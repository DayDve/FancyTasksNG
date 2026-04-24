/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma Singleton
import QtQuick
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.plasma5support as Plasma5Support

/**
 * BadgeManager: Unified aggregator for taskbar badges.
 * Intercepts Unity-style signals via a Python helper script.
 */
Item {
    id: root

    // Reactive store for unread counts
    property var unityCounts: ({})
    property int countVersion: 0

    Component.onCompleted: bridgeStarter.start()

    // Background process to sniff D-Bus signals that QML might miss
    Plasma5Support.DataSource {
        id: bridgeStarter
        engine: "executable"
        connectedSources: []
        
        function start() {
            let scriptPath = Qt.resolvedUrl("../unity_bridge.py").toString();
            if (scriptPath.startsWith("file://")) scriptPath = scriptPath.slice(7);
            connectSource("python3 " + scriptPath);
        }
        
        onNewData: (sourceName, data) => {
            if (data.stderr) console.log("FancyTasksNG BadgeBridge Error:", data.stderr);
        }
    }

    // Listener for internal bridge signals
    DBus.SignalWatcher {
        id: bridgeWatcher
        service: "io.github.daydve.fancytasksng.Bridge"
        path: "/Bridge"
        iface: "io.github.daydve.fancytasksng.BadgeUpdate"
        
        function dbusUpdateSignal(appId, count) {
            root.updateCount(String(appId), count);
        }
    }

    /**
     * Returns the unread count for a given AppId.
     * Tries multiple name variations for maximum compatibility.
     */
    function getUnreadCount(appId) {
        if (!appId) return 0;
        
        let strId = String(appId);
        let cleanId = strId;
        if (cleanId.startsWith("application://")) cleanId = cleanId.slice(14);
        if (cleanId.endsWith(".desktop")) cleanId = cleanId.slice(0, -8);
        if (cleanId.startsWith("applications:")) cleanId = cleanId.slice(13);

        return unityCounts[strId] || unityCounts[cleanId] || unityCounts[cleanId + ".desktop"] || 0;
    }

    /**
     * Updates the count for an application and triggers UI refresh.
     */
    function updateCount(appId, count) {
        let strId = String(appId);
        let cleanId = strId;
        if (cleanId.startsWith("application://")) cleanId = cleanId.slice(14);
        if (cleanId.endsWith(".desktop")) cleanId = cleanId.slice(0, -8);
        
        // We must replace the object to trigger QML property change notifications
        let newCounts = {};
        for (let key in unityCounts) {
            newCounts[key] = unityCounts[key];
        }
        
        newCounts[strId] = count;
        newCounts[cleanId] = count;
        newCounts[cleanId + ".desktop"] = count;
        
        // Handle dot-notation names (e.g. io.github.name)
        if (cleanId.includes(".")) {
            let dots = cleanId.split(".");
            let baseName = dots[dots.length - 1];
            newCounts[baseName] = count;
            newCounts[baseName + ".desktop"] = count;
        }

        root.unityCounts = newCounts;
        root.countVersion++;
    }
}
