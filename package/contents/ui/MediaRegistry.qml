/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.mpris as Mpris

import "code/singletones"

// The one place that decides which task an audio stream or MPRIS player
// belongs to. Everything is attributed to a process (PID), not to a window
// or a group: a browser has one PID for all its windows, while VLC or mpv
// run one process per window.
QtObject {
    id: registry

    required property TaskManager.TasksModel tasksModel

    // Emitted whenever which streams belong to which task may have changed:
    // streams appearing or going away, tasks changing, parent PIDs arriving.
    // Mute/volume/corked changes don't emit it; those are bindable properties
    // on the stream objects themselves.
    signal attributionChanged()

    readonly property Mpris.Mpris2Model mpris2Model: Mpris.Mpris2Model { }

    readonly property Component audioStreamsComponent: Qt.createComponent("AudioStreams.qml")
    // null when plasma-pa isn't available.
    readonly property var audio: audioStreamsComponent.status === Component.Ready ? audioStreamsComponent.createObject(registry) : null

    readonly property int minimalVolume: audio ? audio.minimalVolume : 0
    readonly property int normalVolume: audio ? audio.normalVolume : 65536
    readonly property var preferredSink: audio ? audio.preferredSink : null

    // PIDs of every window on the system. A stream whose PID (or parent PID)
    // is in here is owned by that process and never handed to another task
    // through the app-name fallback - e.g. two separate Firefox installs both
    // report application.name "Firefox". Taken from an unfiltered model, not
    // the panel's: with "show only tasks from the current screen" (or desktop,
    // activity) the playing window may simply not be on this panel.
    property var windowPids: new Set()

    readonly property TaskManager.TasksModel allWindows: TaskManager.TasksModel {
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
    }

    // Stream PID -> parent PID, for stream PIDs that aren't a window's own:
    // Chromium-family browsers play audio from a utility child process.
    property var parentPids: ({})
    property var pendingParentPids: new Set()
    // Requests per PID that came back without an answer (helper not running
    // yet, or not at all); past maxParentPidAttempts the stream just keeps
    // the app-name fallback.
    property var parentPidAttempts: ({})
    readonly property int maxParentPidAttempts: 5

    readonly property Connections audioConnections: Connections {
        target: registry.audio
        function onStreamsChanged(): void {
            registry.scheduleUpdate();
        }
    }

    readonly property Connections tasksConnections: Connections {
        target: registry.allWindows
        function onRowsInserted(): void {
            registry.scheduleUpdate();
        }
        function onRowsRemoved(): void {
            registry.scheduleUpdate();
        }
        function onModelReset(): void {
            registry.scheduleUpdate();
        }
        function onDataChanged(topLeft, bottomRight, roles): void {
            if (roles.length === 0 || roles.indexOf(TaskManager.AbstractTasksModel.AppPid) !== -1) {
                registry.scheduleUpdate();
            }
        }
    }

    // The helper may still be starting when the first streams show up.
    readonly property Timer parentPidRetryTimer: Timer {
        interval: 2000
        onTriggered: registry.scheduleUpdate()
    }

    Component.onCompleted: scheduleUpdate()

    function scheduleUpdate(): void {
        Qt.callLater(registry.update);
    }

    function update(): void {
        const pids = new Set();
        const windows = registry.allWindows;
        for (let row = 0, rows = windows.rowCount(); row < rows; ++row) {
            const index = windows.makeModelIndex(row);
            if (windows.data(index, TaskManager.AbstractTasksModel.IsWindow) === true) {
                const pid = windows.data(index, TaskManager.AbstractTasksModel.AppPid);
                if (pid > 0) {
                    pids.add(pid);
                }
            }
        }
        registry.windowPids = pids;

        const streams = registry.audio ? registry.audio.allStreams() : [];
        const streamPids = new Set(streams.map(stream => stream.pid));
        for (const pid in registry.parentPids) {
            // PIDs get reused; drop entries no stream refers to anymore.
            if (!streamPids.has(Number(pid))) {
                delete registry.parentPids[pid];
            }
        }
        for (const pid in registry.parentPidAttempts) {
            if (!streamPids.has(Number(pid))) {
                delete registry.parentPidAttempts[pid];
            }
        }

        const unknown = [];
        for (const stream of streams) {
            if (stream.pid > 0 && !stream.portalAppId && !stream.isNotificationSound
                    && !pids.has(stream.pid) && !(stream.pid in registry.parentPids)
                    && !registry.pendingParentPids.has(stream.pid) && unknown.indexOf(stream.pid) === -1
                    && (registry.parentPidAttempts[stream.pid] ?? 0) < registry.maxParentPidAttempts) {
                unknown.push(stream.pid);
            }
        }
        if (unknown.length > 0 && !registry.parentPidRetryTimer.running) {
            registry.requestParentPids(unknown);
        }

        registry.attributionChanged();
    }

    function requestParentPids(pids): void {
        pids.forEach(pid => registry.pendingParentPids.add(pid));
        DesktopActionsManager.parentPids(pids, result => {
            pids.forEach(pid => registry.pendingParentPids.delete(pid));
            let resolved = false;
            let missing = false;
            pids.forEach(pid => {
                if (String(pid) in result) {
                    registry.parentPids[pid] = result[String(pid)];
                    resolved = true;
                } else {
                    registry.parentPidAttempts[pid] = (registry.parentPidAttempts[pid] ?? 0) + 1;
                    missing = true;
                }
            });
            if (resolved) {
                registry.scheduleUpdate();
            }
            // Space retries out instead of asking again right away.
            if (missing) {
                registry.parentPidRetryTimer.restart();
            }
        });
    }

    // The window process a stream belongs to, or 0 if it isn't one of ours.
    function ownerPid(stream): int {
        if (stream.portalAppId || stream.isNotificationSound) {
            return 0;
        }
        if (registry.windowPids.has(stream.pid)) {
            return stream.pid;
        }
        const parent = registry.parentPids[stream.pid];
        if (parent !== undefined && registry.windowPids.has(parent)) {
            return parent;
        }
        return 0;
    }

    // Streams belonging to an app with the given portal app id, any of the
    // given window PIDs, or - only for streams no window process owns - the
    // given app name. Notification sounds never belong to a task.
    function streamsFor(appId: string, pids: var, appName: string): var {
        if (!registry.audio) {
            return [];
        }
        const portalAppId = appId ? appId.replace(/\.desktop$/, "") : "";
        return registry.audio.allStreams().filter(stream => {
            if (stream.isNotificationSound) {
                return false;
            }
            if (stream.portalAppId) {
                return portalAppId !== "" && stream.portalAppId === portalAppId;
            }
            const owner = registry.ownerPid(stream);
            if (owner > 0) {
                return pids.indexOf(owner) !== -1;
            }
            return appName !== "" && stream.appName === appName;
        });
    }

    // Streams of a task as shown on its button: every window of a group.
    function streamsForTask(modelIndex): var {
        const model = registry.tasksModel;
        if (!model || !modelIndex || !modelIndex.valid) {
            return [];
        }
        const pids = [];
        const addPid = index => {
            const pid = model.data(index, TaskManager.AbstractTasksModel.AppPid);
            if (pid > 0 && pids.indexOf(pid) === -1) {
                pids.push(pid);
            }
        };
        const children = model.rowCount(modelIndex);
        if (children > 0) {
            for (let child = 0; child < children; ++child) {
                addPid(model.makeModelIndex(modelIndex.row, child));
            }
        } else {
            addPid(modelIndex);
        }
        return registry.streamsFor(model.data(modelIndex, TaskManager.AbstractTasksModel.AppId) ?? "",
                                   pids,
                                   model.data(modelIndex, TaskManager.AbstractTasksModel.AppName) ?? "");
    }

    // Streams of one window's process.
    function streamsForProcess(appId: string, pid: int, appName: string): var {
        return registry.streamsFor(appId, pid > 0 ? [pid] : [], appName);
    }

    function playerFor(launcherUrl, pid: int): var {
        if (!launcherUrl) {
            return null;
        }
        return registry.mpris2Model.playerForLauncherUrl(launcherUrl, pid);
    }

    function setMuted(streams, muted: bool): void {
        streams.forEach(stream => muted ? stream.mute() : stream.unmute());
    }

    function toggleMuted(streams): void {
        registry.setMuted(streams, !(streams.length > 0 && streams.every(stream => stream.muted)));
    }

    function setVolume(streams, volume: int): void {
        streams.forEach(stream => {
            if (stream && typeof stream.setVolume === 'function') {
                stream.setVolume(volume);
                if (volume > 0 && stream.muted) {
                    stream.unmute();
                }
            }
        });
    }

    // Steps each object's volume by the configured step; returns the last
    // one's {volume (0..1), muted}, or null.
    function adjustVolume(objects, increment: int): var {
        if (!registry.audio) {
            return null;
        }
        let result = null;
        objects.forEach(object => {
            result = registry.audio.adjustObjectVolume(object, increment);
        });
        return result;
    }
}
