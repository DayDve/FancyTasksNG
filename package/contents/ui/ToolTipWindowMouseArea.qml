/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras

MouseArea {
    id: rootMouseArea
    required property var modelIndex
    required property var winId
    required property var rootTask
    required property var tasksModel

    property bool globalHovered: false
    readonly property bool dragHovered: thumbnailDrop.containsDrag

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    hoverEnabled: true
    enabled: winId !== undefined

    onClicked: (mouse) => {
        const targetIndex = modelIndex;

        switch (mouse.button) {
        case Qt.LeftButton:
            tasksModel.requestActivate(targetIndex);
            rootTask.closeTooltip();
            break;
        case Qt.MiddleButton:
            if (rootTask.tasksRoot) {
                rootTask.tasksRoot.cancelHighlightWindows();
            }
            tasksModel.requestClose(targetIndex);
            break;
        case Qt.RightButton:
            if (rootTask.tasksRoot) {
                const tasksRoot = rootTask.tasksRoot;
                const menu = tasksRoot.createContextMenu(rootTask, targetIndex);
                // The cursor leaves the tooltip for the menu; the tooltip has
                // to know the menu is open to stay up (see main.qml).
                menu.statusChanged.connect(() => {
                    if (menu.status === PlasmaExtras.Menu.Open) {
                        tasksRoot.thumbnailMenu = menu;
                        tasksRoot.thumbnailMenuTask = rootTask;
                    } else if (tasksRoot.thumbnailMenu === menu) {
                        tasksRoot.thumbnailMenu = null;
                        tasksRoot.thumbnailMenuTask = null;
                    }
                });
                menu.show();
            }
            break;
        }
    }

    property var toolTipDelegate

    function updateHoverState() {
        if (rootTask.tasksRoot) {
            const isHovered = containsMouse || globalHovered;
            
            if (isHovered) {
                rootTask.tasksRoot.windowsHovered([winId], true);
            } else if (toolTipDelegate && toolTipDelegate.containsMouse && toolTipDelegate.isGroup) {
                // Delegate handles clearing when mouse leaves the group, or next item takes over.
            } else {
                 rootTask.tasksRoot.windowsHovered([winId], false);
            }
        }
    }

    onContainsMouseChanged: updateHoverState()
    onGlobalHoveredChanged: updateHoverState()

    // A file dragged over a thumbnail highlights its window; leaving the
    // thumbnail on any side but the panel's, not onto another thumbnail,
    // activates the window, so the file can be dropped into it wherever it
    // is. Not on a dwell over the thumbnail: the thumbnail over the button
    // is crossed on the way to the others, and once a window is activated
    // the drag goes to it.
    function leftAwayFromPanel(x: real, y: real): bool {
        const edges = [y, height - y, x, width - x]; // top, bottom, left, right
        const distance = Math.min(...edges);
        // A drag cancelled or dropped mid-thumbnail isn't leaving it.
        if (distance > Kirigami.Units.gridUnit * 2) {
            return false;
        }
        const nearest = edges.indexOf(distance);
        switch (rootTask.tasksRoot?.effectiveLocation) {
        case PlasmaCore.Types.TopEdge:
            return nearest !== 0;
        case PlasmaCore.Types.LeftEdge:
            return nearest !== 2;
        case PlasmaCore.Types.RightEdge:
            return nearest !== 3;
        default:
            return nearest !== 1;
        }
    }

    DropArea {
        id: thumbnailDrop
        anchors.fill: parent

        property point lastPosition
        property bool dropped: false

        onEntered: (drag) => {
            dropped = false;
            lastPosition = Qt.point(drag.x, drag.y);
            rootMouseArea.rootTask.tasksRoot?.windowsHovered([rootMouseArea.winId], true);
            if (rootMouseArea.toolTipDelegate) {
                rootMouseArea.toolTipDelegate.innerDragCount += 1;
            }
        }
        onPositionChanged: (drag) => {
            lastPosition = Qt.point(drag.x, drag.y);
        }
        onExited: {
            const tasksRoot = rootMouseArea.rootTask.tasksRoot;
            tasksRoot?.windowsHovered([rootMouseArea.winId], false);
            if (rootMouseArea.toolTipDelegate) {
                rootMouseArea.toolTipDelegate.innerDragCount = Math.max(0, rootMouseArea.toolTipDelegate.innerDragCount - 1);
            }
            if (dropped || !rootMouseArea.leftAwayFromPanel(lastPosition.x, lastPosition.y)) {
                return;
            }
            // Not when it went on to another thumbnail or list entry (one
            // above this in a vertical list): that one's enter comes with
            // this exit.
            const delegate = rootMouseArea.toolTipDelegate;
            const index = rootMouseArea.modelIndex;
            const model = rootMouseArea.tasksModel;
            Qt.callLater(() => {
                if (!delegate || delegate.innerDragCount === 0) {
                    model.requestActivate(index);
                }
            });
        }
        onDropped: (drop) => {
            dropped = true;
            if (drop.hasUrls) {
                rootMouseArea.tasksModel.requestOpenUrls(rootMouseArea.modelIndex, drop.urls);
                drop.accept();
                
                rootMouseArea.rootTask.closeTooltip();
            } else {
                drop.accepted = false;
            }
        }
    }
}
