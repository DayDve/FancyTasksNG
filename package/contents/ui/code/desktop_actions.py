#!/usr/bin/env python3
"""
Desktop Actions Helper — reads .desktop jump list actions and
KActivities recent documents for contextual menu population.

Protocol (line-based JSON over stdin/stdout):
  Request:  {"launcherUrl": "file:///usr/share/applications/org.kde.dolphin.desktop"}
  Response: {"jumpList": [...], "recentDocs": [...]}

Each jumpList item: {"name": str, "icon": str, "exec": str}
Each recentDocs item: {"name": str, "url": str, "icon": str}
"""

import configparser
import json
import mimetypes
import os
import sqlite3
import subprocess
import sys
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

    # Determine system languages (e.g. from LANGUAGE or LANG)
    lang_env = os.environ.get("LANGUAGE", "") or os.environ.get("LANG", "")
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
        exec_cmd = cp.get(section, "Exec", fallback="")

        if not name:
            continue

        actions.append({"name": name, "icon": icon, "exec": exec_cmd, "actionId": aid})

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


def get_current_activity():
    """Get current KDE activity ID via qdbus6."""
    try:
        result = subprocess.run(
            ["qdbus6", "org.kde.ActivityManager",
             "/ActivityManager/Activities", "CurrentActivity"],
            capture_output=True, text=True, timeout=2
        )
        return result.stdout.strip()
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
            SELECT rsc.targettedResource, ri.mimetype, rsc.lastUpdate
            FROM ResourceScoreCache rsc
            LEFT JOIN ResourceInfo ri ON rsc.targettedResource = ri.targettedResource
            WHERE rsc.initiatingAgent = ?
            AND rsc.usedActivity = ?
            ORDER BY rsc.lastUpdate DESC
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

            # KActivities sometimes returns directories, but recent documents usually exclude them
            # unless it's a file manager. Dolphin IS a file manager, so we allow directories.
            if os.path.isdir(file_path) and storage_id != 'org.kde.dolphin':
                continue

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


def clear_recent_documents(desktop_path):
    """Clear recent documents for this application from the database."""
    if not KACTIVITIES_DB.is_file():
        return False

    storage_id = get_storage_id(desktop_path)
    if not storage_id:
        return False

    activity = get_current_activity()
    if not activity:
        return False

    try:
        conn = sqlite3.connect(str(KACTIVITIES_DB))
        cur = conn.cursor()
        cur.execute("""
            DELETE FROM ResourceScoreCache 
            WHERE initiatingAgent = ? AND usedActivity = ?
        """, (storage_id, activity))
        conn.commit()
        conn.close()
        
        # Trigger KDED to reload stats (optional, usually updates itself)
        subprocess.run(
            ["qdbus6", "org.kde.ActivityManager", "/ActivityManager/Resources/Scoring", "org.freedesktop.DBus.Properties.EmitChanged"],
            capture_output=True, timeout=1
        )
        return True
    except Exception as e:
        print(f"desktop_actions: DB clear error: {e}", file=sys.stderr)
        return False


import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import subprocess
import ctypes
import signal

def set_pdeathsig():
    """Ensure the process dies when its parent (plasmashell) dies."""
    try:
        libc = ctypes.CDLL("libc.so.6")
        libc.prctl(1, signal.SIGTERM) # 1 is PR_SET_PDEATHSIG
    except Exception:
        pass

class DesktopActionsService(dbus.service.Object):
    def __init__(self):
        try:
            self.bus = dbus.SessionBus()
            self.bus_name = dbus.service.BusName('io.github.daydve.fancytasksng.DesktopActions', bus=self.bus)
            dbus.service.Object.__init__(self, self.bus_name, '/DesktopActions')
            print("DesktopActionsService ready", flush=True)
        except Exception as e:
            print(f"DesktopActionsService error: {e}", file=sys.stderr)
            sys.exit(1)

    @dbus.service.method('io.github.daydve.fancytasksng.DesktopActions', in_signature='s', out_signature='s')
    def Query(self, launcher_url):
        desktop_path = resolve_launcher_url(launcher_url)
        jump_list = get_jump_list_actions(desktop_path) if desktop_path else []
        recent_docs = get_recent_documents(desktop_path) if desktop_path else []
        data = {
            "jumpList": jump_list,
            "recentDocs": recent_docs,
            "desktopPath": desktop_path or "",
        }
        return json.dumps(data)

    @dbus.service.method('io.github.daydve.fancytasksng.DesktopActions', in_signature='s', out_signature='')
    def ClearRecent(self, launcher_url):
        desktop_path = resolve_launcher_url(launcher_url)
        if desktop_path:
            clear_recent_documents(desktop_path)

    @dbus.service.method('io.github.daydve.fancytasksng.DesktopActions', in_signature='s', out_signature='')
    def Execute(self, exec_cmd):
        try:
            subprocess.Popen(exec_cmd, shell=True, start_new_session=True)
        except Exception as e:
            print(f"Execute error: {e}", file=sys.stderr)

    @dbus.service.method('io.github.daydve.fancytasksng.DesktopActions', in_signature='s', out_signature='')
    def OpenUrl(self, url):
        try:
            subprocess.Popen(["kioclient", "exec", url], start_new_session=True)
        except Exception as e:
            print(f"OpenUrl error: {e}", file=sys.stderr)

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
