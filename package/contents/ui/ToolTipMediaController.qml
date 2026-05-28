/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris

Item {
    id: controller

    // Input Properties
    required property var toolTipDelegate
    required property int appPid
    property string appId: ""
    property string title: ""
    property var audioStreamManager
    property var mpris2Model
    property int index
    property var thumbnailWinId
    property bool isPlayingAudio: false

    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration ? Plasmoid.configuration.indicateAudioStreams : false

    // Media Player Data
    readonly property var playerData: {
        if (!mpris2Model || !toolTipDelegate)
            return null;
        if (!mpris2Model.playerForLauncherUrl)
            return null;
        return mpris2Model.playerForLauncherUrl(toolTipDelegate.launcherUrl, appPid);
    }
    readonly property bool titleIncludesTrack: playerData && playerData.track && title.includes(playerData.track)

    // Audio Streams
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)

    // Cached and smoothed volume properties to prevent slider flicker
    property int cachedVolume: 0
    readonly property int appVolume: {
        if (hasAudioStream && audioStreams.length > 0) {
            var validStreams = audioStreams.filter(s => s && typeof s.volume !== 'undefined');
            if (validStreams.length > 0) {
                return validStreams.reduce((max, s) => Math.max(max, s.volume), 0);
            }
        }
        return cachedVolume;
    }

    function hasWindowSpecificStream(winId) {
        if (!winId || !hasAudioStream)
            return false;
        return audioStreams.some(stream => stream.windowId === winId);
    }

    Timer {
        id: streamClearTimer
        interval: 1000
        repeat: false
        onTriggered: controller.audioStreams = []
    }

    function updateAudioStreams(args) {
        if (args && args.delay) {
            delayAudioStreamIndicator = true;
        }
        var currentForce = (args && args.force);

        if (!controller.audioStreamManager) {
            streamClearTimer.stop();
            audioStreams = [];
            return;
        }
        var pa = controller.audioStreamManager.item;
        if (!pa) {
            streamClearTimer.stop();
            audioStreams = [];
            return;
        }

        // Check appid first for app using portal
        var streams = pa.streamsForAppId(appId.replace(/\.desktop/, ''));
        if (!streams.length) {
            streams = pa.streamsForPid(appPid);
        }



        if (streams.length > 0) {
            var activeKey = appPid;
            var savedVol = pa.getCachedVolume(activeKey);

            var validStreams = streams.filter(s => s && typeof s.volume !== 'undefined');
            if (validStreams.length > 0) {
                var maxVol = validStreams.reduce((max, s) => Math.max(max, s.volume), 0);
                cachedVolume = maxVol;
            }

            var currentMax = streams.reduce((max, s) => Math.max(max, s.volume), 0);
            var seemsReset = (currentMax > 60000 && savedVol > 0 && Math.abs(currentMax - savedVol) > 2000);

            if ((streamClearTimer.running || seemsReset) && savedVol > 0) {
                streams.forEach(s => s.setVolume(savedVol));
            }

            streamClearTimer.stop();
            audioStreams = streams;
        } else {
            if (audioStreams.length > 0) {
                streamClearTimer.restart();
            } else {
                streamClearTimer.stop();
                audioStreams = [];
            }
        }
    }

    function toggleMuted() {
        if (muted) {
            audioStreams.forEach(item => item.unmute());
        } else {
            audioStreams.forEach(item => item.mute());
        }
    }

    function adjustAppVolume(increment) {
        if (!hasAudioStream || !audioStreamManager || !audioStreamManager.item) return;
        let pa = audioStreamManager.item;
        audioStreams.forEach(item => {
            if (item && typeof item.setVolume === 'function') {
                let newVol = Math.max(pa.minimalVolume, Math.min(pa.normalVolume, item.volume + increment));
                item.setVolume(newVol);
                if (newVol > 0 && item.muted) {
                    item.unmute();
                }
                cachedVolume = newVol;
            }
        });
    }

    function setVolume(value) {
        if (!hasAudioStream) return;
        audioStreams.forEach(item => {
            if (item && typeof item.setVolume === 'function') {
                item.setVolume(value);
                if (value > 0 && item.muted) {
                    item.unmute();
                }
            }
        });
        cachedVolume = value;
    }

    Connections {
        target: controller.audioStreamManager ? controller.audioStreamManager.item : null
        ignoreUnknownSignals: true
        function onStreamsChanged() {
            controller.updateAudioStreams({
                delay: true
            });
        }
    }

    onAppPidChanged: updateAudioStreams({
        delay: false,
        force: true
    })
    onAppIdChanged: updateAudioStreams({
        delay: false,
        force: true
    })
    Component.onCompleted: {
        updateAudioStreams({
            delay: false,
            force: true
        });
    }

    // Effective control state calculation
    readonly property bool showPlayerControls: index !== -1 && playerData && playerData.canControl && (hasWindowSpecificStream(thumbnailWinId) || titleIncludesTrack || (toolTipDelegate.windows.length === 1 && (isPlayingAudio || hasAudioStream))) && (playerData.playbackStatus === Mpris.PlaybackStatus.Playing || playerData.playbackStatus === Mpris.PlaybackStatus.Paused || (playerData.track && playerData.track.length > 0))
    readonly property bool showVolumeControls: index !== -1 && audioStreamManager && audioStreamManager.item !== null && audioIndicatorsEnabled && (hasWindowSpecificStream(thumbnailWinId) || titleIncludesTrack || (toolTipDelegate.windows.length === 1 && hasAudioStream))
    readonly property bool controlsAreEffective: Plasmoid.configuration && Plasmoid.configuration.showMediaControls && (showPlayerControls || showVolumeControls)
}

