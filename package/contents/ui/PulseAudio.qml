/*
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.volume

QtObject {
    id: pulseAudio
    property var backend

    signal streamsChanged()
    
    Component.onCompleted: {
        console.log("PulseAudio: Initialized. Backend:", backend);
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
            readonly property bool muted: model.Muted
            // whether there is actually nothing going on on that stream
            readonly property bool corked: model.Corked
            readonly property int volume: model.Volume
            
            // Allow setting volume/mute
            function mute(): void {
                model.Muted = true;
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
                var cached = pulseAudio.getCachedVolume(pid);
                if (cached > 0) { 
                    setVolume(cached);
                }
            }
            
            onVolumeChanged: {
                if (pid > 0) {
                     pulseAudio.saveVolume(pid, volume);
                }
            }
        }

        onObjectAdded: (index, object) => pulseAudio.streamsChanged()
        onObjectRemoved: (index, object) => pulseAudio.streamsChanged()
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
        
        // 2. If no streams found, try checking parent PID (legacy/complex apps)
        // DISABLED: Causes anomaly where file managers (Dolphin) claim streams of launched apps (VLC).
        /*
        if (streams.length === 0) {
             streams = findStreams(stream => {
                // If the stream has no PID or we can't find it, try to resolve parent PID via backend
                // Note: Calling backend.parentPid might be expensive if done repeatedly, but we only do it on miss.
                let parentPid = backend.parentPid(stream.pid);
                return parentPid === pid;
             });
        }
        */
        
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
