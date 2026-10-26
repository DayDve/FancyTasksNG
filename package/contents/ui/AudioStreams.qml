/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.volume as PlasmaPa

// The PlasmaPa-backed half of MediaRegistry, loaded separately so the
// registry (and MPRIS) keeps working when plasma-pa isn't installed.
// Which task a stream belongs to is decided in MediaRegistry, not here.
QtObject {
    id: audioStreams

    signal streamsChanged()

    readonly property QtObject globalConfig: PlasmaPa.GlobalConfig { }

    readonly property PlasmaPa.SinkModel sinksModel: PlasmaPa.SinkModel { }
    readonly property var preferredSink: sinksModel.preferredObject || sinksModel.preferredSink || (sinksModel.count > 0 ? sinksModel.data(sinksModel.index(0, 0), 257 /*ItemRole*/) : null)

    readonly property int minimalVolume: PlasmaPa.PulseAudio.MinimalVolume ?? 0
    readonly property int normalVolume: PlasmaPa.PulseAudio.NormalVolume ?? 65536

    // QtObject has no default property, hence adding the Instantiator to one explicitly.
    readonly property Instantiator instantiator: Instantiator {
        model: PlasmaPa.PulseObjectFilterModel {
            filters: [ { role: "VirtualStream", value: false } ]
            sourceModel: PlasmaPa.SinkInputModel {}
        }

        delegate: QtObject {
            id: delegate
            required property var model

            // PipeWire-native clients (mpv, Telegram) only carry the process
            // properties on the client, not on the stream itself.
            readonly property int pid: model.Client?.properties["application.process.id"] ?? 0
            readonly property string binary: model.Client?.properties["application.process.binary"] ?? ""
            readonly property string appName: model.Client?.properties["application.name"] ?? ""
            readonly property string portalAppId: model.Client?.properties["pipewire.access.portal.app_id"] ?? ""
            // Per-stream name: Firefox and mpv put the page or window title
            // here, Chromium-family browsers just "Playback".
            readonly property string mediaName: model.Name ?? ""
            // Notification sounds are played by plasmashell on the app's
            // behalf; the app they belong to is only in the stream's own
            // application.name, not the client's.
            readonly property bool isNotificationSound: binary === "plasmashell"
            readonly property string streamAppName: model.Properties?.["application.name"] ?? appName

            readonly property int x11Xid: parseInt(model.Client?.properties["window.x11.xid"] ?? "0")
            readonly property int windowId: x11Xid > 0 ? x11Xid : 0
            readonly property bool muted: model.Muted
            // whether there is actually nothing going on on that stream
            readonly property bool corked: model.Corked
            readonly property int volume: model.Volume

            function mute(): void {
                model.Muted = true;
            }
            function unmute(): void {
                model.Muted = false;
            }
            function setVolume(vol): void {
                model.Volume = vol;
            }

            onPidChanged: {
                if (pid > 0) restoreVolume();
            }

            function restoreVolume() {
                var cached = audioStreams.getCachedVolume(pid);
                if (cached > 0) {
                    setVolume(cached);
                }
            }

            onVolumeChanged: {
                if (pid > 0) {
                     audioStreams.saveVolume(pid, volume);
                }
            }
        }

        onObjectAdded: (index, object) => audioStreams.streamsChanged()
        onObjectRemoved: (index, object) => audioStreams.streamsChanged()
    }

    function allStreams(): var {
        const results = [];
        for (let i = 0, count = instantiator.count; i < count; ++i) {
            const stream = instantiator.objectAt(i);
            if (stream) {
                results.push(stream);
            }
        }
        return results;
    }

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

    function adjustObjectVolume(obj, increment) {
        if (!obj) return;

        const step = (normalVolume - minimalVolume) * (globalConfig["volumeStep"] || 5) / 100;
        const currentVolume = obj.Volume !== undefined ? obj.Volume : (obj.volume !== undefined ? obj.volume : 0);
        const newVolume = Math.round(Math.max(minimalVolume, Math.min(currentVolume + (step * increment), normalVolume)));

        if (obj.setVolume !== undefined) {
            obj.setVolume(newVolume);
        } else if (obj.volume !== undefined) {
            obj.volume = newVolume;
        } else if (obj.Volume !== undefined) {
            obj.Volume = newVolume;
        }

        const isCurrentlyMuted = obj.Muted !== undefined ? obj.Muted : (obj.muted !== undefined ? obj.muted : false);

        if (newVolume > minimalVolume && isCurrentlyMuted) {
            if (obj.unmute !== undefined) obj.unmute();
            else if (obj.Muted !== undefined) obj.Muted = false;
            else if (obj.muted !== undefined) obj.muted = false;
        } else if (newVolume <= minimalVolume && !isCurrentlyMuted) {
            if (obj.mute !== undefined) obj.mute();
            else if (obj.Muted !== undefined) obj.Muted = true;
            else if (obj.muted !== undefined) obj.muted = true;
        }
        return {
            volume: (newVolume - minimalVolume) / (normalVolume - minimalVolume),
            muted: obj.Muted !== undefined ? obj.Muted : (obj.muted !== undefined ? obj.muted : false)
        };
    }
}
