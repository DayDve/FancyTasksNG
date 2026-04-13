/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

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
    property int ignoredPid: -1
    property string ignoredId: ""
    property string ignoredLauncherUrl: ""
    property var hoveredItem
    property bool isGroupDialog: false
    property bool isMoving: false

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
        if (target.animating || dropArea.isMoving) {
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
        if (above.model) {
            const dragSource = dropArea.tasks.dragSource;
            if (dragSource && dragSource.model) {
                // EXPLICIT GUARD: Do not allow mixing launchers and normal tasks if grouped
                const sourceIsLauncher = !!(dragSource.model.IsLauncher || dragSource.model.IsStartup);
                const aboveIsLauncher = !!(above.model.IsLauncher || above.model.IsStartup);
                
                if (sourceIsLauncher !== aboveIsLauncher) {
                    return;
                }
            }

            const aboveIsLauncher = !!(above.model.IsLauncher || above.model.IsStartup);
            if (aboveIsLauncher) {
                if (above.model.LauncherUrlWithoutIcon && above.model.LauncherUrlWithoutIcon === dropArea.ignoredLauncherUrl) {
                    return;
                }
            } else if (above.model.AppPid !== -1 && above.model.AppPid === dropArea.ignoredPid) {
                if (above.model.AppId === dropArea.ignoredId) {
                    return;
                }
            }
        }

        if (dropArea.tasksModel.sortMode === TaskManager.TasksModel.SortManual && dropArea.tasks.dragSource) {
            // Reject drags between different TaskList instances.
            if (dropArea.tasks.dragSource.parent !== above.parent) {
                return;
            }

            const fromRow = dropArea.tasks.dragSource.modelRow();
            const toRow = above.modelRow();

            if (fromRow !== toRow && fromRow !== -1 && toRow !== -1) {
                dropArea.isMoving = true;
                const tasksModel = dropArea.tasks.tasksModel;
                const groupDialog = dropArea.tasks.groupDialog;
                
                Qt.callLater(() => {
                    // CONTEXT GUARD: Ensure objects still exist when the deferred call runs
                    if (!tasksModel || tasksModel.count === undefined) return;
                    
                    if (groupDialog && groupDialog.visualParent) {
                        tasksModel.move(fromRow, toRow,
                            tasksModel.makeModelIndex(groupDialog.visualParent.modelRow()));
                    } else {
                        tasksModel.move(fromRow, toRow);
                    }
                });

                dropArea.ignoredPid = (above.model && above.model.AppPid !== undefined) ? above.model.AppPid : -1;
                dropArea.ignoredId = (above.model && above.model.AppId !== undefined) ? above.model.AppId : "";
                dropArea.ignoredLauncherUrl = (above.model && above.model.LauncherUrlWithoutIcon !== undefined) ? above.model.LauncherUrlWithoutIcon : "";
                ignoreItemTimer.restart();
                moveTimer.restart();
            }
        } else if (!dropArea.tasks.dragSource && hoveredItem !== above) {
            if (hoveredItem && hoveredItem !== above && hoveredItem.toolTipOpen) {
                let oldHovered = hoveredItem;
                hideTooltipTimer.itemToHide = oldHovered;
                hideTooltipTimer.restart();
            }
            hoveredItem = above;
            activationTimer.restart();
        }
    }

    onExited: {
        if (hoveredItem && hoveredItem.toolTipOpen) {
            hideTooltipTimer.itemToHide = hoveredItem;
            hideTooltipTimer.restart();
        }
        hoveredItem = null;
        activationTimer.stop();
    }

    Timer {
        id: hideTooltipTimer
        interval: 500
        repeat: false
        property var itemToHide: null
        onTriggered: {
            if (itemToHide && itemToHide.toolTipOpen && !dropArea.tasks.isTooltipHovered) {
                itemToHide.toolTipOpen = false;
                if (itemToHide.tasksRoot.toolTipAreaItem === itemToHide) {
                    itemToHide.tasksRoot.toolTipAreaItem = null;
                }
            }
        }
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
                dropArea.ignoredPid = -1;
                dropArea.ignoredId = "";
                dropArea.ignoredLauncherUrl = "";
                ignoreItemTimer.stop();
            }
        }
    }

    Timer {
        id: ignoreItemTimer
        repeat: false
        interval: 750
        onTriggered: {
            dropArea.ignoredPid = -1;
            dropArea.ignoredId = "";
            dropArea.ignoredLauncherUrl = "";
        }
    }

    Timer {
        id: moveTimer
        repeat: false
        interval: 150
        onTriggered: dropArea.isMoving = false
    }

    Timer {
        id: activationTimer

        interval: 250
        repeat: false

        onTriggered: {
            if (parent.hoveredItem.model.IsGroupParent) {
                parent.hoveredItem.tasksRoot.currentHoveredTask = parent.hoveredItem;
                parent.hoveredItem.toolTipOpen = true;
                parent.hoveredItem.tasksRoot.toolTipAreaItem = parent.hoveredItem;
            } else if (!parent.hoveredItem.model.IsLauncher) {
                dropArea.tasks.tasksModel.requestActivate(parent.hoveredItem.modelIndex());
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
