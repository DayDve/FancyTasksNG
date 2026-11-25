/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

// A task icon in one style for the whole panel ("Stylization" under Task
// Styling): drawn here in place of the icon itself (TaskIconBox hides it).
// The filter runs on a copy of the icon at twice the size, for smooth thin
// lines, and its result is a layer: it's worked out once and drawn again as
// it is, also while the icon zooms or bounces; only a new icon, size or
// setting runs it again.
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

    Item {
        width: stylizer.width * stylizer.supersampling
        height: stylizer.height * stylizer.supersampling
        scale: 1 / stylizer.supersampling
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true

        Kirigami.Icon {
            id: icon
            anchors.fill: parent
            roundToIconSize: false
            source: stylizer.source
        }
        ShaderEffectSource {
            id: iconTexture
            sourceItem: icon
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
