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

    // Reactive store for unread counts and progress
    property var unityCounts: ({})
    property var unityProgress: ({})
    property int countVersion: 0

    Component.onCompleted: bridgeStarter.start()

    // Background process to sniff D-Bus signals that QML might miss
    Plasma5Support.DataSource {
        id: bridgeStarter
        engine: "executable"
        connectedSources: []
        
        function start() {
            let scriptPath = Qt.resolvedUrl("../unity_bridge.py").toString().replace(/^file:\/\//, "");
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
        
        function dbusUpdateSignal(appId, count, progress) {
            console.log("FancyTasksNG BadgeBridge received:", appId, count, progress);
            root.updateData(String(appId), count, progress);
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
     * Returns the progress (-1.0 if not visible) for a given AppId.
     */
    function getProgress(appId) {
        if (!appId) return -1.0;
        
        let strId = String(appId);
        let cleanId = strId;
        if (cleanId.startsWith("application://")) cleanId = cleanId.slice(14);
        if (cleanId.endsWith(".desktop")) cleanId = cleanId.slice(0, -8);
        if (cleanId.startsWith("applications:")) cleanId = cleanId.slice(13);

        if (unityProgress[strId] !== undefined) return unityProgress[strId];
        if (unityProgress[cleanId] !== undefined) return unityProgress[cleanId];
        if (unityProgress[cleanId + ".desktop"] !== undefined) return unityProgress[cleanId + ".desktop"];
        return -1.0;
    }

    /**
     * Updates the count and progress for an application and triggers UI refresh.
     */
    function updateData(appId, count, progress) {
        let strId = String(appId);
        let cleanId = strId;
        if (cleanId.startsWith("application://")) cleanId = cleanId.slice(14);
        if (cleanId.endsWith(".desktop")) cleanId = cleanId.slice(0, -8);
        
        // We must replace the object to trigger QML property change notifications
        let newCounts = {};
        for (let key in unityCounts) {
            newCounts[key] = unityCounts[key];
        }
        let newProgress = {};
        for (let key in unityProgress) {
            newProgress[key] = unityProgress[key];
        }
        
        newCounts[strId] = count;
        newCounts[cleanId] = count;
        newCounts[cleanId + ".desktop"] = count;

        newProgress[strId] = progress;
        newProgress[cleanId] = progress;
        newProgress[cleanId + ".desktop"] = progress;
        
        // Handle dot-notation names (e.g. io.github.name)
        if (cleanId.includes(".")) {
            let dots = cleanId.split(".");
            let baseName = dots[dots.length - 1];
            newCounts[baseName] = count;
            newCounts[baseName + ".desktop"] = count;
            newProgress[baseName] = progress;
            newProgress[baseName + ".desktop"] = progress;
        }

        root.unityCounts = newCounts;
        root.unityProgress = newProgress;
        root.countVersion++;
    }
}
