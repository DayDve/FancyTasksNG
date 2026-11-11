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
import org.kde.plasma.extras as PlasmaExtras

MouseArea {
    id: rootMouseArea
    required property var modelIndex
    required property var winId
    required property var rootTask
    required property var tasksModel

    property bool globalHovered: false

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

    Timer {
        id: dragActivationTimer
        interval: 750
        repeat: false
        onTriggered: {
            rootMouseArea.tasksModel.requestActivate(rootMouseArea.modelIndex);
        }
    }

    DropArea {
        anchors.fill: parent
        
        onEntered: {
            dragActivationTimer.restart();
            if (rootMouseArea.toolTipDelegate) {
                rootMouseArea.toolTipDelegate.innerDragCount += 1;
            }
        }
        onPositionChanged: {
            if (!dragActivationTimer.running) {
                dragActivationTimer.restart();
            }
        }
        onExited: {
            dragActivationTimer.stop();
            if (rootMouseArea.toolTipDelegate) {
                rootMouseArea.toolTipDelegate.innerDragCount = Math.max(0, rootMouseArea.toolTipDelegate.innerDragCount - 1);
            }
        }
        onDropped: (drop) => {
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
