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

    readonly property var mediaRegistry: taskItem && taskItem.tasksRoot ? taskItem.tasksRoot.mediaRegistry : null
    readonly property var config: Plasmoid.configuration
    readonly property bool audioIndicatorsEnabled: config ? config.indicateAudioStreams : false

    // Exposed Audio State Properties
    property var audioStreams: []
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    // Streams of every window of the task (all of a group's processes)
    function updateAudioStreams(): void {
        if (!taskItem || !mediaRegistry || !taskItem.model) {
            audioStreams = [];
            return;
        }
        audioStreams = mediaRegistry.streamsForTask(taskItem.modelIndex());
    }

    function toggleMuted(): void {
        if (mediaRegistry) {
            mediaRegistry.toggleMuted(audioStreams);
        }
    }

    // Adjust application volume or system global volume
    function adjustVolume(increment, isGlobal): void {
        if (!taskItem || !mediaRegistry) return;

        const tasksRoot = taskItem.tasksRoot;
        const streams = isGlobal ? (mediaRegistry.preferredSink ? [mediaRegistry.preferredSink] : []) : audioStreams;
        if (streams.length === 0) return;

        const lastResult = mediaRegistry.adjustVolume(streams, increment);
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

    Connections {
        target: controller.mediaRegistry
        function onAttributionChanged(): void {
            controller.updateAudioStreams();
        }
    }

    // Listen to task metadata and state changes
    Connections {
        target: controller.taskItem
        ignoreUnknownSignals: true
        function onPidChanged(): void {
            if (controller.taskItem.model) controller.updateAudioStreams();
        }
        function onAppNameChanged(): void {
            if (controller.taskItem.model) controller.updateAudioStreams();
        }
        function onIsWindowChanged(): void {
            if (controller.taskItem.model && controller.taskItem.model.IsWindow) {
                controller.updateAudioStreams();
            }
        }
    }

    // Task.qml assigns taskItem only after the Loader has created us. Pinned
    // launchers need this too: their app's streams are found by app id, and
    // Shift+wheel over one would otherwise have nothing to adjust until the
    // next attribution change.
    onTaskItemChanged: {
        if (taskItem && taskItem.model) {
            updateAudioStreams();
        }
    }
}
