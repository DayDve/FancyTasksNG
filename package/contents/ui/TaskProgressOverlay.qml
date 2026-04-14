/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

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

            states: [
                State {
                    name: "top"
                    when: control.pStyle === 3
                    AnchorChanges { target: progressStrip; anchors.top: parent.top; anchors.left: parent.left; anchors.bottom: undefined; anchors.right: undefined }
                    PropertyChanges { target: progressStrip; width: parent.width * control.pPosition; height: control.pThick }
                },
                State {
                    name: "bottom"
                    when: control.pStyle === 4
                    AnchorChanges { target: progressStrip; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.top: undefined; anchors.right: undefined }
                    PropertyChanges { target: progressStrip; width: parent.width * control.pPosition; height: control.pThick }
                },
                State {
                    name: "left"
                    when: control.pStyle === 5
                    AnchorChanges { target: progressStrip; anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.right: undefined; anchors.top: undefined }
                    PropertyChanges { target: progressStrip; height: parent.height * control.pPosition; width: control.pThick }
                },
                State {
                    name: "right"
                    when: control.pStyle === 6
                    AnchorChanges { target: progressStrip; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.left: undefined; anchors.top: undefined }
                    PropertyChanges { target: progressStrip; height: parent.height * control.pPosition; width: control.pThick }
                }
            ]
        }
    }
}
