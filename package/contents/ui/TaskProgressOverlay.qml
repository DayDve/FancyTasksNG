/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2023 Marco Martin <notmart@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import org.kde.ksvg as KSvg
import "code/tools.js" as TaskTools

Item {
    id: control
    anchors.fill: parent

    // Public API: set these from the parent
    property int pStyle: 0
    property color pColor: "#00FF00"
    property real pOpacity: 1.0
    property int pThick: 2
    property real pPosition: 0.0
    property int panelLocation: 0

    Item {
        id: contentItem
        anchors.fill: parent
        opacity: control.pOpacity

        // Styles 1 & 2: Shape/Background Fill (SVG based)
        Item {
            id: fillClip
            visible: control.pStyle === 1 || control.pStyle === 2
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: control.pStyle === 1 ? parent.width * control.pPosition : parent.width
            height: control.pStyle === 2 ? parent.height * control.pPosition : parent.height
            clip: true

            KSvg.FrameSvgItem {
                width: control.width
                height: control.height
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                imagePath: "widgets/tasks"
                prefix: TaskTools.taskPrefix("progress", control.panelLocation)
                enabledBorders: KSvg.FrameSvg.NoBorder
                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: control.pColor
                }
            }
        }

        // Styles 3-6: Edge Strips
        Rectangle {
            id: progressStrip
            visible: control.pStyle >= 3 && control.pStyle <= 6
            color: control.pColor

            x: control.pStyle === 6 ? parent.width - width : 0
            y: control.pStyle === 3 ? 0 : parent.height - height
            width: (control.pStyle === 3 || control.pStyle === 4) ? parent.width * control.pPosition : control.pThick
            height: (control.pStyle === 5 || control.pStyle === 6) ? parent.height * control.pPosition : control.pThick
        }
    }
}
