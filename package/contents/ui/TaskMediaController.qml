/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.plasmoid

Item {
    id: controller

    // Input Properties
    property var taskItem: null

    // Audio stream manager from tasksRoot
    readonly property var audioStreamManager: taskItem && taskItem.tasksRoot ? taskItem.tasksRoot.audioStreamManager : null
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration ? Plasmoid.configuration.indicateAudioStreams : false

    // Exposed Audio State Properties
    property var audioStreams: []
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    // Query and update PulseAudio streams matching the task
    function updateAudioStreams(): void {
        if (!taskItem) return;
        
        const tasksRoot = taskItem.tasksRoot;
        if (!tasksRoot) return;

        const pa = tasksRoot.audioStreamManager.item;
        if (!pa || !taskItem.model) {
            audioStreams = [];
            return;
        }

        // Try matching by AppId, then AppPid, then AppName
        let streams = pa.streamsForAppId(taskItem.model.AppId);
        if (!streams.length) {
            streams = pa.streamsForPid(taskItem.model.AppPid);
            
            if (!streams.length) {
                 streams = pa.streamsForAppName(taskItem.model.AppName);
            }
        }

        audioStreams = streams;
    }

    // Toggle mute state for all application streams
    function toggleMuted(): void {
        if (muted) {
            audioStreams.forEach(item => item.unmute());
        } else {
            audioStreams.forEach(item => item.mute());
        }
    }

    // Adjust application volume or system global volume
    function adjustVolume(increment, isGlobal): void {
        if (!taskItem) return;

        const tasksRoot = taskItem.tasksRoot;
        if (!tasksRoot) return;

        const audioManager = tasksRoot.audioStreamManager.item;
        if (!audioManager) return;

        const streams = isGlobal ? (audioManager.preferredSink ? [audioManager.preferredSink] : []) : audioStreams;
        if (streams.length === 0) return;
        
        let lastResult = null;
        streams.forEach(stream => {
            lastResult = audioManager.adjustObjectVolume(stream, increment);
        });

        if (lastResult) {
            if (isGlobal) {
                if (tasksRoot.globalVolumeOverlay && tasksRoot.globalVolumeOverlay.item) {
                    tasksRoot.globalVolumeOverlay.item.volume = lastResult.volume;
                    tasksRoot.globalVolumeOverlay.item.muted = lastResult.muted;
                    tasksRoot.globalVolumeOverlay.item.show();
                }
            } else if (taskItem.volumeOverlay) {
                taskItem.volumeOverlay.volume = lastResult.volume;
                taskItem.volumeOverlay.muted = lastResult.muted;
                taskItem.volumeOverlay.show();
            }
        }
    }

    // Watch for stream changes globally
    Connections {
        target: controller.audioStreamManager ? controller.audioStreamManager.item : null
        ignoreUnknownSignals: true
        function onStreamsChanged(): void {
            controller.updateAudioStreams();
        }
    }

    // Listen to task metadata and state changes
    Connections {
        target: taskItem
        ignoreUnknownSignals: true
        function onPidChanged(): void {
            if (taskItem.model) controller.updateAudioStreams();
        }
        function onAppNameChanged(): void {
            if (taskItem.model) controller.updateAudioStreams();
        }
        function onIsWindowChanged(): void {
            if (taskItem.model && taskItem.model.IsWindow) {
                controller.updateAudioStreams();
            }
        }
    }

    Component.onCompleted: {
        if (taskItem && !taskItem.inPopup && taskItem.model && taskItem.model.IsWindow) {
            updateAudioStreams();
        }
    }
}
