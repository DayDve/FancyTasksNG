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
    // Plasma hands out an app's player to any of its processes when none
    // matches by PID (a flatpak's player reports the D-Bus proxy's PID). In a
    // group that would put it on every window of the app, so there it has to
    // be this process's own player or come with a sign it plays here.
    property bool strictPlayer: false

    readonly property var config: Plasmoid.configuration
    readonly property bool audioIndicatorsEnabled: config ? config.indicateAudioStreams : false

    // Media Player Data
    readonly property var playerData: mediaRegistry && toolTipDelegate ? mediaRegistry.playerFor(toolTipDelegate.launcherUrl, appPid) : null
    readonly property bool titleIncludesTrack: playerData && playerData.track && title.includes(playerData.track)

    // Audio Streams
    property var audioStreams: []
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)

    // While userVolumeChangeTimer is running, expose cachedVolume instead of live PA
    // to prevent the slider from showing intermediate PA values during rapid scrolling.
    property int cachedVolume: 0
    readonly property int appVolume: {
        if (hasAudioStream && audioStreams.length > 0 && !userVolumeChangeTimer.running) {
            let validStreams = audioStreams.filter(s => typeof s.volume !== 'undefined');
            if (validStreams.length > 0) {
                return validStreams.reduce((max, s) => Math.max(max, s.volume), 0);
            }
        }
        return cachedVolume;
    }

    Timer {
        id: userVolumeChangeTimer
        // Cooldown after a user volume change. During this window appVolume returns
        // cachedVolume instead of reading live PA streams, which may still carry
        // intermediate values from earlier commands in a rapid scroll sequence.
        interval: 500
        repeat: false
        onTriggered: {
            var validStreams = controller.audioStreams.filter(s => typeof s.volume !== 'undefined');
            if (validStreams.length > 0)
                controller.cachedVolume = validStreams.reduce((max, s) => Math.max(max, s.volume), 0);
        }
    }

    function updateAudioStreams() {
        if (!controller.mediaRegistry || !controller.mediaRegistry.audio) {
            audioStreams = [];
            return;
        }

        var streams = controller.mediaRegistry.streamsForProcess(appId, appPid, toolTipDelegate ? toolTipDelegate.appName : "");

        if (streams.length > 0) {
            // Only update cachedVolume from PA when not actively changing volume.
            // While userVolumeChangeTimer is running we keep cachedVolume as-is so
            // the slider stays at the intended position until PA fully converges.
            if (!userVolumeChangeTimer.running) {
                let validStreams = streams.filter(s => typeof s.volume !== 'undefined');
                if (validStreams.length > 0)
                    cachedVolume = validStreams.reduce((max, s) => Math.max(max, s.volume), 0);
            }
        }
        // Dropped streams go right away: holding on to them kept objects
        // PulseAudio had already removed. The tooltip's own hide delay
        // (ToolTipInstance.controlsHideTimer) keeps the controls from flickering.
        audioStreams = streams;
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
            controller.updateAudioStreams();
        }
    }

    onAppPidChanged: updateAudioStreams()
    onAppIdChanged: updateAudioStreams()
    Component.onCompleted: updateAudioStreams()

    // Effective control state calculation
    readonly property bool showPlayerControls: {
        if (index === -1 || !playerData || !playerData.canControl)
            return false;
        
        var hasStatus = playerData.playbackStatus === Mpris.PlaybackStatus.Playing || 
                        playerData.playbackStatus === Mpris.PlaybackStatus.Paused || 
                        (playerData.track && playerData.track.length > 0);
        if (!hasStatus)
            return false;

        return !strictPlayer || mediaRegistry.ownsPlayer(playerData, appPid) || hasAudioStream || titleIncludesTrack;
    }
    readonly property bool showVolumeControls: index !== -1 && mediaRegistry && mediaRegistry.audio !== null && audioIndicatorsEnabled && hasAudioStream
    readonly property bool controlsAreEffective: config && config.showMediaControls && (showPlayerControls || showVolumeControls)
}

