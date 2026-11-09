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

Interface io.github.daydve.fancytasksng.Config:
  ExportConfig(path, content) -> "OK" or "ERROR: ..."
  ImportConfig(path) -> file content or "ERROR: ..."
"""

import configparser
import hashlib
import json
import mimetypes
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

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import Gio, GLib
from pathlib import Path
from urllib.parse import unquote, urlparse

KACTIVITIES_DB = Path.home() / ".local/share/kactivitymanagerd/resources/database"
DESKTOP_DIRS = [
    "/usr/share/applications",
    "/usr/local/share/applications",
    str(Path.home() / ".local/share/applications"),
    # Flatpak
    "/var/lib/flatpak/exports/share/applications",
    str(Path.home() / ".local/share/flatpak/exports/share/applications"),
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

    # Bare name (e.g. "org.kde.dolphin.desktop")
    if parsed.scheme == "" and not os.path.sep in url_str:
        name = url_str if url_str.endswith(".desktop") else url_str + ".desktop"
        for d in DESKTOP_DIRS:
            candidate = os.path.join(d, name)
            if os.path.isfile(candidate):
                return candidate

    return None


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
        _session_bus = dbus.SessionBus()
    return _session_bus


def get_current_activity():
    """Get current KDE activity ID via D-Bus."""
    try:
        bus = _get_session_bus()
        # Bounded timeout: this runs on the service's single mainloop, so a hung
        # ActivityManager must not be able to freeze every tooltip/menu query.
        activity = bus.call_blocking(
            "org.kde.ActivityManager",
            "/ActivityManager/Activities",
            "org.kde.ActivityManager.Activities",
            "CurrentActivity", "", [],
            timeout=2.0,
        )
        return str(activity)
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
        print(f"desktop_actions: DB error: {e}", file=sys.stderr)

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
                        if db_name in target and os.path.isfile(target):
                            return Path(target)
                    except (OSError, PermissionError):
                        continue
            except (OSError, PermissionError):
                continue
    except Exception as e:
        print(f"desktop_actions: proc scan error: {e}", file=sys.stderr)
    return None


def extract_favicons(history_items, favicons_db_path, browser_type):
    """Extract favicons for history items and save them to local cache."""
    if not history_items or not favicons_db_path or not os.path.exists(favicons_db_path):
        return history_items

    cache_dir = Path.home() / ".cache" / "fancytasksng" / "favicons"
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
        shutil.copy2(favicons_db_path, temp_db)
        conn = sqlite3.connect(temp_db)
        cursor = conn.cursor()

        for url, item, cached_png, cached_failed in urls_to_query:
            blob = None
            if browser_type == "firefox":
                cursor.execute("""
                    SELECT i.data FROM moz_icons i
                    JOIN moz_icons_to_pages itp ON itp.icon_id = i.id
                    JOIN moz_pages_w_icons p ON p.id = itp.page_id
                    WHERE p.page_url = ? AND i.data IS NOT NULL
                    ORDER BY i.width DESC LIMIT 1
                """, (url,))
                row = cursor.fetchone()
                if row:
                    blob = row[0]
            else:
                cursor.execute("""
                    SELECT b.image_data FROM favicon_bitmaps b
                    JOIN icon_mapping m ON m.icon_id = b.icon_id
                    WHERE m.page_url = ? AND b.image_data IS NOT NULL
                    ORDER BY b.width DESC LIMIT 1
                """, (url,))
                row = cursor.fetchone()
                if row:
                    blob = row[0]

            if blob:
                try:
                    with open(cached_png, "wb") as f:
                        f.write(blob)
                    item["icon"] = f"file://{cached_png}"
                except Exception as e:
                    print(f"desktop_actions: failed to write favicon cache: {e}", file=sys.stderr)
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
        print(f"desktop_actions: extract_favicons error: {e}", file=sys.stderr)
    finally:
        if temp_db.exists():
            try:
                temp_db.unlink()
            except OSError:
                pass

    return history_items


def get_firefox_recent(limit=10, app_pid=0):
    """Fetch recent Firefox history with active profile detection via process info and fallback."""
    # 1. Try to find active profile via /proc using app_pid
    active_db = find_active_db_from_proc("places.sqlite", app_pid=app_pid)
    if active_db:
        history = fetch_sqlite_history(active_db, """
            SELECT DISTINCT url, title FROM moz_places 
            WHERE last_visit_date IS NOT NULL AND title IS NOT NULL AND url LIKE 'http%'
            ORDER BY last_visit_date DESC LIMIT ?
        """, "places_ff_active.sqlite", limit)
        return extract_favicons(history, active_db.parent / "favicons.sqlite", "firefox")

    # 2. Fallback to searching directories
    search_dirs = [
        Path.home() / ".mozilla" / "firefox",
        Path.home() / ".config" / "mozilla" / "firefox",
        Path.home() / ".var" / "app" / "org.mozilla.firefox" / ".mozilla" / "firefox",
        Path.home() / ".var" / "app" / "org.mozilla.firefox-trunk" / ".mozilla" / "firefox",
        Path.home() / "snap" / "firefox" / "common" / ".mozilla" / "firefox"
    ]
    
    candidates = []
    for d in search_dirs:
        if d.exists() and (d / "profiles.ini").exists():
            try:
                config = configparser.ConfigParser()
                config.read(d / "profiles.ini")
                for section in config.sections():
                    p_dir = config[section].get("Path") if section.startswith("Profile") else config[section].get("Default") if section.startswith("Install") else None
                    if p_dir:
                        full_path = d / p_dir if config[section].get("IsRelative", "1") == "1" else Path(p_dir)
                        if (full_path / "places.sqlite").exists():
                            candidates.append(full_path / "places.sqlite")
            except Exception: continue

    if not candidates: return []
    
    # Pick most recent
    db_path = max(candidates, key=lambda p: p.stat().st_mtime)
    
    query = """
        SELECT DISTINCT url, title FROM moz_places 
        WHERE last_visit_date IS NOT NULL AND title IS NOT NULL AND url LIKE 'http%'
        ORDER BY last_visit_date DESC LIMIT ?
    """
    history = fetch_sqlite_history(db_path, query, "places_ff_recent.sqlite", limit)
    return extract_favicons(history, db_path.parent / "favicons.sqlite", "firefox")


def get_chromium_recent(browser_name, limit=10, app_pid=0):
    """Fetch recent history for Chromium-based browsers with active profile detection."""
    # 1. Try to find active profile via /proc using app_pid
    active_db = find_active_db_from_proc("History", app_pid=app_pid)
    if active_db:
        history = fetch_sqlite_history(active_db, """
            SELECT DISTINCT url, title FROM urls 
            WHERE last_visit_time IS NOT NULL AND title IS NOT NULL AND url LIKE 'http%'
            ORDER BY last_visit_time DESC LIMIT ?
        """, f"history_{browser_name}_active.sqlite", limit)
        return extract_favicons(history, active_db.parent / "Favicons", "chromium")

    # 2. Fallback to searching directories
    configs = {
        "chrome": [
            Path.home() / ".config" / "google-chrome",
            Path.home() / ".var" / "app" / "com.google.Chrome" / "config" / "google-chrome"
        ],
        "chromium": [
            Path.home() / ".config" / "chromium",
            Path.home() / ".var" / "app" / "org.chromium.Chromium" / "config" / "chromium"
        ],
        "brave": [
            Path.home() / ".config" / "BraveSoftware" / "Brave-Browser",
            Path.home() / ".var" / "app" / "com.brave.Browser" / "config" / "BraveSoftware" / "Brave-Browser"
        ],
        "vivaldi": [
            Path.home() / ".config" / "vivaldi",
            Path.home() / ".var" / "app" / "com.vivaldi.Vivaldi" / "config" / "vivaldi"
        ],
        "edge": [
            Path.home() / ".config" / "microsoft-edge",
            Path.home() / ".var" / "app" / "com.microsoft.Edge" / "config" / "microsoft-edge"
        ],
        "opera": [
            Path.home() / ".config" / "opera",
            Path.home() / ".var" / "app" / "com.opera.Opera" / "config" / "opera"
        ],
    }
    
    base_dirs = configs.get(browser_name, [])
    candidates = []
    for base in base_dirs:
        if not base.exists(): continue
        # Common profile names
        for profile in ["Default", "Profile 1", "Profile 2", "."]:
            history_db = base / profile / "History"
            if history_db.exists():
                candidates.append(history_db)

    if not candidates: return []
    
    db_path = max(candidates, key=lambda p: p.stat().st_mtime)
    query = """
        SELECT DISTINCT url, title FROM urls 
        WHERE last_visit_time IS NOT NULL AND title IS NOT NULL AND url LIKE 'http%'
        ORDER BY last_visit_time DESC LIMIT ?
    """
    history = fetch_sqlite_history(db_path, query, f"history_{browser_name}_recent.sqlite", limit)
    return extract_favicons(history, db_path.parent / "Favicons", "chromium")


def fetch_sqlite_history(db_path, query, temp_name, limit=10):
    """Generic helper to fetch history from a SQLite DB using a temporary copy."""
    docs = []
    # Use tempfile to avoid collisions and permission issues in /tmp
    fd, temp_path = tempfile.mkstemp(prefix=temp_name)
    os.close(fd)
    temp_db = Path(temp_path)
    
    try:
        shutil.copy2(db_path, temp_db)
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
        print(f"desktop_actions: fetch_history error ({db_path}): {e}", file=sys.stderr)
    finally:
        if temp_db.exists():
            try:
                temp_db.unlink()
            except OSError:
                pass
    return docs


def clear_recent_documents(desktop_path):
    """Clear recent documents for this application from both score cache and event history."""
    if not KACTIVITIES_DB.is_file():
        return False

    storage_id = get_storage_id(desktop_path)
    if not storage_id:
        return False

    activity = get_current_activity()
    if not activity:
        return False

    try:
        # Use a context manager to ensure the connection is closed properly.
        # We need to delete from BOTH tables to keep the daemon happy.
        with sqlite3.connect(str(KACTIVITIES_DB), timeout=5) as conn:
            cur = conn.cursor()
            # 1. Clear the score cache
            cur.execute("""
                DELETE FROM ResourceScoreCache 
                WHERE initiatingAgent = ? AND usedActivity = ?
            """, (storage_id, activity))
            
            # 2. Clear the event history
            cur.execute("""
                DELETE FROM ResourceEvent 
                WHERE initiatingAgent = ? AND usedActivity = ?
            """, (storage_id, activity))
            
            # 3. Clear the resource links (this is likely what was missing for full reset)
            cur.execute("""
                DELETE FROM ResourceLink 
                WHERE initiatingAgent = ? AND usedActivity = ?
            """, (storage_id, activity))
            
            conn.commit()
            # Ensure changes are written and visible to others
            cur.execute("PRAGMA wal_checkpoint(FULL)")
        
        # Notify the daemon that stats have changed via D-Bus
        try:
            bus = _get_session_bus()
            bus.call_blocking(
                "org.kde.ActivityManager",
                "/ActivityManager/Resources/Scoring",
                "org.freedesktop.DBus.Properties",
                "EmitChanged", "s", ["org.kde.ActivityManager.ResourcesScoring"],
                timeout=1.0,
            )
        except Exception:
            pass  # Non-critical: daemon will detect DB changes on next query
        
        return True
    except Exception as e:
        print(f"desktop_actions: DB clear error: {e}", file=sys.stderr)
        return False


def get_kde_places():
    """Parse ~/.local/share/user-places.xbel to get KDE Places."""
    places = []
    xbel_path = Path.home() / ".local/share/user-places.xbel"
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


class NotAllowed(dbus.exceptions.DBusException):
    _dbus_error_name = "io.github.daydve.fancytasksng.Error.NotAllowed"


class DesktopActionsService(dbus.service.Object):
    """Only the widget's own shell may call this service: it launches
    programs, reads and writes files and returns browsing history, so any
    other client of the session bus (a Flatpak app with bus access, say)
    must not be able to use it."""

    def __init__(self):
        self.allowed_pids = _ancestor_pids()
        self.sender_allowed = {}
        try:
            self.bus = dbus.SessionBus()
            self.bus_name = dbus.service.BusName('io.github.daydve.fancytasksng.DesktopActions', bus=self.bus,
                                                 do_not_queue=True)
            dbus.service.Object.__init__(self, self.bus_name, '/DesktopActions')
            print("DesktopActionsService ready", flush=True)
        except Exception as e:
            print(f"DesktopActionsService error: {e}", file=sys.stderr)
            sys.exit(1)

    def _check_caller(self, sender):
        # Unique bus names are never reused, so the verdict can be cached.
        if sender not in self.sender_allowed:
            try:
                pid = int(self.bus.call_blocking(
                    'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                    'GetConnectionUnixProcessID', 's', (sender,), timeout=2.0))
            except dbus.exceptions.DBusException:
                pid = 0
            self.sender_allowed[sender] = pid in self.allowed_pids
        if not self.sender_allowed[sender]:
            raise NotAllowed(f"{sender} is not the shell running this widget")

    @dbus.service.method('io.github.daydve.fancytasksng.DesktopActions', in_signature='sbii', out_signature='s', sender_keyword='sender')
    def Query(self, launcher_url, show_history, limit, app_pid, sender=None):
        self._check_caller(sender)
        desktop_path = resolve_launcher_url(launcher_url)
        jump_list = get_jump_list_actions(desktop_path) if desktop_path else []
        
        browser_history = []
        if desktop_path and show_history:
            d_lower = desktop_path.lower()
            if "firefox" in d_lower or "mozilla" in d_lower or "ffpwa" in d_lower:
                browser_history = get_firefox_recent(limit, app_pid)
            elif "chrome" in d_lower:
                browser_history = get_chromium_recent("chrome", limit, app_pid)
            elif "brave" in d_lower:
                browser_history = get_chromium_recent("brave", limit, app_pid)
            elif "vivaldi" in d_lower:
                browser_history = get_chromium_recent("vivaldi", limit, app_pid)
            elif "chromium" in d_lower:
                browser_history = get_chromium_recent("chromium", limit, app_pid)
            elif "edge" in d_lower:
                browser_history = get_chromium_recent("edge", limit, app_pid)
            elif "opera" in d_lower:
                browser_history = get_chromium_recent("opera", limit, app_pid)
        
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
        }
        return json.dumps(data)

    @dbus.service.method('io.github.daydve.fancytasksng.DesktopActions', in_signature='s', out_signature='', sender_keyword='sender')
    def ClearRecent(self, launcher_url, sender=None):
        self._check_caller(sender)
        desktop_path = resolve_launcher_url(launcher_url)
        if desktop_path:
            clear_recent_documents(desktop_path)

    @dbus.service.method('io.github.daydve.fancytasksng.DesktopActions', in_signature='ss', out_signature='', sender_keyword='sender')
    def LaunchAction(self, launcher_url, action_id, sender=None):
        """Run one of the [Desktop Action ...] entries of an app's .desktop file."""
        self._check_caller(sender)
        desktop_path = resolve_launcher_url(launcher_url)
        if not desktop_path:
            return
        try:
            app = Gio.DesktopAppInfo.new_from_filename(desktop_path)
            if app and action_id in app.list_actions():
                app.launch_action(action_id, None)
        except GLib.Error as e:
            print(f"LaunchAction error: {e}", file=sys.stderr)

    @dbus.service.method('io.github.daydve.fancytasksng.DesktopActions', in_signature='s', out_signature='s', sender_keyword='sender')
    def ParentPids(self, pids_csv, sender=None):
        """Map comma-separated PIDs to their parent PIDs (JSON object).

        QML can't read /proc itself. Chromium-family browsers play audio
        from a utility child process, so its stream PID only matches a
        window through its parent. PIDs that no longer exist are omitted.
        """
        self._check_caller(sender)
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

    @dbus.service.method('io.github.daydve.fancytasksng.DesktopActions', in_signature='is', out_signature='b', sender_keyword='sender')
    def ActivateBrowserTab(self, browser_pid, title, sender=None):
        """Switch a browser to the tab with the given title; True on success.

        Goes through the Plasma Browser Integration extension: each browser
        it runs in starts its own native host, a child of the browser, and
        every host offers KRunner's tab search on /TabsRunner. A browser
        names a tab's audio stream after the page, so this finds the tab a
        stream plays in - the one way to get to a tab that isn't the one
        the browser's single MPRIS player follows.
        """
        self._check_caller(sender)
        if browser_pid <= 0 or not title:
            return False
        try:
            bus = dbus.SessionBus()
            bus_daemon = bus.get_object('org.freedesktop.DBus', '/org/freedesktop/DBus')
            names = bus_daemon.ListNames(dbus_interface='org.freedesktop.DBus')
            for name in names:
                if not str(name).startswith('org.kde.plasma.browser_integration'):
                    continue
                try:
                    host_pid = int(bus_daemon.GetConnectionUnixProcessID(name, dbus_interface='org.freedesktop.DBus'))
                    with open(f"/proc/{host_pid}/status", encoding="utf-8") as f:
                        parent = next((int(line.split()[1]) for line in f if line.startswith("PPid:")), 0)
                    if parent != browser_pid:
                        continue
                    runner = dbus.Interface(bus.get_object(name, '/TabsRunner'), 'org.kde.krunner1')
                    matches = runner.Match(title, timeout=2)
                    # (id, text, icon name, type, relevance, properties)
                    exact = [m for m in matches if str(m[1]) == title]
                    chosen = exact[0] if exact else (matches[0] if len(matches) == 1 else None)
                    if chosen is None:
                        return False
                    runner.Run(chosen[0], '', timeout=2)
                    return True
                except (dbus.exceptions.DBusException, OSError, ValueError, StopIteration):
                    continue
        except dbus.exceptions.DBusException as e:
            print(f"ActivateBrowserTab error: {e}", file=sys.stderr)
        return False

    @dbus.service.method('io.github.daydve.fancytasksng.Config', in_signature='ss', out_signature='s', sender_keyword='sender')
    def ExportConfig(self, path, content, sender=None):
        self._check_caller(sender)
        try:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            return "OK"
        except Exception as e:
            return f"ERROR: {e}"

    @dbus.service.method('io.github.daydve.fancytasksng.Config', in_signature='s', out_signature='s', sender_keyword='sender')
    def ImportConfig(self, path, sender=None):
        self._check_caller(sender)
        try:
            with open(path, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            return f"ERROR: {e}"

    @dbus.service.method('io.github.daydve.fancytasksng.DesktopActions', in_signature='ss', out_signature='', sender_keyword='sender')
    def OpenUrl(self, url, preferred_app, sender=None):
        self._check_caller(sender)
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
            print(f"OpenUrl error: {e}", file=sys.stderr)


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


def main():
    set_pdeathsig()
    DBusGMainLoop(set_as_default=True)
    service = DesktopActionsService()
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        sys.exit(0)

if __name__ == "__main__":
    main()
