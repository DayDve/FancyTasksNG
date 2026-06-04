/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "code/tools.js" as TaskTools

Item {
    id: control
    anchors.fill: parent

    property double volume: 0
    property bool muted: false

    function show() {
        opacity = 1;
        hideTimer.restart();
    }

    opacity: 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.longDuration }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: control.opacity = 0
    }

    Item {
        id: contentItem
        anchors.fill: parent

        // Use the same visual style as the task progress bar
        Item {
            id: fillClip
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width * control.volume
            height: parent.height
            clip: true

            KSvg.FrameSvgItem {
                width: control.width
                height: control.height
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                imagePath: "widgets/tasks"
                // Using 'progress' prefix for consistency with task progress
                prefix: TaskTools.taskPrefix("progress", Plasmoid.location)
                enabledBorders: KSvg.FrameSvg.NoBorder
                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: control.muted ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
                }
            }
        }
    }
}
