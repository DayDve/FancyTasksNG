/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasmoid

import "code/tools.js" as TaskTools

DropArea {
    id: dropArea
    signal urlsDropped(var urls)

    property var target
    property Item ignoredItem
    property var hoveredItem
    property bool isGroupDialog: false
    property bool moved: false

    property alias handleWheelEvents: wheelHandler.handleWheelEvents

    required property var tasks
    required property var tasksModel

    //ignore anything that is neither internal to TaskManager or a URL list
    onEntered: event => {
        if (event.formats.indexOf("text/x-plasmoidservicename") >= 0) {
            event.accepted = false;
        }
        target.animating = false;
    }

    onPositionChanged: event => {
        if (target.animating) {
            return;
        }

        let above;
        if (isGroupDialog) {
            above = target.itemAt(event.x, event.y);
        } else {
            above = target.childAt(event.x, event.y);
        }

        if (!above) {
            hoveredItem = null;
            activationTimer.stop();

            return;
        }

        // If we're mixing launcher tasks with other tasks and are moving
        // a (small) launcher task across a non-launcher task, don't allow
        // the latter to be the move target twice in a row for a while, as
        // it will naturally be moved underneath the cursor as result of the
        // initial move, due to being far larger than the launcher delegate.
        // TODO: This restriction (minus the timer, which improves things)
        // has been proven out in the EITM fork, but could be improved later
        // by tracking the cursor movement vector and allowing the drag if
        // the movement direction has reversed, establishing user intent to
        // move back.
        if (!Plasmoid.configuration.separateLaunchers
                && dropArea.tasks.dragSource?.model.IsLauncher
                && !above.model.IsLauncher
                && above === dropArea.ignoredItem) {
            return;
        } else {
            dropArea.ignoredItem = null;
        }

        if (dropArea.tasksModel.sortMode === TaskManager.TasksModel.SortManual && dropArea.tasks.dragSource) {
            // Reject drags between different TaskList instances.
            if (dropArea.tasks.dragSource.parent !== above.parent) {
                return;
            }

            const insertAt = above.index;

            if (dropArea.tasks.dragSource !== above && dropArea.tasks.dragSource.index !== insertAt) {
                if (dropArea.tasks.groupDialog) {
                    dropArea.tasksModel.move(dropArea.tasks.dragSource.index, insertAt,
                        dropArea.tasksModel.makeModelIndex(dropArea.tasks.groupDialog.visualParent.index));
                } else {
                    dropArea.tasksModel.move(dropArea.tasks.dragSource.index, insertAt);
                }

                dropArea.ignoredItem = above;
                ignoreItemTimer.restart();
            }
        } else if (!dropArea.tasks.dragSource && hoveredItem !== above) {
            hoveredItem = above;
            activationTimer.restart();
        }
    }

    onExited: {
        hoveredItem = null;
        activationTimer.stop();
    }

    onDropped: event => {
        // Reject internal drops.
        if (event.formats.indexOf("application/x-orgkdeplasmataskmanager_taskbuttonitem") >= 0) {
            event.accepted = false;
            return;
        }

        // Reject plasmoid drops.
        if (event.formats.indexOf("text/x-plasmoidservicename") >= 0) {
            event.accepted = false;
            return;
        }

        if (event.hasUrls) {
            urlsDropped(event.urls);
            return;
        }
    }

    Connections {
        target: dropArea.tasks

        function onDragSourceChanged(): void {
            if (!dropArea.tasks.dragSource) {
                dropArea.ignoredItem = null;
                ignoreItemTimer.stop();
            }
        }
    }

    Timer {
        id: ignoreItemTimer

        repeat: false
        interval: 750

        onTriggered: {
            dropArea.ignoredItem = null;
        }
    }

    Timer {
        id: activationTimer

        interval: 250
        repeat: false

        onTriggered: {
            if (parent.hoveredItem.model.IsGroupParent) {
                TaskTools.createGroupDialog(parent.hoveredItem, dropArea.tasks);
            } else if (!parent.hoveredItem.model.IsLauncher) {
                dropArea.tasksModel.requestActivate(parent.hoveredItem.modelIndex());
            }
        }
    }

    WheelHandler {
        id: wheelHandler

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        property bool handleWheelEvents: true

        enabled: handleWheelEvents && Plasmoid.configuration.wheelEnabled

        onWheel: event => {
            // magic number 15 for common "one scroll"
            // See https://doc.qt.io/qt-6/qml-qtquick-wheelhandler.html#rotation-prop
            let increment = 0;
            while (rotation >= 15) {
                rotation -= 15;
                increment++;
            }
            while (rotation <= -15) {
                rotation += 15;
                increment--;
            }
            const anchor = dropArea.target.childAt(event.x, event.y);
            while (increment !== 0) {
                TaskTools.activateNextPrevTask(anchor, increment < 0, Plasmoid.configuration.wheelSkipMinimized, dropArea.tasks);
                increment += (increment < 0) ? 1 : -1;
            }
        }
    }
}
