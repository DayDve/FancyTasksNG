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
    property var mediaRegistry
    property int index
    property var thumbnailWinId
    property bool isPlayingAudio: false

    readonly property var config: Plasmoid.configuration
    readonly property bool audioIndicatorsEnabled: config ? config.indicateAudioStreams : false

    // Media Player Data
    readonly property var playerData: mediaRegistry && toolTipDelegate ? mediaRegistry.playerFor(toolTipDelegate.launcherUrl, appPid) : null
    readonly property bool titleIncludesTrack: playerData && playerData.track && title.includes(playerData.track)

    // Audio Streams
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)

    // While userVolumeChangeTimer is running, expose cachedVolume instead of live PA
    // to prevent the slider from showing intermediate PA values during rapid scrolling.
    property int cachedVolume: 0
    readonly property int appVolume: {
        if (hasAudioStream && audioStreams.length > 0 && !userVolumeChangeTimer.running) {
            let validStreams = audioStreams.filter(s => s && typeof s.volume !== 'undefined');
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

    Timer {
        id: userVolumeChangeTimer
        // Cooldown after a user volume change. During this window appVolume returns
        // cachedVolume instead of reading live PA streams, which may still carry
        // intermediate values from earlier commands in a rapid scroll sequence.
        interval: 500
        repeat: false
        onTriggered: {
            var validStreams = controller.audioStreams.filter(s => s && typeof s.volume !== 'undefined');
            if (validStreams.length > 0)
                controller.cachedVolume = validStreams.reduce((max, s) => Math.max(max, s.volume), 0);
        }
    }

    function updateAudioStreams(args) {
        if (args && args.delay) {
            delayAudioStreamIndicator = true;
        }
        var currentForce = (args && args.force);

        if (!controller.mediaRegistry || !controller.mediaRegistry.audio) {
            streamClearTimer.stop();
            audioStreams = [];
            return;
        }

        var streams = controller.mediaRegistry.streamsForProcess(appId, appPid, toolTipDelegate ? toolTipDelegate.appName : "");

        if (streams.length > 0) {
            // Only update cachedVolume from PA when not actively changing volume.
            // While userVolumeChangeTimer is running we keep cachedVolume as-is so
            // the slider stays at the intended position until PA fully converges.
            if (!userVolumeChangeTimer.running) {
                let validStreams = streams.filter(s => s && typeof s.volume !== 'undefined');
                if (validStreams.length > 0)
                    cachedVolume = validStreams.reduce((max, s) => Math.max(max, s.volume), 0);
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
        if (mediaRegistry)
            mediaRegistry.toggleMuted(audioStreams);
    }

    function adjustAppVolume(increment) {
        if (!hasAudioStream || !mediaRegistry)
            return;
        // Compute an absolute target and delegate to setVolume — same path as the slider.
        // appVolume returns the live PA value when idle, or cachedVolume during rapid
        // scrolling, so accumulation is always correct without any separate caching logic.
        setVolume(Math.max(mediaRegistry.minimalVolume, Math.min(mediaRegistry.normalVolume, appVolume + increment)));
    }

    function setVolume(value) {
        if (!hasAudioStream)
            return;
        cachedVolume = value;
        userVolumeChangeTimer.restart();
        if (mediaRegistry)
            mediaRegistry.setVolume(audioStreams, value);
    }

    Connections {
        target: controller.mediaRegistry
        function onAttributionChanged() {
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
    readonly property bool showPlayerControls: {
        if (index === -1 || !playerData || !playerData.canControl)
            return false;
        
        var hasStatus = playerData.playbackStatus === Mpris.PlaybackStatus.Playing || 
                        playerData.playbackStatus === Mpris.PlaybackStatus.Paused || 
                        (playerData.track && playerData.track.length > 0);
        if (!hasStatus)
            return false;

        // If it's a single window tooltip or global group controller, always allow controls
        if (!toolTipDelegate || !toolTipDelegate.isGroup || !thumbnailWinId)
            return true;

        // For individual windows inside a group, require strict stream or title matching
        return hasWindowSpecificStream(thumbnailWinId) || titleIncludesTrack || isPlayingAudio || hasAudioStream;
    }
    readonly property bool showVolumeControls: index !== -1 && mediaRegistry && mediaRegistry.audio !== null && audioIndicatorsEnabled && (hasWindowSpecificStream(thumbnailWinId) || titleIncludesTrack || hasAudioStream)
    readonly property bool controlsAreEffective: config && config.showMediaControls && (showPlayerControls || showVolumeControls)
}

