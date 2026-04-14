/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.plasmoid

KSvg.SvgItem {
    id: arrow

    required property var taskModel
    required property Item iconBox
    property int locationOverride: -1

    readonly property int effLocation: (locationOverride >= 0 && locationOverride <= 3) ? locationOverride :
        (tasks.effectiveLocation === PlasmaCore.Types.TopEdge ? 3 :
         tasks.effectiveLocation === PlasmaCore.Types.LeftEdge ? 1 :
         tasks.effectiveLocation === PlasmaCore.Types.RightEdge ? 2 : 0)

    visible: taskModel.IsGroupParent

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
                anchors.horizontalCenter: iconBox.horizontalCenter
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
                anchors.verticalCenter: iconBox.verticalCenter
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
                anchors.verticalCenter: iconBox.verticalCenter
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
                anchors.horizontalCenter: iconBox.horizontalCenter
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
