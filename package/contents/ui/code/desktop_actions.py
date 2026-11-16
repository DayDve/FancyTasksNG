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
  ParentPids(pidsCsv) -> JSON object {pid: parentPid}
  ActivateBrowserTab(browserPid, title) -> bool
  ListApps() -> JSON array of installed apps

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
DESKTOP_DIRS = [
    "/usr/share/applications",
    "/usr/local/share/applications",
    str(DATA_HOME / "applications"),
    # Flatpak
    "/var/lib/flatpak/exports/share/applications",
    str(DATA_HOME / "flatpak/exports/share/applications"),
]
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


def resolve_launcher_url(url_str):
    """Convert a launcher URL to a local .desktop file path."""
    if not url_str:
        return None

    parsed = urlparse(url_str)

    if parsed.scheme == "file":
        path = unquote(parsed.path)
        if os.path.isfile(path):
            return path

    if parsed.scheme == "applications" or parsed.scheme == "":
        name = parsed.path.lstrip("/")
        if not name.endswith(".desktop"):
            name += ".desktop"
        for d in DESKTOP_DIRS:
            candidate = os.path.join(d, name)
            if os.path.isfile(candidate):
                return candidate

    return None


def get_categories(desktop_path):
    """The Categories list of a .desktop file."""
    cp = configparser.RawConfigParser(interpolation=None)
    cp.optionxform = str
    try:
        cp.read(desktop_path, encoding="utf-8")
    except Exception:
        return []
    value = cp.get("Desktop Entry", "Categories", fallback="")
    return [c.strip() for c in value.split(";") if c.strip()]


def get_jump_list_actions(desktop_path):
    """Parse [Desktop Action ...] sections from a .desktop file."""
    actions = []
    if not desktop_path or not os.path.isfile(desktop_path):
        return actions

    cp = configparser.RawConfigParser()
    cp.optionxform = str  # preserve case
    try:
        cp.read(desktop_path, encoding="utf-8")
    except Exception:
        return actions

    action_ids = cp.get("Desktop Entry", "Actions", fallback="").strip(";").split(";")
    action_ids = [a.strip() for a in action_ids if a.strip()]

    # Determine system languages (e.g. from LANGUAGE, LC_ALL, LC_MESSAGES, or LANG)
    lang_envs = [
        os.environ.get("LANGUAGE", ""),
        os.environ.get("LC_ALL", ""),
        os.environ.get("LC_MESSAGES", ""),
        os.environ.get("LANG", "")
    ]
    lang_env = ":".join(filter(None, lang_envs))
    langs = []
    for l in lang_env.split(":"):
        l = l.split(".")[0].strip() # e.g. ru_RU.UTF-8 -> ru_RU
        if l and l not in langs:
            langs.append(l)
            short = l.split("_")[0]
            if short not in langs:
                langs.append(short)

    for aid in action_ids:
        section = f"Desktop Action {aid}"
        if not cp.has_section(section):
            continue

        name = None
        # Try localized names
        for l in langs:
            name = cp.get(section, f"Name[{l}]", fallback=None)
            if name is not None:
                break
        
        if name is None:
            name = cp.get(section, "Name", fallback="")
            
        icon = cp.get(section, "Icon", fallback="")
        if not name:
            continue

        actions.append({"name": name, "icon": icon, "actionId": aid})

    return actions


def get_storage_id(desktop_path):
    """Extract the storage ID (agent name) from a .desktop file path.
    KActivities uses the desktop file basename without .desktop as the agent."""
    if not desktop_path:
        return None
    basename = os.path.basename(desktop_path)
    if basename.endswith(".desktop"):
        return basename[:-8]
    return basename


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


def get_recent_documents(desktop_path):
    """Query KActivities database for recent documents opened by this app."""
    docs = []
    if not KACTIVITIES_DB.is_file():
        return docs

    storage_id = get_storage_id(desktop_path)
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


def clear_recent_documents(desktop_path):
    """Forget this app's recent documents in the current activity.

    Goes through kactivitymanagerd, which owns the database: writing to it
    behind the daemon's back can race with its own writes and leaves its
    caches stale."""
    storage_id = get_storage_id(desktop_path)
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
    """Takes a bus name without queueing; True if this process owns it."""
    try:
        reply = _dbus_call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                           "RequestName", GLib.Variant("(su)", (name, 4)), "(u)")  # 4: DO_NOT_QUEUE
        return reply[0] == 1  # PRIMARY_OWNER
    except GLib.Error as e:
        log.warning(f"could not request {name}: {e}")
        return False


class DesktopActionsService:
    """Only the widget's own shell may call this service: it launches
    programs, reads and writes files and returns browsing history, so any
    other client of the session bus (a Flatpak app with bus access, say)
    must not be able to use it."""

    def __init__(self):
        self.allowed_pids = _ancestor_pids()
        self.sender_allowed = {}
        self.bus = _get_session_bus()
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
        desktop_path = resolve_launcher_url(launcher_url)
        jump_list = get_jump_list_actions(desktop_path) if desktop_path else []
        
        browser_history = []
        if desktop_path and show_history:
            browser = detect_browser(desktop_path)
            if browser:
                browser_history = get_browser_recent(browser, limit, app_pid)

        raw_recent = get_recent_documents(desktop_path) if desktop_path else []
        
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
            "categories": get_categories(desktop_path) if desktop_path else [],
        }
        return json.dumps(data)

    def ClearRecent(self, launcher_url):
        desktop_path = resolve_launcher_url(launcher_url)
        if desktop_path:
            clear_recent_documents(desktop_path)

    def LaunchAction(self, launcher_url, action_id):
        """Run one of the [Desktop Action ...] entries of an app's .desktop file."""
        desktop_path = resolve_launcher_url(launcher_url)
        if not desktop_path:
            return
        try:
            app = Gio.DesktopAppInfo.new_from_filename(desktop_path)
            if app and action_id in app.list_actions():
                app.launch_action(action_id, None)
        except GLib.Error as e:
            log.warning(f"LaunchAction error: {e}")

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

    def ListApps(self):
        return json.dumps(list_applications())

    def OpenUrl(self, url, preferred_app):
        try:
            desktop_path = resolve_launcher_url(preferred_app)
            app = Gio.DesktopAppInfo.new_from_filename(desktop_path) if desktop_path else None
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
        # is on the bus. If it's taken (Plasma's own task manager), the
        # signals are still received through the subscription below.
        if _request_name("com.canonical.Unity"):
            log.info("registered as com.canonical.Unity")
        else:
            log.info("com.canonical.Unity already owned, listening passively")
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


def main():
    _apply_name_suffix(sys.argv)
    set_pdeathsig()
    DesktopActionsService()
    BadgeBridge()
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        sys.exit(0)


if __name__ == "__main__":
    main()
