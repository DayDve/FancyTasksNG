/*
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.volume

QtObject {
    id: audioStreamManager

    signal streamsChanged()
    
    Component.onCompleted: {
    }
    
    // QtObject has no default property, hence adding the Instantiator to one explicitly.
    readonly property Instantiator instantiator: Instantiator {
        model: PulseObjectFilterModel {
            filters: [ { role: "VirtualStream", value: false } ]
            sourceModel: SinkInputModel {}
        }

        delegate: QtObject {
            id: delegate
            required property var model
            
            readonly property int pid: model.Client?.properties["application.process.id"] ?? 0
            readonly property string appName: model.Client?.properties["application.name"] ?? ""
            readonly property string portalAppId: model.Client?.properties["pipewire.access.portal.app_id"] ?? ""
            
            // Expose Window IDs for matching
            readonly property int x11Xid: parseInt(model.Client?.properties["window.x11.xid"] ?? "0")
            readonly property int windowId: x11Xid > 0 ? x11Xid : 0
            readonly property bool muted: model.Muted
            // whether there is actually nothing going on on that stream
            readonly property bool corked: model.Corked
            readonly property int volume: model.Volume
            
            // Allow setting volume/mute
            function mute(): void {
                model.Muted = true;
            }
            function unmute(): void {
                model.Muted = false;
            }
            function setVolume(vol): void {
                model.Volume = vol;
            }
            Component.onCompleted: {
                if (pid > 0) restoreVolume();
            }
            
            onPidChanged: {
                if (pid > 0) restoreVolume();
            }
            
            function restoreVolume() {
                var cached = audioStreamManager.getCachedVolume(pid);
                if (cached > 0) { 
                    setVolume(cached);
                }
            }
            
            onVolumeChanged: {
                if (pid > 0) {
                     audioStreamManager.saveVolume(pid, volume);
                }
            }
        }

        onObjectAdded: (index, object) => audioStreamManager.streamsChanged()
        onObjectRemoved: (index, object) => audioStreamManager.streamsChanged()
    }

    function streamsForAppId(appId: string): var {
        if (!appId) return [];
        return findStreams(stream => stream.portalAppId === appId);
    }

    function streamsForAppName(appName: string): var {
        if (!appName) return [];
        return findStreams(stream => stream.appName === appName);
    }

    function streamsForPid(pid: int): var {
        if (pid <= 0) return [];
        
        // 1. Try direct PID match
        let streams = findStreams(stream => stream.pid === pid && !stream.portalAppId);
        
        
        return streams;
    }

    function findStreams(predicate): var {
        const results = [];
        for (let i = 0, count = instantiator.count; i < count; ++i) {
            const stream = instantiator.objectAt(i);
            if (stream && predicate(stream)) {
                results.push(stream);
            }
        }

        return results;
    }

    // Expose volume constants if valid, otherwise fallback
    readonly property int minimalVolume: PulseAudio.MinimalVolume ?? 0
    readonly property int normalVolume: PulseAudio.NormalVolume ?? 65536

    // Persistent Volume Cache (Key: WinID or PID)
    property var volumeCache: ({})

    function saveVolume(key, vol: int) {
        if (key) {
            volumeCache[key] = vol;
        }
    }

    function getCachedVolume(key): int {
        if (key && volumeCache[key] !== undefined) {
            return volumeCache[key];
        }
        return -1;
    }
}
