/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma Singleton
import QtQuick
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.plasma5support as Plasma5Support

/**
 * DesktopActionsManager — provides desktop file jump list actions
 * and recent documents via a Python helper over DBus.
 */
Item {
    id: root

    property var cache: ({})

    Plasma5Support.DataSource {
        id: dbusDaemonStarter
        engine: "executable"
        connectedSources: []
        Component.onCompleted: {
            // Start the DBus daemon ONCE
            let scriptPath = Qt.resolvedUrl("../desktop_actions.py").toString();
            if (scriptPath.startsWith("file://")) scriptPath = scriptPath.slice(7);
            connectSource("python3 '" + scriptPath + "'");
        }
    }

    function query(launcherUrl, callback) {
        const key = String(launcherUrl);

        if (key in cache) {
            if (callback) callback(cache[key]);
            return;
        }

        const pendingReply = DBus.SessionBus.asyncCall({
            "service": "io.github.daydve.fancytasksng.DesktopActions",
            "path": "/DesktopActions",
            "iface": "io.github.daydve.fancytasksng.DesktopActions",
            "member": "Query",
            "arguments": [key]
        });

        pendingReply.finished.connect(() => {
            const stdoutValue = pendingReply.value;
            // pendingReply.value is a QVariant, which JS might treat as an object. We safely cast to String.
            const stdout = stdoutValue !== undefined && stdoutValue !== null ? String(stdoutValue).trim() : "";
            
            // Native DBus might return empty array (coerced to "") or empty string on errors (e.g. service starting up)
            if (!stdout) {
                if (callback) callback({jumpList: [], recentDocs: []});
            } else {
                let result = null;
                try {
                    result = JSON.parse(stdout);
                    root.cache[key] = result;
                } catch (e) {
                    console.warn("DesktopActionsManager JSON parse error:", e, stdout);
                    result = {jumpList: [], recentDocs: []};
                }
                
                // Call callback outside the try-catch so UI errors aren't swallowed!
                if (callback) callback(result);
            }
            pendingReply.destroy();
        });
    }

    function invalidate(launcherUrl) {
        if (launcherUrl) {
            delete cache[String(launcherUrl)];
        } else {
            cache = {};
        }
    }

    function clearRecentDocuments(launcherUrl) {
        const key = String(launcherUrl);
        const pendingReply = DBus.SessionBus.asyncCall({
            "service": "io.github.daydve.fancytasksng.DesktopActions",
            "path": "/DesktopActions",
            "iface": "io.github.daydve.fancytasksng.DesktopActions",
            "member": "ClearRecent",
            "arguments": [key]
        });
        pendingReply.finished.connect(() => {
            invalidate(launcherUrl);
            pendingReply.destroy();
        });
    }

    function executeCommand(execCmd) {
        const pendingReply = DBus.SessionBus.asyncCall({
            "service": "io.github.daydve.fancytasksng.DesktopActions",
            "path": "/DesktopActions",
            "iface": "io.github.daydve.fancytasksng.DesktopActions",
            "member": "Execute",
            "arguments": [execCmd]
        });
        pendingReply.finished.connect(() => pendingReply.destroy());
    }

    function openUrl(url) {
        const pendingReply = DBus.SessionBus.asyncCall({
            "service": "io.github.daydve.fancytasksng.DesktopActions",
            "path": "/DesktopActions",
            "iface": "io.github.daydve.fancytasksng.DesktopActions",
            "member": "OpenUrl",
            "arguments": [url]
        });
        pendingReply.finished.connect(() => pendingReply.destroy());
    }
}
