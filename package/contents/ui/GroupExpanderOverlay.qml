/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2023 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg

KSvg.SvgItem {
    id: arrow

    required property var taskModel
    required property Item iconBox
    property var tasksRoot
    property int locationOverride: -1

    readonly property int effLocation: (locationOverride >= 0 && locationOverride <= 3) ? locationOverride :
        (!tasksRoot ? 0 :
         tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge ? 3 :
         tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge ? 1 :
         tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge ? 2 : 0)

    visible: arrow.taskModel.IsGroupParent

    states: [
        State {
            name: "bottom"
            when: arrow.effLocation === 0
            AnchorChanges {
                target: arrow
                anchors.top: undefined
                anchors.left: undefined
                anchors.right: undefined
                anchors.bottom: arrow.parent.bottom
                anchors.horizontalCenter: arrow.parent.horizontalCenter
                anchors.verticalCenter: undefined
            }
        },
        State {
            name: "left"
            when: arrow.effLocation === 1
            AnchorChanges {
                target: arrow
                anchors.top: undefined
                anchors.left: arrow.parent.left
                anchors.right: undefined
                anchors.bottom: undefined
                anchors.horizontalCenter: undefined
                anchors.verticalCenter: arrow.parent.verticalCenter
            }
        },
        State {
            name: "right"
            when: arrow.effLocation === 2
            AnchorChanges {
                target: arrow
                anchors.top: undefined
                anchors.left: undefined
                anchors.right: arrow.parent.right
                anchors.bottom: undefined
                anchors.horizontalCenter: undefined
                anchors.verticalCenter: arrow.parent.verticalCenter
            }
        },
        State {
            name: "top"
            when: arrow.effLocation === 3
            AnchorChanges {
                target: arrow
                anchors.top: arrow.parent.top
                anchors.left: undefined
                anchors.right: undefined
                anchors.bottom: undefined
                anchors.horizontalCenter: arrow.parent.horizontalCenter
                anchors.verticalCenter: undefined
            }
        }
    ]

    implicitWidth: Math.min(naturalSize.width, iconBox.width)
    implicitHeight: Math.min(naturalSize.height, iconBox.width)

    imagePath: "widgets/tasks"
    elementId: elementForLocation()

    function elementForLocation(): string {
        switch (arrow.effLocation) {
        case 1: // Left
            return "group-expander-left";
        case 3: // Top
            return "group-expander-top";
        case 2: // Right
            return "group-expander-right";
        case 0: // Bottom
        default:
            return "group-expander-bottom";
        }
    }
}
