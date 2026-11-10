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

    readonly property int appVolume: audioStreams.reduce((max, s) => Math.max(max, s.volume ?? 0), 0)

    // Wheel deltas carried over between events, so a touchpad's small ones
    // add up to whole steps instead of getting lost.
    property real wheelDelta: 0

    function updateAudioStreams() {
        if (!controller.mediaRegistry || !controller.mediaRegistry.audio) {
            audioStreams = [];
            return;
        }

        var streams = controller.mediaRegistry.streamsForProcess(appId, appPid, toolTipDelegate ? toolTipDelegate.appName : "");

        // Dropped streams go right away: holding on to them kept objects
        // PulseAudio had already removed. The tooltip's own hide delay
        // (ToolTipInstance.controlsHideTimer) keeps the controls from flickering.
        audioStreams = streams;
    }

    function toggleMuted() {
        if (mediaRegistry)
            mediaRegistry.toggleMuted(audioStreams);
    }

    // Steps the volume by the configured step per wheel notch, the same way
    // as the wheel over a task or its speaker badge.
    function wheelVolume(angleDelta: real): void {
        wheelDelta += angleDelta;
        const steps = Math.trunc(wheelDelta / 120);
        if (steps === 0)
            return;
        wheelDelta -= steps * 120;
        if (hasAudioStream && mediaRegistry)
            mediaRegistry.adjustVolume(audioStreams, steps);
    }

    function setVolume(value) {
        if (hasAudioStream && mediaRegistry)
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

