/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2023-2024 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2024 Māris Nartišs <maris.kde@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasmoid

import "code/tools.js" as TaskTools

DropArea {
    id: dropArea
    signal urlsDropped(var urls)

    property var target
    property var hoveredItem
    property bool isGroupDialog: false

    property alias handleWheelEvents: wheelHandler.handleWheelEvents

    required property var tasks
    required property var tasksModel
    required property var proxyModel

    //ignore anything that is neither internal to TaskManager or a URL list
    onEntered: event => {
        if (event.formats.indexOf("text/x-plasmoidservicename") >= 0) {
            event.accepted = false;
        }
        target.animating = false;
    }

    onPositionChanged: event => {
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

        if (above.model && Plasmoid.configuration.sortingStrategy === 1) {
            const dragSource = dropArea.tasks.dragSource;
            if (dragSource && dragSource.model) {
                const tasks = dropArea.tasks;
                const dropIndicator = tasks.dropIndicator;
                
                // Map event to targetItem's coordinates to decide left/right side
                const pos = above.mapFromItem(dropArea, event.x, event.y);
                
                // Map items to indicator's parent coordinates
                const indicatorPos = tasks.mapFromItem(above, 0, 0);
                
                let dropIndex;
                if (tasks.vertical) {
                    if (pos.y < above.height / 2) {
                        dropIndex = above.index;
                        dropIndicator.x = indicatorPos.x;
                        dropIndicator.y = indicatorPos.y;
                    } else {
                        dropIndex = above.index + 1;
                        dropIndicator.x = indicatorPos.x;
                        dropIndicator.y = indicatorPos.y + above.height;
                    }
                } else {
                    if (pos.x < above.width / 2) {
                        dropIndex = above.index;
                        dropIndicator.x = indicatorPos.x;
                        dropIndicator.y = indicatorPos.y;
                    } else {
                        dropIndex = above.index + 1;
                        dropIndicator.x = indicatorPos.x + above.width;
                        dropIndicator.y = indicatorPos.y;
                    }
                }
                
                tasks.dropIndex = dropIndex;
                dropIndicator.visible = true;
                return; // Don't process normal hover when dragging
            }
        }

        if (!dropArea.tasks.dragSource && hoveredItem !== above) {
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
        dropArea.tasks.dropIndicator.visible = false;
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
        // Handle internal task reordering
        if (event.formats.indexOf("application/x-orgkdeplasmataskmanager_taskbuttonitem") >= 0) {
            const dragSource = dropArea.tasks.dragSource;
            if (dragSource && dropArea.tasks.dropIndex !== -1) {
                let targetProxyIndex = dropArea.tasks.dropIndex;

                // If moving forward, adjust the target index to account for the gap left by the moved item.
                // This ensures that "dropping between items" lands the item in the expected spot.
                if (targetProxyIndex > dragSource.index) {
                    targetProxyIndex--;
                }

                // Safety clamp
                targetProxyIndex = Math.max(0, Math.min(targetProxyIndex, dropArea.proxyModel.count - 1));

                // Get the source indices from the proxy model
                const fromIdx = dropArea.proxyModel.mapToSource(dropArea.proxyModel.index(dragSource.index, 0));
                const toIdx = dropArea.proxyModel.mapToSource(dropArea.proxyModel.index(targetProxyIndex, 0));

                if (fromIdx.row !== -1 && toIdx.row !== -1 && fromIdx.row !== toIdx.row) {
                    dropArea.tasksModel.move(fromIdx.row, toIdx.row);
                }
            }
            dropArea.tasks.dropIndicator.visible = false;
            event.accepted = true;
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
                dropArea.tasks.dropIndicator.visible = false;
            }
        }
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

    property real _rotationAccumulator: 0
    WheelHandler {
        id: wheelHandler

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        property bool handleWheelEvents: true

        enabled: handleWheelEvents && (Plasmoid.configuration.wheelAction !== 0 || (Plasmoid.configuration.wheelCtrlActionEnabled && Plasmoid.configuration.wheelCtrlAction !== 0))

        onWheel: event => {
            dropArea._rotationAccumulator += (event.angleDelta.y / 8.0);
            let increment = 0;
            while (dropArea._rotationAccumulator >= 15) {
                dropArea._rotationAccumulator -= 15;
                increment++;
            }
            while (dropArea._rotationAccumulator <= -15) {
                dropArea._rotationAccumulator += 15;
                increment--;
            }

            if (increment === 0) return;

            const anchor = dropArea.target.childAt(event.x, event.y);
            const isCtrl = (event.modifiers & Qt.ControlModifier) && Plasmoid.configuration.wheelCtrlActionEnabled;
            const action = isCtrl ? Plasmoid.configuration.wheelCtrlAction : Plasmoid.configuration.wheelAction;

            if (action >= 1 && action <= 4) { // Cycle Tasks
                const skipMinimized = (action === 2 || action === 4);
                const groupOnly = (action === 3 || action === 4);
                while (increment !== 0) {
                    TaskTools.activateNextPrevTask(anchor, increment < 0, skipMinimized, dropArea.tasks, groupOnly);
                    increment += (increment < 0) ? 1 : -1;
                }
            } else if (action === 5) { // Adjust Volume
                const isShift = (event.modifiers & Qt.ShiftModifier) && Plasmoid.configuration.wheelShiftSystemVolumeEnabled;
                if (anchor && anchor.adjustVolume) {
                    anchor.adjustVolume(increment, isShift);
                } else if (isShift && dropArea.tasks.adjustGlobalVolume) {
                    dropArea.tasks.adjustGlobalVolume(increment);
                }
            }
        }
    }
}
