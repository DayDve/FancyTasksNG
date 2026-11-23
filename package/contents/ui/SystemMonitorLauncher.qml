/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import org.kde.taskmanager as TaskManager

// System Monitor, started like a pinned app, with startup feedback: a model
// of its own with it as the only launcher, so nothing gets pinned. It may not
// be installed (a package of its own): its launcher then has no app id (the
// name falls back to the file name), and the model follows apps being
// installed or removed.
QtObject {
    id: root

    property bool installed: false

    function open(): void {
        for (let row = 0; row < model.count; row++) {
            const index = model.makeModelIndex(row);
            if (model.data(index, TaskManager.AbstractTasksModel.IsLauncher)) {
                model.requestActivate(index);
                return;
            }
        }
    }

    readonly property TaskManager.TasksModel model: TaskManager.TasksModel {
        launcherList: ["applications:org.kde.plasma-systemmonitor.desktop"]
        hideActivatedLaunchers: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        // No windows, only the launcher: a screen that no window is on.
        // Launchers have no screen, and the filter lets them through.
        filterByScreen: true
        screenGeometry: Qt.rect(-100000, -100000, 1, 1)
    }

    readonly property Instantiator resolver: Instantiator {
        model: root.model
        delegate: QtObject {
            required property var model
            readonly property bool isLauncher: model.IsLauncher === true
            readonly property string appId: model.AppId || ""
            onAppIdChanged: if (isLauncher) root.installed = appId !== ""
            Component.onCompleted: if (isLauncher) root.installed = appId !== ""
        }
    }
}
