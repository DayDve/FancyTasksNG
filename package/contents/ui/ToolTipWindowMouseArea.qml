/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.taskmanager as TaskManager

MouseArea {
    required property var modelIndex
    required property var winId
    required property var rootTask
    required property var tasksModel

    property bool globalHovered: false

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    hoverEnabled: true
    enabled: winId !== undefined

    onClicked: (mouse) => {
        // Fix: Find the correct index for the specific window ID
        // The original modelIndex passed might be incorrect for grouped tasks in some context
        let targetIndex = modelIndex;
        
        if (rootTask.childCount > 0 && winId !== undefined) {
             targetIndex = findMatchingTaskIndex();
        }

        switch (mouse.button) {
        case Qt.LeftButton:
            tasksModel.requestActivate(targetIndex);
            rootTask.closeTooltip();
            if (rootTask.tasksRoot) {
                rootTask.tasksRoot.cancelHighlightWindows();
            }
            break;
        case Qt.MiddleButton:
            if (rootTask.tasksRoot) {
                rootTask.tasksRoot.cancelHighlightWindows();
            }
            tasksModel.requestClose(targetIndex);
            break;
        case Qt.RightButton:
            if (rootTask.tasksRoot) {
                rootTask.tasksRoot.createContextMenu(rootTask, targetIndex).show();
            }
            break;
        }
    }

    function findMatchingTaskIndex() {
        // Function to find the child task index that owns this winId
        if (!tasksModel || rootTask.childCount === 0) return modelIndex;

        // Iterate through children
        // We assume rootTask.index is the row of the group parent
        const parentRow = rootTask.index;
        
        for (let i = 0; i < rootTask.childCount; ++i) {
            // Create index for child i
            // Assuming makeModelIndex(parentRow, childRow) convention used in ToolTipDelegate
            const idx = tasksModel.makeModelIndex(parentRow, i);
            
            // Get WinIdList for this child
            const winIds = tasksModel.data(idx, TaskManager.AbstractTasksModel.WinIdList);
            
            if (winIds && winIds.includes(winId)) {
                return idx;
            }
        }
        
        return modelIndex;
    }

    function updateHoverState() {
        if (rootTask.tasksRoot) {
            const isHovered = containsMouse || globalHovered;
            rootTask.tasksRoot.windowsHovered([winId], isHovered);
        }
    }

    onContainsMouseChanged: updateHoverState()
    onGlobalHoveredChanged: updateHoverState()
}
