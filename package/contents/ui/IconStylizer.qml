/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

// A task icon in one style for the whole panel ("Stylization" under Task
// Styling): drawn here in place of the icon itself (TaskIconBox hides it).
// The filter runs on a copy of the icon at twice the size, for smooth thin
// lines, and its result is a layer: it's worked out once and drawn again as
// it is, also while the icon zooms or bounces; only a new icon, size or
// setting runs it again. The icon's shape (rounded corners) and backing are
// put on first, as the plain icon has them, so the style follows the shape:
// with a backing, every icon becomes the same tile.
Item {
    id: stylizer

    // The icon: an icon name, a QIcon or a file.
    property var source
    // 1: Outline, 2: Lines.
    property int style: 2
    // Outline: how weak an edge still gets a line, 0..1.
    property real sensitivity: 0.5
    // Lines: the line thickness, the blur's sigma in output pixels.
    property real thickness: 0.5
    property color color: Kirigami.Theme.textColor
    // Icon Shape under Task Styling: corners rounded to `cornerRadius` (a
    // fraction of the side), with a backing behind when it's shown.
    property bool clipToShape: false
    property real cornerRadius: 0
    property bool backingVisible: false
    property color backingColor: "transparent"
    property real backingOpacity: 1

    readonly property int supersampling: 2

    // A mostly dark icon has a light drawing (a terminal's prompt): its
    // brightness is turned over before the lines are found.
    Kirigami.ImageColors {
        id: colors
        source: stylizer.source
        Component.onCompleted: update()
        onSourceChanged: update()
    }
    readonly property bool darkIcon: colors.average
        ? (0.2126 * colors.average.r + 0.7152 * colors.average.g + 0.0722 * colors.average.b) < 0.35 : false

    // Room around the icon: a line along its very edge (a backing's border)
    // is drawn there instead of being cut off.
    readonly property int margin: 2

    Item {
        x: -stylizer.margin
        y: -stylizer.margin
        width: (stylizer.width + 2 * stylizer.margin) * stylizer.supersampling
        height: (stylizer.height + 2 * stylizer.margin) * stylizer.supersampling
        scale: 1 / stylizer.supersampling
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true

        // The icon with its shape and backing, and the room around it.
        Item {
            id: canvas
            anchors.fill: parent
            Item {
                id: shaped
                anchors.fill: parent
                anchors.margins: stylizer.margin * stylizer.supersampling
                readonly property real radius: stylizer.cornerRadius * Math.min(width, height)
                Rectangle {
                    anchors.fill: parent
                    visible: stylizer.clipToShape && stylizer.backingVisible
                    radius: shaped.radius
                    antialiasing: true
                    color: stylizer.backingColor
                    opacity: stylizer.backingOpacity
                }
                Kirigami.Icon {
                    anchors.fill: parent
                    roundToIconSize: false
                    source: stylizer.source
                    layer.enabled: stylizer.clipToShape
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: mask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                }
            }
        }
        // Kept visible, out of sight: a hidden item renders no layer, and
        // the mask would be empty (as iconMask in TaskIconBox).
        Rectangle {
            id: mask
            x: -9999
            y: -9999
            width: shaped.width
            height: shaped.height
            radius: shaped.radius
            color: "black"
            antialiasing: true
            layer.enabled: true
            layer.smooth: true
        }
        ShaderEffectSource {
            id: iconTexture
            sourceItem: canvas
            hideSource: true
            visible: false
        }
        ShaderEffect {
            visible: stylizer.style === 1
            anchors.fill: parent
            readonly property var source: iconTexture
            // Lines a pixel thick at the icon's size.
            readonly property size texel: Qt.size(stylizer.supersampling / width, stylizer.supersampling / height)
            readonly property real threshold: 0.35 - 0.25 * stylizer.sensitivity
            readonly property color lineColor: stylizer.color
            fragmentShader: Qt.resolvedUrl("shaders/outline.frag.qsb")
        }
        ShaderEffect {
            visible: stylizer.style === 2
            anchors.fill: parent
            readonly property var source: iconTexture
            readonly property size texel: Qt.size(1 / width, 1 / height)
            readonly property real sigma: stylizer.thickness * stylizer.supersampling
            readonly property real invert: stylizer.darkIcon ? 1 : 0
            readonly property color lineColor: stylizer.color
            fragmentShader: Qt.resolvedUrl("shaders/lines.frag.qsb")
        }
    }
}
