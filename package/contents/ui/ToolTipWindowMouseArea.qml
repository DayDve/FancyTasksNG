/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

MouseArea {
    required property var modelIndex
    required property var winId
    required property var rootTask // Используем var вместо Task, чтобы избежать циклических зависимостей

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    hoverEnabled: true
    enabled: winId !== undefined

    onClicked: (mouse) => {
        switch (mouse.button) {
        case Qt.LeftButton:
            tasksModel.requestActivate(modelIndex);
            rootTask.hideImmediately();
            // Используем tasksRoot для доступа к корневому элементу
            if (rootTask.tasksRoot) {
                rootTask.tasksRoot.cancelHighlightWindows();
            }
            break;
        case Qt.MiddleButton:
            if (rootTask.tasksRoot) {
                rootTask.tasksRoot.cancelHighlightWindows();
            }
            tasksModel.requestClose(modelIndex);
            break;
        case Qt.RightButton:
            if (rootTask.tasksRoot) {
                rootTask.tasksRoot.createContextMenu(rootTask, modelIndex).show();
            }
            break;
        }
    }

    onContainsMouseChanged: {
        if (rootTask.tasksRoot) {
            rootTask.tasksRoot.windowsHovered([winId], containsMouse);
        }
    }
}
