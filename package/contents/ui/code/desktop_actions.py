#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

"""
Desktop Actions Helper: a session D-Bus service that gives the context menu
jump list actions, recent documents, browser history and places, plus a few
system helpers QML can't do itself.

Bus name io.github.daydve.fancytasksng.DesktopActions, object /DesktopActions.
Only the shell that started the helper may call it.

Interface io.github.daydve.fancytasksng.DesktopActions:
  Query(launcherUrl, showHistory, limit, appPid) -> JSON string
      {"jumpList", "recentDocs", "recentFolders", "browserHistory",
       "places", "desktopPath"}
  ClearRecent(launcherUrl)
  LaunchAction(launcherUrl, actionId)
  OpenUrl(url, preferredApp)
  ForceQuit(pidsCsv) -> how many were killed
      SIGKILL to processes of this user, never the shell itself
  ParentPids(pidsCsv) -> JSON object {pid: parentPid}
  ActivateBrowserTab(browserPid, title) -> bool
  ListApps() -> JSON array of installed apps
  RegisterTaskEntryShortcuts(component) -> the component's object path
      registers the "Activate Task Manager Entry 1-10" global shortcuts
      (Meta+1 to Meta+9) under component; the shell listens to the presses

Interface io.github.daydve.fancytasksng.Config:
  ExportConfig(path, content) -> "OK" or "ERROR: ..."
  ImportConfig(path) -> file content or "ERROR: ..."

It also owns io.github.daydve.fancytasksng.Bridge and com.canonical.Unity:
Unity LauncherEntry.Update signals (badge counts and progress) are re-emitted
as io.github.daydve.fancytasksng.BadgeUpdate.UpdateSignal(appId, count,
progress, senderPid) on /Bridge, with the state accumulated per sender.

--name-suffix SUFFIX appends SUFFIX to both bus names (not to the interface
names): a copy of the widget run from source (make test) uses its own helper
instead of talking to the installed widget's one, which wouldn't answer it.
"""

import configparser
import gettext
import hashlib
import json
import logging
import logging.handlers
import os
import re
import shlex
import shutil
import sqlite3
import sys
import tempfile
import xml.etree.ElementTree as ET
import ctypes
import signal

from gi.repository import Gio, GLib
from pathlib import Path
from urllib.parse import unquote, urlparse


def _make_logger(name):
    """Logs to the journal (as "fancytasksng"): the executable engine that
    starts the helpers only hands their output over when they exit, so
    stdout/stderr would be lost. Falls back to stderr without /dev/log."""
    logger = logging.getLogger(name)
    try:
        handler = logging.handlers.SysLogHandler(address="/dev/log")
        handler.ident = "fancytasksng: "
    except OSError:
        handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(name)s: %(message)s"))
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    return logger


log = _make_logger("desktop_actions")


def xdg_dir(var, default):
    """An XDG base directory: $var when set to an absolute path, else
    ~/default, as the XDG Base Directory spec says."""
    value = os.environ.get(var, "")
    return Path(value) if os.path.isabs(value) else Path.home() / default


DATA_HOME = xdg_dir("XDG_DATA_HOME", ".local/share")
CACHE_HOME = xdg_dir("XDG_CACHE_HOME", ".cache")
CONFIG_HOME = xdg_dir("XDG_CONFIG_HOME", ".config")

KACTIVITIES_DB = DATA_HOME / "kactivitymanagerd/resources/database"
MAX_RECENT = 5

# KDE icon names for common mime type groups
MIME_ICON_MAP = {
    "inode/directory": "inode-directory",
    "application/pdf": "application-pdf",
    "text/plain": "text-x-generic",
    "text/html": "text-html",
    "image/": "image-x-generic",
    "video/": "video-x-generic",
    "audio/": "audio-x-generic",
    "application/vnd.oasis": "x-office-document",
    "application/vnd.openxml": "x-office-document",
    "application/zip": "application-zip",
}


def app_for_launcher(url_str):
    """The installed app a launcher URL points to, or None. "file://" takes a
    .desktop file path; "applications:" (or a bare id) a desktop file id,
    looked up in $XDG_DATA_HOME and $XDG_DATA_DIRS (Flatpak exports included)
    the way every other desktop app finds it."""
    if not url_str:
        return None
    parsed = urlparse(url_str)
    try:
        if parsed.scheme == "file":
            return Gio.DesktopAppInfo.new_from_filename(unquote(parsed.path))
        if parsed.scheme in ("applications", ""):
            desktop_id = parsed.path.lstrip("/")
            if not desktop_id.endswith(".desktop"):
                desktop_id += ".desktop"
            return Gio.DesktopAppInfo.new(desktop_id)
    except (GLib.Error, TypeError):
        pass
    return None


def get_categories(app):
    """The app's Categories list."""
    return [c for c in (app.get_categories() or "").split(";") if c]


def _languages():
    """Languages to look translations up in, best first: GLib's (from
    $LANGUAGE) and the session locale's with and without its region. GLib's
    alone misses a "Name[ru_RU]" with LANGUAGE=ru, which Plasma, going by
    LANG, does show."""
    langs = [lang for lang in GLib.get_language_names() if lang != "C"]
    for var in ("LC_ALL", "LC_MESSAGES", "LANG"):
        locale_name = os.environ.get(var, "").split(".")[0].split("@")[0]
        if locale_name and locale_name not in ("C", "POSIX"):
            for lang in (locale_name, locale_name.split("_")[0]):
                if lang not in langs:
                    langs.append(lang)
            break
    return langs


def get_jump_list_actions(app):
    """The app's [Desktop Action ...] entries, with their names in the
    session's language. GDesktopAppInfo lists them; their names and icons are
    read from the file, as it has no getter for an action's icon and picks
    translations by $LANGUAGE alone."""
    actions = []
    keyfile = GLib.KeyFile()
    try:
        keyfile.load_from_file(app.get_filename(), GLib.KeyFileFlags.KEEP_TRANSLATIONS)
    except (GLib.Error, TypeError):
        return actions
    langs = _languages()

    def value(section, key):
        try:
            return keyfile.get_string(section, key)
        except GLib.Error:
            return ""

    for action_id in app.list_actions():
        section = f"Desktop Action {action_id}"
        name = next((n for n in (value(section, f"Name[{lang}]") for lang in langs) if n), "") or value(section, "Name")
        if not name:
            continue
        actions.append({"name": name, "icon": value(section, "Icon"), "actionId": action_id})
    return actions


def get_storage_id(app):
    """The app's desktop file id without ".desktop": the agent kactivitymanagerd
    files its recent documents under."""
    desktop_id = app.get_id() or os.path.basename(app.get_filename() or "")
    return desktop_id[:-8] if desktop_id.endswith(".desktop") else desktop_id


_session_bus = None


def _get_session_bus():
    """Return a cached session bus connection shared by all D-Bus helper calls."""
    global _session_bus
    if _session_bus is None:
        _session_bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    return _session_bus


def _dbus_call(name, path, iface, method, args=None, reply_type=None, timeout_ms=2000):
    """Blocking D-Bus call with a bounded timeout; returns the unpacked reply
    tuple. Raises GLib.Error on failure."""
    reply = _get_session_bus().call_sync(
        name, path, iface, method, args,
        GLib.VariantType.new(reply_type) if reply_type else None,
        Gio.DBusCallFlags.NONE, timeout_ms, None)
    return reply.unpack() if reply is not None else ()


def _connection_pid(name):
    """PID of the process behind a bus name, 0 if unknown."""
    try:
        return int(_dbus_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                              "GetConnectionUnixProcessID", GLib.Variant("(s)", (name,)), "(u)")[0])
    except GLib.Error:
        return 0


def get_current_activity():
    """Get current KDE activity ID via D-Bus."""
    try:
        # Bounded timeout: this runs on the service's single mainloop, so a hung
        # ActivityManager must not be able to freeze every tooltip/menu query.
        return str(_dbus_call("org.kde.ActivityManager",
                              "/ActivityManager/Activities",
                              "org.kde.ActivityManager.Activities",
                              "CurrentActivity", None, "(s)")[0])
    except Exception:
        return None


def guess_icon_for_mime(mime_type):
    """Map a MIME type to a freedesktop icon name."""
    if not mime_type:
        return "unknown"
    for prefix, icon in MIME_ICON_MAP.items():
        if mime_type.startswith(prefix):
            return icon
    # Generic: replace / with - for freedesktop naming
    return mime_type.replace("/", "-")


def get_recent_documents(app):
    """Query KActivities database for recent documents opened by this app."""
    docs = []
    if not KACTIVITIES_DB.is_file():
        return docs

    storage_id = get_storage_id(app)
    if not storage_id:
        return docs

    activity = get_current_activity()
    if not activity:
        return docs

    try:
        conn = sqlite3.connect(str(KACTIVITIES_DB))
        cur = conn.cursor()
        cur.execute(f"""
            SELECT re.targettedResource, ri.mimetype, MAX(re.start) as lastUpdate
            FROM ResourceEvent re
            LEFT JOIN ResourceInfo ri ON re.targettedResource = ri.targettedResource
            WHERE re.initiatingAgent = ?
            AND re.usedActivity = ?
            GROUP BY re.targettedResource
            ORDER BY lastUpdate DESC
            LIMIT ?
        """, (storage_id, activity, MAX_RECENT * 2))

        seen = set()
        for row in cur.fetchall():
            resource = row[0]
            mimetype = row[1]

            if not resource:
                continue

            # Parse file path
            file_path = resource
            if file_path.startswith("file://"):
                file_path = file_path[7:]
            
            # Kickoff typically checks if local files exist, but we still allow valid KDE URLs
            if file_path.startswith("/"):
                if not os.path.exists(file_path):
                    continue
            elif file_path.startswith("zip://") or file_path.startswith("tar://") or file_path.startswith("krarc://"):
                # For virtual KDE KIO paths, we try to extract the base archive path and verify if the archive still exists
                protocol_end = file_path.find("://") + 3
                archive_path = file_path[protocol_end:]
                # Split at the first well-known archive extension 
                for ext in [".zip/", ".tar/", ".tar.gz/", ".xz/", ".bz2/", ".rar/"]:
                    if ext in archive_path:
                        real_archive = archive_path[:archive_path.find(ext) + len(ext) - 1]
                        if not os.path.exists(real_archive):
                            file_path = None # Mark as non-existent
                        break
                
                if file_path is None:
                    continue
            elif file_path.startswith("trash:/"):
                # Always allow opening the root Trash folder in Dolphin
                if file_path != "trash:/" and file_path != "trash://":
                    # Specific deleted files (trash:/file.txt) shouldn't be opened directly
                    continue
            elif file_path.startswith("mailto:"):
                # Filter out mailto protocols (e.g. recent emails composed, not actual documents)
                continue
            
            # Determine icon and name
            icon_name = guess_icon_for_mime(mimetype)
            name = os.path.basename(file_path) if file_path.startswith("/") else file_path

            if file_path not in seen:
                seen.add(file_path)
                url = f"file://{file_path}" if file_path.startswith("/") else file_path
                docs.append({
                    "name": name,
                    "url": url,
                    "icon": icon_name,
                    "mimeType": mimetype or ""
                })
            
            if len(docs) >= MAX_RECENT:
                break

        conn.close()
    except Exception as e:
        log.warning(f"DB error: {e}")

    return docs


def find_active_db_from_proc(db_name, app_pid=0):
    """Find the active database path by inspecting open file descriptors of the given PID and its parent PPID."""
    if app_pid <= 0:
        return None
    try:
        pids = [app_pid]
        # Browser renderers may have child PIDs while the main process owns the DB handle.
        # Inspect parent PID as well to cover multi-process architectures.
        try:
            with open(f"/proc/{app_pid}/stat", "r") as f:
                stat_parts = f.read().split()
                if len(stat_parts) > 3:
                    ppid = int(stat_parts[3])
                    if ppid > 0:
                        pids.append(ppid)
        except Exception:
            pass

        for pid in set(pids):
            fd_dir = Path(f"/proc/{pid}/fd")
            if not fd_dir.exists():
                continue
            try:
                for fd in fd_dir.iterdir():
                    try:
                        target = os.readlink(fd)
                        # Exact name: the -wal/-journal files are open too.
                        if os.path.basename(target) == db_name and os.path.isfile(target):
                            return Path(target)
                    except (OSError, PermissionError):
                        continue
            except (OSError, PermissionError):
                continue
    except Exception as e:
        log.warning(f"proc scan error: {e}")
    return None


def copy_sqlite(src, dest):
    """Copy a live browser database for reading. Recent changes sit in the
    write-ahead log until the browser checkpoints, so it goes along; SQLite
    replays it when the copy is opened."""
    shutil.copy2(src, dest)
    wal = Path(f"{src}-wal")
    if wal.exists():
        shutil.copy2(wal, f"{dest}-wal")


def remove_sqlite_copy(path):
    for suffix in ("", "-wal", "-shm"):
        try:
            Path(f"{path}{suffix}").unlink(missing_ok=True)
        except OSError:
            pass


def extract_favicons(history_items, favicons_db_path, engine):
    """Extract favicons for history items and save them to local cache."""
    if not history_items or not favicons_db_path or not os.path.exists(favicons_db_path):
        return history_items

    cache_dir = CACHE_HOME / "fancytasksng" / "favicons"
    cache_dir.mkdir(parents=True, exist_ok=True)

    urls_to_query = []
    for item in history_items:
        url = item.get("url")
        if not url:
            continue
        url_hash = hashlib.md5(url.encode('utf-8')).hexdigest()
        
        cached_png = cache_dir / f"{url_hash}.png"
        cached_failed = cache_dir / f"{url_hash}.failed"
        
        if cached_png.exists():
            item["icon"] = f"file://{cached_png}"
        elif cached_failed.exists():
            item["icon"] = "internet-services"
        else:
            urls_to_query.append((url, item, cached_png, cached_failed))

    if not urls_to_query:
        return history_items

    fd, temp_path = tempfile.mkstemp(prefix="favicons_temp.sqlite")
    os.close(fd)
    temp_db = Path(temp_path)

    try:
        copy_sqlite(favicons_db_path, temp_db)
        conn = sqlite3.connect(temp_db)
        cursor = conn.cursor()

        for url, item, cached_png, cached_failed in urls_to_query:
            cursor.execute(FAVICON_QUERIES[engine], (url,))
            row = cursor.fetchone()
            blob = row[0] if row else None

            if blob:
                try:
                    with open(cached_png, "wb") as f:
                        f.write(blob)
                    item["icon"] = f"file://{cached_png}"
                except Exception as e:
                    log.warning(f"failed to write favicon cache: {e}")
                    item["icon"] = "internet-services"
            else:
                try:
                    with open(cached_failed, "w") as f:
                        f.write("")
                except Exception:
                    pass
                item["icon"] = "internet-services"

        conn.close()
    except Exception as e:
        log.warning(f"extract_favicons error: {e}")
    finally:
        remove_sqlite_copy(temp_db)

    return history_items


HISTORY_QUERIES = {
    "firefox": """
        SELECT DISTINCT url, title FROM moz_places
        WHERE last_visit_date IS NOT NULL AND title IS NOT NULL AND url LIKE 'http%'
        ORDER BY last_visit_date DESC LIMIT ?
    """,
    "chromium": """
        SELECT DISTINCT url, title FROM urls
        WHERE last_visit_time IS NOT NULL AND title IS NOT NULL AND url LIKE 'http%'
        ORDER BY last_visit_time DESC LIMIT ?
    """,
}

FAVICON_QUERIES = {
    "firefox": """
        SELECT i.data FROM moz_icons i
        JOIN moz_icons_to_pages itp ON itp.icon_id = i.id
        JOIN moz_pages_w_icons p ON p.id = itp.page_id
        WHERE p.page_url = ? AND i.data IS NOT NULL
        ORDER BY i.width DESC LIMIT 1
    """,
    "chromium": """
        SELECT b.image_data FROM favicon_bitmaps b
        JOIN icon_mapping m ON m.icon_id = b.icon_id
        WHERE m.page_url = ? AND b.image_data IS NOT NULL
        ORDER BY b.width DESC LIMIT 1
    """,
}

# Per engine: the history and favicon database file names.
ENGINE_FILES = {
    "firefox": ("places.sqlite", "favicons.sqlite"),
    "chromium": ("History", "Favicons"),
}

_HOME = Path.home()
# Browser -> (engine, profile base directories: native, Flatpak, Snap).
# Native profiles under ~/.config follow $XDG_CONFIG_HOME, as the browsers
# do; Firefox's legacy ~/.mozilla and Flatpak/Snap dirs stay home-based.
BROWSERS = {
    "firefox": ("firefox", [
        _HOME / ".mozilla" / "firefox",
        CONFIG_HOME / "mozilla" / "firefox",
        _HOME / ".var" / "app" / "org.mozilla.firefox" / ".mozilla" / "firefox",
        _HOME / ".var" / "app" / "org.mozilla.firefox-trunk" / ".mozilla" / "firefox",
        _HOME / "snap" / "firefox" / "common" / ".mozilla" / "firefox",
    ]),
    "chrome": ("chromium", [
        CONFIG_HOME / "google-chrome",
        _HOME / ".var" / "app" / "com.google.Chrome" / "config" / "google-chrome",
    ]),
    "chromium": ("chromium", [
        CONFIG_HOME / "chromium",
        _HOME / ".var" / "app" / "org.chromium.Chromium" / "config" / "chromium",
    ]),
    "brave": ("chromium", [
        CONFIG_HOME / "BraveSoftware" / "Brave-Browser",
        _HOME / ".var" / "app" / "com.brave.Browser" / "config" / "BraveSoftware" / "Brave-Browser",
    ]),
    "vivaldi": ("chromium", [
        CONFIG_HOME / "vivaldi",
        _HOME / ".var" / "app" / "com.vivaldi.Vivaldi" / "config" / "vivaldi",
    ]),
    "edge": ("chromium", [
        CONFIG_HOME / "microsoft-edge",
        _HOME / ".var" / "app" / "com.microsoft.Edge" / "config" / "microsoft-edge",
    ]),
    "opera": ("chromium", [
        CONFIG_HOME / "opera",
        _HOME / ".var" / "app" / "com.opera.Opera" / "config" / "opera",
    ]),
}


def _firefox_profile_dbs(base, db_name):
    """History databases of the profiles listed in a Firefox profiles.ini."""
    dbs = []
    if not (base / "profiles.ini").exists():
        return dbs
    try:
        config = configparser.ConfigParser()
        config.read(base / "profiles.ini")
        for section in config.sections():
            if section.startswith("Profile"):
                p_dir = config[section].get("Path")
            elif section.startswith("Install"):
                p_dir = config[section].get("Default")
            else:
                p_dir = None
            if p_dir:
                full_path = base / p_dir if config[section].get("IsRelative", "1") == "1" else Path(p_dir)
                if (full_path / db_name).exists():
                    dbs.append(full_path / db_name)
    except Exception:
        pass
    return dbs


def _chromium_profile_dbs(base, db_name):
    """History databases of a Chromium-family browser's common profiles."""
    return [base / profile / db_name for profile in ("Default", "Profile 1", "Profile 2", ".")
            if (base / profile / db_name).exists()]


def get_browser_recent(browser, limit=10, app_pid=0):
    """Recent pages from a browser's history: the profile the running browser
    has open, or else the most recently written one found on disk."""
    engine, base_dirs = BROWSERS[browser]
    history_name, favicons_name = ENGINE_FILES[engine]

    db_path = find_active_db_from_proc(history_name, app_pid=app_pid)
    if not db_path:
        find_profiles = _firefox_profile_dbs if engine == "firefox" else _chromium_profile_dbs
        candidates = [db for base in base_dirs if base.exists() for db in find_profiles(base, history_name)]
        if not candidates:
            return []
        db_path = max(candidates, key=lambda p: p.stat().st_mtime)

    history = fetch_sqlite_history(db_path, HISTORY_QUERIES[engine], f"history_{browser}.sqlite", limit)
    return extract_favicons(history, db_path.parent / favicons_name, engine)


# Name parts of a browser's .desktop file -> browser. Matched as whole parts:
# a substring test took "hedgewars" for Edge.
BROWSER_NAME_PARTS = {
    "firefox": "firefox", "mozilla": "firefox", "ffpwa": "firefox",
    "chrome": "chrome", "brave": "brave", "vivaldi": "vivaldi",
    "chromium": "chromium", "edge": "edge", "opera": "opera",
}


def detect_browser(desktop_path):
    parts = re.split(r"[^a-z0-9]+", os.path.basename(desktop_path).lower())
    for part in parts:
        if part in BROWSER_NAME_PARTS:
            return BROWSER_NAME_PARTS[part]
    return None


def fetch_sqlite_history(db_path, query, temp_name, limit=10):
    """Generic helper to fetch history from a SQLite DB using a temporary copy."""
    docs = []
    # Use tempfile to avoid collisions and permission issues in /tmp
    fd, temp_path = tempfile.mkstemp(prefix=temp_name)
    os.close(fd)
    temp_db = Path(temp_path)
    
    try:
        copy_sqlite(db_path, temp_db)
        conn = sqlite3.connect(temp_db)
        cursor = conn.cursor()
        cursor.execute(query, (limit * 3,))
        
        seen_urls = set()
        seen_titles = set()
        for url, title in cursor.fetchall():
            norm_url = url.split('#')[0].rstrip('/')
            if norm_url in seen_urls or title in seen_titles:
                continue
            seen_urls.add(norm_url)
            seen_titles.add(title)
            docs.append({"name": title, "url": url, "icon": "internet-services", "mimeType": "text/html"})
            if len(docs) >= limit: break
        conn.close()
    except Exception as e:
        log.warning(f"fetch_history error ({db_path}): {e}")
    finally:
        remove_sqlite_copy(temp_db)
    return docs


def clear_recent_documents(app):
    """Forget this app's recent documents in the current activity.

    Goes through kactivitymanagerd, which owns the database: writing to it
    behind the daemon's back can race with its own writes and leaves its
    caches stale."""
    storage_id = get_storage_id(app)
    activity = get_current_activity()
    if not storage_id or not activity:
        return False
    try:
        _dbus_call("org.kde.ActivityManager",
                   "/ActivityManager/Resources/Scoring",
                   "org.kde.ActivityManager.ResourcesScoring",
                   "DeleteStatsForResource", GLib.Variant("(sss)", (activity, storage_id, "*")))
        return True
    except GLib.Error as e:
        log.warning(f"clear recent error: {e}")
        return False


def get_kde_places():
    """Parse $XDG_DATA_HOME/user-places.xbel to get KDE Places."""
    places = []
    xbel_path = DATA_HOME / "user-places.xbel"
    if not xbel_path.exists():
        return places

    try:
        # Standard XBEL doesn't use namespaces for title/bookmark, 
        # but KDE adds metadata in its own namespaces.
        tree = ET.parse(xbel_path)
        root = tree.getroot()
        
        for bookmark in root.findall('bookmark'):
            href = bookmark.get('href')
            title_node = bookmark.find('title')
            title = title_node.text if title_node is not None else href
            
            icon = "folder"
            is_hidden = False
            
            # Metadata for icon and hidden state
            # Metadata nodes can have owner="http://freedesktop.org" or "http://www.kde.org"
            for info in bookmark.findall('info'):
                for metadata in info.findall('metadata'):
                    owner = metadata.get('owner')
                    if owner == "http://freedesktop.org":
                        # Look for <bookmark:icon name="..."/>
                        # XBEL spec uses http://www.freedesktop.org/standards/desktop-bookmarks namespace
                        icon_node = metadata.find('{http://www.freedesktop.org/standards/desktop-bookmarks}icon')
                        if icon_node is not None:
                            icon = icon_node.get('name')
                    elif owner == "http://www.kde.org":
                        hidden_node = metadata.find('IsHidden')
                        if hidden_node is not None and hidden_node.text == "true":
                            is_hidden = True

            if not is_hidden:
                places.append({
                    "name": title,
                    "url": href,
                    "icon": icon
                })
    except Exception as e:
        # print(f"XBEL error: {e}", file=sys.stderr)
        pass

    return places



def set_pdeathsig():
    """Ensure the process dies when its parent (plasmashell) dies."""
    try:
        libc = ctypes.CDLL("libc.so.6")
        libc.prctl(1, signal.SIGTERM) # 1 is PR_SET_PDEATHSIG
    except Exception:
        pass

def _ancestor_pids():
    """PIDs of this process's ancestors: plasmashell (or plasmawindowed when
    run with `make test`), possibly through a shell started by the executable
    data engine."""
    pids = set()
    pid = os.getppid()
    while pid > 1 and pid not in pids:
        pids.add(pid)
        try:
            with open(f"/proc/{pid}/status", encoding="utf-8") as f:
                pid = next((int(line.split()[1]) for line in f if line.startswith("PPid:")), 0)
        except (OSError, ValueError, IndexError):
            break
    return pids


def list_applications():
    """Every installed app (Hidden ones excluded, NoDisplay ones flagged), for
    the Pinned Applications settings page, sorted by name."""
    apps = []
    for info in Gio.AppInfo.get_all():
        if not isinstance(info, Gio.DesktopAppInfo) or not info.get_id():
            continue
        apps.append({
            "id": info.get_id(),
            "name": info.get_display_name() or info.get_id(),
            "icon": info.get_string("Icon") or "application-x-executable",
            "genericName": info.get_generic_name() or "",
            "comment": info.get_description() or "",
            "keywords": list(info.get_keywords() or []),
            "display": bool(info.should_show()),
        })
    apps.sort(key=lambda app: app["name"].casefold())
    return apps


SERVICE_NAME = "io.github.daydve.fancytasksng.DesktopActions"
BRIDGE_NAME = "io.github.daydve.fancytasksng.Bridge"


def _apply_name_suffix(argv):
    global SERVICE_NAME, BRIDGE_NAME
    if "--name-suffix" in argv:
        suffix = argv[argv.index("--name-suffix") + 1]
        SERVICE_NAME += suffix
        BRIDGE_NAME += suffix

SERVICE_XML = """
<node>
  <interface name="io.github.daydve.fancytasksng.DesktopActions">
    <method name="Query">
      <arg type="s" direction="in"/><arg type="b" direction="in"/>
      <arg type="i" direction="in"/><arg type="i" direction="in"/>
      <arg type="s" direction="out"/>
    </method>
    <method name="ClearRecent"><arg type="s" direction="in"/></method>
    <method name="LaunchAction"><arg type="s" direction="in"/><arg type="s" direction="in"/></method>
    <method name="ParentPids"><arg type="s" direction="in"/><arg type="s" direction="out"/></method>
    <method name="ActivateBrowserTab">
      <arg type="i" direction="in"/><arg type="s" direction="in"/><arg type="b" direction="out"/>
    </method>
    <method name="ListApps"><arg type="s" direction="out"/></method>
    <method name="OpenUrl"><arg type="s" direction="in"/><arg type="s" direction="in"/></method>
    <method name="ForceQuit"><arg type="s" direction="in"/><arg type="i" direction="out"/></method>
    <method name="Restart"><arg type="s" direction="in"/><arg type="s" direction="in"/></method>
    <method name="EditApplication"><arg type="s" direction="in"/></method>
    <method name="DesktopFile"><arg type="s" direction="in"/><arg type="s" direction="out"/></method>
    <method name="RegisterTaskEntryShortcuts"><arg type="s" direction="in"/><arg type="o" direction="out"/></method>
  </interface>
  <interface name="io.github.daydve.fancytasksng.Config">
    <method name="ExportConfig">
      <arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="out"/>
    </method>
    <method name="ImportConfig"><arg type="s" direction="in"/><arg type="s" direction="out"/></method>
  </interface>
</node>
"""

BRIDGE_XML = """
<node>
  <interface name="io.github.daydve.fancytasksng.BadgeUpdate">
    <signal name="UpdateSignal">
      <arg type="s"/><arg type="i"/><arg type="d"/><arg type="u"/>
    </signal>
  </interface>
</node>
"""


def _request_name(name):
    """Takes one of our bus names; True if this process owns it. A helper
    still running for an earlier shell (one that didn't quit with it) gives
    the name up to the new one and quits: it only answers that earlier shell,
    so it would leave the new one without app names or jump lists."""
    try:
        # 1: ALLOW_REPLACEMENT, 2: REPLACE_EXISTING, 4: DO_NOT_QUEUE
        reply = _dbus_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                           "RequestName", GLib.Variant("(su)", (name, 7)), "(u)")
        return reply[0] == 1  # PRIMARY_OWNER
    except GLib.Error as e:
        log.warning(f"could not request {name}: {e}")
        return False


KGLOBALACCEL = ("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel")


class GlobalShortcuts:
    """Registers global shortcuts with kglobalaccel, as KGlobalAccel::
    setGlobalShortcut() does, and registers them again whenever kglobalaccel
    comes back: it loses them when it restarts (with KWin on Wayland). The
    shell listens to the presses itself."""

    SET_PRESENT = 2  # keep the keys already on record (System Settings)
    IS_DEFAULT = 8

    def __init__(self, bus):
        self.actions = {}  # (component, action) -> (friendly name, default keys)
        self.watch_id = Gio.bus_watch_name_on_connection(
            bus, KGLOBALACCEL[0], Gio.BusNameWatcherFlags.NONE, self._on_appeared, None)

    def register(self, component, actions):
        """actions: (action name, friendly name, default key combinations).
        Returns the component's object path, which emits the presses."""
        for name, friendly, keys in actions:
            self.actions[(component, name)] = (friendly, keys)
            self._register(component, name, friendly, keys)
        return _dbus_call(*KGLOBALACCEL, "getComponent", GLib.Variant("(s)", (component,)), "(o)")[0]

    def _register(self, component, name, friendly, keys):
        # An empty component friendly name keeps the one already on record.
        action_id = [component, name, "", friendly]
        _dbus_call(*KGLOBALACCEL, "doRegister", GLib.Variant("(as)", (action_id,)))
        sequences = [([key],) for key in keys]
        for flags in (self.SET_PRESENT, self.IS_DEFAULT):
            _dbus_call(*KGLOBALACCEL, "setShortcutKeys",
                       GLib.Variant("(asa(ai)u)", (action_id, sequences, flags)), "(a(ai))")

    def _on_appeared(self, connection, name, owner):
        for (component, action), (friendly, keys) in self.actions.items():
            try:
                self._register(component, action, friendly, keys)
            except GLib.Error as e:
                log.warning(f"could not register {action}: {e}")


class DesktopActionsService:
    """Only the widget's own shell may call this service: it launches
    programs, reads and writes files and returns browsing history, so any
    other client of the session bus (a Flatpak app with bus access, say)
    must not be able to use it."""

    def __init__(self):
        self.allowed_pids = _ancestor_pids()
        self.sender_allowed = {}
        self.bus = _get_session_bus()
        self.shortcuts = GlobalShortcuts(self.bus)
        node = Gio.DBusNodeInfo.new_for_xml(SERVICE_XML)
        self.out_signatures = {}
        for iface in node.interfaces:
            for method in iface.methods:
                self.out_signatures[method.name] = "".join(arg.signature for arg in method.out_args)
            self.bus.register_object("/DesktopActions", iface, self._on_method_call, None, None)
        if not _request_name(SERVICE_NAME):
            log.error(f"{SERVICE_NAME} is already taken")
            sys.exit(1)
        log.info("service ready")

    def _caller_allowed(self, sender):
        # Unique bus names are never reused, so the verdict can be cached.
        if sender not in self.sender_allowed:
            self.sender_allowed[sender] = _connection_pid(sender) in self.allowed_pids
        return self.sender_allowed[sender]

    def _on_method_call(self, connection, sender, path, iface, method, params, invocation):
        if not self._caller_allowed(sender):
            invocation.return_dbus_error("io.github.daydve.fancytasksng.Error.NotAllowed",
                                         f"{sender} is not the shell running this widget")
            return
        try:
            result = getattr(self, method)(*params.unpack())
        except Exception as e:
            log.warning(f"{method} failed: {e}")
            invocation.return_dbus_error("org.freedesktop.DBus.Error.Failed", str(e))
            return
        signature = self.out_signatures[method]
        invocation.return_value(GLib.Variant(f"({signature})", (result,)) if signature else None)

    def Query(self, launcher_url, show_history, limit, app_pid):
        app = app_for_launcher(launcher_url)
        desktop_path = app.get_filename() if app else None
        jump_list = get_jump_list_actions(app) if app else []

        browser_history = []
        if desktop_path and show_history:
            browser = detect_browser(desktop_path)
            if browser:
                browser_history = get_browser_recent(browser, limit, app_pid)

        raw_recent = get_recent_documents(app) if app else []
        
        # Filter/Split recent items
        recent_docs = []
        recent_folders = []
        browser_urls = {item['url'] for item in browser_history}
        
        for doc in raw_recent:
            if doc['url'] in browser_urls:
                continue
            
            if doc.get('mimeType') == 'inode/directory':
                recent_folders.append(doc)
            else:
                recent_docs.append(doc)
        
        places = []
        if desktop_path and "dolphin" in desktop_path.lower():
            places = get_kde_places()

        data = {
            "jumpList": jump_list,
            "recentDocs": recent_docs,
            "recentFolders": recent_folders,
            "browserHistory": browser_history,
            "places": places,
            "desktopPath": desktop_path or "",
            "categories": get_categories(app) if app else [],
        }
        return json.dumps(data)

    def ClearRecent(self, launcher_url):
        app = app_for_launcher(launcher_url)
        if app:
            clear_recent_documents(app)

    def LaunchAction(self, launcher_url, action_id):
        """Run one of the [Desktop Action ...] entries of an app's .desktop file."""
        app = app_for_launcher(launcher_url)
        if not app:
            return
        try:
            if action_id in app.list_actions():
                app.launch_action(action_id, None)
        except GLib.Error as e:
            log.warning(f"LaunchAction error: {e}")

    def EditApplication(self, launcher_url):
        """Opens the app in the menu editor (KMenuEdit), as "Edit
        Application…" in the app menu does. An edited system launcher is saved
        as a copy in ~/.local/share/applications, which then wins over it."""
        app = app_for_launcher(launcher_url)
        editor = Gio.DesktopAppInfo.new("org.kde.kmenuedit.desktop")
        if not app or not app.get_id() or not editor:
            return
        try:
            GLib.spawn_async([editor.get_executable(), app.get_id()], flags=GLib.SpawnFlags.SEARCH_PATH)
        except GLib.Error as e:
            log.warning(f"EditApplication error: {e}")

    def ParentPids(self, pids_csv):
        """Map comma-separated PIDs to their parent PIDs (JSON object).

        QML can't read /proc itself. Chromium-family browsers play audio
        from a utility child process, so its stream PID only matches a
        window through its parent. PIDs that no longer exist are omitted.
        """
        result = {}
        for token in pids_csv.split(","):
            token = token.strip()
            if not token.isdigit():
                continue
            try:
                with open(f"/proc/{token}/status", encoding="utf-8") as f:
                    for line in f:
                        if line.startswith("PPid:"):
                            result[token] = int(line.split()[1])
                            break
            except (OSError, ValueError, IndexError):
                pass
        return json.dumps(result)

    def ActivateBrowserTab(self, browser_pid, title):
        """Switch a browser to the tab with the given title; True on success.

        Goes through the Plasma Browser Integration extension: each browser
        it runs in starts its own native host, a child of the browser, and
        every host offers KRunner's tab search on /TabsRunner. A browser
        names a tab's audio stream after the page, so this finds the tab a
        stream plays in - the one way to get to a tab that isn't the one
        the browser's single MPRIS player follows.
        """
        if browser_pid <= 0 or not title:
            return False
        try:
            names = _dbus_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                               "ListNames", None, "(as)")[0]
        except GLib.Error as e:
            log.warning(f"ActivateBrowserTab error: {e}")
            return False
        for name in names:
            if not name.startswith('org.kde.plasma.browser_integration'):
                continue
            try:
                host_pid = _connection_pid(name)
                with open(f"/proc/{host_pid}/status", encoding="utf-8") as f:
                    parent = next((int(line.split()[1]) for line in f if line.startswith("PPid:")), 0)
                if parent != browser_pid:
                    continue
                matches = _dbus_call(name, '/TabsRunner', 'org.kde.krunner1', 'Match',
                                     GLib.Variant("(s)", (title,)))[0]
                # (id, text, icon name, type, relevance, properties)
                exact = [m for m in matches if m[1] == title]
                chosen = exact[0] if exact else (matches[0] if len(matches) == 1 else None)
                if chosen is None:
                    return False
                _dbus_call(name, '/TabsRunner', 'org.kde.krunner1', 'Run', GLib.Variant("(ss)", (chosen[0], '')))
                return True
            except (GLib.Error, OSError, ValueError, StopIteration):
                continue
        return False

    def ExportConfig(self, path, content):
        try:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            return "OK"
        except Exception as e:
            return f"ERROR: {e}"

    def ImportConfig(self, path):
        try:
            with open(path, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            return f"ERROR: {e}"

    def RegisterTaskEntryShortcuts(self, component):
        """The actions plasmashell registered up to Plasma 6.7 and the stock
        task manager's backend registers since 6.8, under the same names, so
        a key changed in System Settings applies whichever registered it."""
        meta, key_0 = 0x10000000, 0x30  # Qt::MetaModifier, Qt::Key_0
        actions = []
        for entry in range(1, 11):
            # The stock task manager's wording and translation.
            friendly = gettext.dgettext("plasma_applet_org.kde.plasma.taskmanager",
                                        "Activate Task Manager Entry %1").replace("%1", str(entry))
            keys = [meta | (key_0 + entry)] if entry < 10 else []
            actions.append((f"activate task manager entry {entry}", friendly, keys))
        return self.shortcuts.register(component, actions)

    def ListApps(self):
        return json.dumps(list_applications())

    def OpenUrl(self, url, preferred_app):
        try:
            app = app_for_launcher(preferred_app)
            if app:
                commandline = app.get_commandline() or ""
                # Firefox PWAs (FFPWA) take links through --protocol, which
                # treats a web URL as a protocol handler call; --url opens it.
                if url.lower().startswith("http") and "--protocol" in commandline:
                    argv = expand_exec(commandline.replace("--protocol", "--url"), url)
                    Gio.Subprocess.new(argv, Gio.SubprocessFlags.NONE)
                else:
                    app.launch_uris([url], None)
                return
            Gio.AppInfo.launch_default_for_uri(url, None)
        except (GLib.Error, ValueError) as e:
            log.warning(f"OpenUrl error: {e}")

    def ForceQuit(self, pids_csv):
        """Kill the processes of windows that no longer respond. Only this
        user's processes, and never the shell (or this helper): a window of
        plasmashell itself, such as this widget's settings, is a task too."""
        protected = self.allowed_pids | {os.getpid()}
        killed = 0
        pids = {int(p) for p in pids_csv.split(",") if p.strip().isdigit()}
        for pid in pids:
            if pid <= 1 or pid in protected:
                continue
            try:
                if os.stat(f"/proc/{pid}").st_uid != os.getuid():
                    continue
                os.kill(pid, signal.SIGKILL)
                killed += 1
                log.info(f"force quit pid {pid}")
            except OSError as e:
                log.warning(f"ForceQuit {pid}: {e}")
        return killed

    def Restart(self, pids_csv, launcher_url):
        """Launch the app again once its processes are gone. The shell asks
        the windows to close first; an app that keeps running (say, waiting
        on a "save changes?" dialog) isn't launched a second time."""
        app = app_for_launcher(launcher_url)
        if not app:
            return
        pids = {int(p) for p in pids_csv.split(",") if p.strip().isdigit() and int(p) > 1}
        waited = [0]

        def check():
            if any(os.path.exists(f"/proc/{pid}") for pid in pids):
                waited[0] += 1
                if waited[0] * 200 >= 30000:
                    log.info(f"restart of {launcher_url} given up: still running")
                    return False
                return True
            try:
                app.launch([], None)
                log.info(f"restarted {launcher_url}")
            except GLib.Error as e:
                log.warning(f"Restart error: {e}")
            return False
        GLib.timeout_add(200, check)

    def DesktopFile(self, launcher_url):
        """The path of the app's .desktop file, "" if there's none."""
        app = app_for_launcher(launcher_url)
        return (app.get_filename() or "") if app else ""


def expand_exec(commandline, url):
    """Split a .desktop Exec line into argv with the file/URL field codes
    replaced by url, as the desktop entry spec describes."""
    argv = []
    used = False
    for arg in shlex.split(commandline):
        if arg in ("%f", "%F", "%u", "%U"):
            argv.append(url)
            used = True
        elif arg in ("%i", "%c", "%k"):
            continue
        else:
            for code in ("%f", "%F", "%u", "%U"):
                if code in arg:
                    arg = arg.replace(code, url)
                    used = True
            argv.append(arg.replace("%%", "%"))
    if not used:
        argv.append(url)
    return argv


class BadgeBridge:
    """Re-emits Unity LauncherEntry updates (badge counts and progress) on a
    bus name of our own, which QML's SignalWatcher can follow."""

    def __init__(self):
        self.bus = _get_session_bus()
        # Last known LauncherEntry properties per app and sender. An Update
        # carries only the properties that changed (a download sends just its
        # progress), so the rest has to come from earlier ones.
        self.entry_state = {}
        # Unique bus names are never reused, so a sender's PID can be cached.
        self.sender_pids = {}
        node = Gio.DBusNodeInfo.new_for_xml(BRIDGE_XML)
        self.bus.register_object("/Bridge", node.interfaces[0], None, None, None)
        if not _request_name(BRIDGE_NAME):
            log.error(f"{BRIDGE_NAME} is already taken")
            sys.exit(1)
        # Apps such as KMail only send badge updates while com.canonical.Unity
        # is on the bus. If it's taken (Plasma's own task manager, or the
        # helper this one replaces, until it quits), the signals are still
        # received through the subscription below, and the name is taken
        # once it's free.
        Gio.bus_own_name_on_connection(
            self.bus, "com.canonical.Unity", Gio.BusNameOwnerFlags.NONE,
            lambda connection, name: log.info(f"registered as {name}"), None)
        self.bus.signal_subscribe(None, "com.canonical.Unity.LauncherEntry", "Update", None, None,
                                  Gio.DBusSignalFlags.NONE, self._on_update)

    def _sender_pid(self, sender):
        if not sender:
            return 0
        if sender not in self.sender_pids:
            self.sender_pids[sender] = _connection_pid(sender)
        return self.sender_pids[sender]

    def _on_update(self, connection, sender, path, iface, signal_name, params):
        app_id, properties = params.unpack()
        state = self.entry_state.setdefault((app_id, sender), {})
        state.update(properties)
        count = int(state.get("count", 0)) if state.get("count-visible", True) else 0
        progress = float(state.get("progress", 0.0)) if state.get("progress-visible", False) else -1.0
        # The app id an app reports can differ from the one of the task it
        # runs as (Telegram forks report their own id while started from
        # Telegram's desktop file), so the sender's PID goes along to match
        # the task by process.
        self.bus.emit_signal(None, "/Bridge", "io.github.daydve.fancytasksng.BadgeUpdate", "UpdateSignal",
                             GLib.Variant("(sidu)", (app_id, count, progress, self._sender_pid(sender))))


def _quit_with_shell(bus):
    """Quits once the shell that started this helper is gone, or once a
    helper for a newer shell takes over our bus names. PR_SET_PDEATHSIG alone
    misses a shell that runs the helper through /bin/sh, which then outlives
    it."""
    # The parent, and its parent too when the parent is a /bin/sh in between.
    # Not every ancestor: one may well be a terminal that `plasmashell
    # --replace &` was run from, gone long before the shell.
    shell_pids = [os.getppid()]
    try:
        with open(f"/proc/{shell_pids[0]}/status", encoding="utf-8") as f:
            status = dict(line.rstrip("\n").split(":\t", 1) for line in f if ":\t" in line)
        if status.get("Name") in ("sh", "dash", "bash", "zsh"):
            shell_pids.append(int(status["PPid"]))
    except (OSError, ValueError, KeyError):
        pass

    def on_name_lost(connection, sender, path, iface, signal_name, params):
        name = params.unpack()[0]
        if name in (SERVICE_NAME, BRIDGE_NAME):
            log.info(f"{name} taken over by a newer helper, quitting")
            os._exit(0)

    bus.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameLost",
                         "/org/freedesktop/DBus", None, Gio.DBusSignalFlags.NONE, on_name_lost)

    def check_shell():
        if not all(os.path.exists(f"/proc/{pid}") for pid in shell_pids):
            log.info("the shell is gone, quitting")
            os._exit(0)
        return True

    GLib.timeout_add_seconds(5, check_shell)


def main():
    _apply_name_suffix(sys.argv)
    set_pdeathsig()
    _quit_with_shell(_get_session_bus())
    DesktopActionsService()
    BadgeBridge()
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        sys.exit(0)


if __name__ == "__main__":
    main()
