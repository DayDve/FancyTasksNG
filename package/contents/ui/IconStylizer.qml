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
    // 1: Outline, 2: Lines, 3: Monochrome.
    property int style: 2
    // Outline: how weak an edge still gets a line, 0..1.
    property real sensitivity: 0.5
    // Lines: the line thickness, the blur's sigma in output pixels.
    property real thickness: 0.5
    // Monochrome: the contrast, 1 for none.
    property real contrast: 1.2
    // Colorization: 0 the theme's text color, 1 the accent, 2 customColor,
    // 3 the icon's dominant color, 4 its average color.
    property int colorization: 0
    property color customColor: "white"
    // Icon Shape under Task Styling: corners rounded to `cornerRadius` (a
    // fraction of the side), with a backing behind when it's shown.
    property bool clipToShape: false
    property real cornerRadius: 0
    property bool backingVisible: false
    property color backingColor: "transparent"
    property real backingOpacity: 1

    // The hover highlight: 0 none, 1 the icon's original colors, 2 the
    // accent, 3 hoverCustomColor, 4 the icon's dominant color, 5 its average.
    property int hoverHighlight: 1
    property color hoverCustomColor: "white"
    // The cursor, in lightSpace's coordinates, while pointerInside.
    property Item lightSpace: null
    property point pointerPosition
    property bool pointerInside: false

    readonly property int supersampling: 2

    // The highlight reaches about one icon from the cursor. An icon it
    // doesn't reach keeps its uniforms, and isn't drawn again.
    readonly property real lightRadius: Math.min(width, height) * 0.9
    readonly property point light: lightSpace ? mapFromItem(lightSpace, pointerPosition) : Qt.point(0, 0)
    readonly property bool lit: hoverHighlight > 0 && pointerInside && lightSpace !== null
        && light.x > -lightRadius && light.x < width + lightRadius
        && light.y > -lightRadius && light.y < height + lightRadius
    // In the shaders' pixels: the canvas, twice the size, with its margin.
    readonly property point lightInCanvas: lit
        ? Qt.point((light.x + margin) * supersampling, (light.y + margin) * supersampling) : Qt.point(-100000, -100000)
    readonly property real lightRadiusInCanvas: lit ? lightRadius * supersampling : 0

    // A mostly dark icon has a light drawing (a terminal's prompt): its
    // brightness is turned over before the lines are found.
    Kirigami.ImageColors {
        id: colors
        source: stylizer.source
        Component.onCompleted: update()
        onSourceChanged: update()
    }
    function luminance(c: color): real {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }
    readonly property bool darkIcon: colors.average ? luminance(colors.average) < 0.35 : false
    readonly property bool darkPanel: luminance(Kirigami.Theme.backgroundColor) < 0.5

    // The icon's own color, made to stand out on the panel: as bright as
    // it gets on a dark one, darkened on a light one, its hue and saturation
    // kept. A greyish color (Breeze's greys are slightly blue: brightened,
    // they'd turn into a pale blue), or none at all (the icon couldn't be
    // read: ImageColors then gives the panel's background), is the theme's
    // text color.
    readonly property bool colorsRead: colors.palette.length > 0
    function onPanel(c: color): color {
        if (!colorsRead || c.hsvSaturation < 0.25)
            return Kirigami.Theme.textColor;
        return Qt.hsva(c.hsvHue, c.hsvSaturation, darkPanel ? 1 : 0.55, 1);
    }
    // Animated: the active task's drawing turns to its own color and back.
    property color color: colorFor(colorization)
    Behavior on color {
        ColorAnimation { duration: Kirigami.Units.longDuration }
    }
    function colorFor(colorization: int): color {
        switch (colorization) {
        case 1: return Kirigami.Theme.highlightColor;
        case 2: return customColor;
        case 3: return onPanel(colors.dominant);
        case 4: return onPanel(colors.average);
        default: return Kirigami.Theme.textColor;
        }
    }
    readonly property color hoverColor: {
        switch (hoverHighlight) {
        case 2: return Kirigami.Theme.highlightColor;
        case 3: return hoverCustomColor;
        case 4: return onPanel(colors.dominant);
        case 5: return onPanel(colors.average);
        default: return Kirigami.Theme.highlightColor;
        }
    }
    // Monochrome runs from the icon's dark tones to its light ones: on a dark
    // panel from a dim shade of the color up to the color itself, on a light
    // one from the color up to a pale shade of it, so it never melts into
    // the panel.
    readonly property color monochromeDark: darkPanel ? Qt.rgba(color.r * 0.25, color.g * 0.25, color.b * 0.25, 1) : color
    readonly property color monochromeLight: darkPanel ? color : Qt.tint(color, Qt.rgba(1, 1, 1, 0.8))
    // Monochrome: the icon's own darkest and lightest tones, stretched to
    // the whole range (kept apart, so a one-color icon isn't blown up).
    readonly property real levelLow: colors.closestToBlack ? Math.min(0.45, luminance(colors.closestToBlack)) : 0
    readonly property real levelHigh: colors.closestToWhite ? Math.max(0.55, luminance(colors.closestToWhite)) : 1

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
            readonly property color hoverColor: stylizer.hoverColor
            readonly property size itemSize: Qt.size(width, height)
            readonly property point mouse: stylizer.lightInCanvas
            readonly property real radius: stylizer.lightRadiusInCanvas
            readonly property real useSource: stylizer.hoverHighlight === 1 ? 1 : 0
            readonly property size pixel: Qt.size(1 / width, 1 / height)
            readonly property real ownMax: stylizer.darkPanel ? 1 : 0.55
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
            readonly property color hoverColor: stylizer.hoverColor
            readonly property size itemSize: Qt.size(width, height)
            readonly property point mouse: stylizer.lightInCanvas
            readonly property real radius: stylizer.lightRadiusInCanvas
            readonly property real useSource: stylizer.hoverHighlight === 1 ? 1 : 0
            readonly property size pixel: Qt.size(1 / width, 1 / height)
            readonly property real ownMax: stylizer.darkPanel ? 1 : 0.55
            fragmentShader: Qt.resolvedUrl("shaders/lines.frag.qsb")
        }
        ShaderEffect {
            visible: stylizer.style === 3
            anchors.fill: parent
            readonly property var source: iconTexture
            readonly property real lo: stylizer.levelLow
            readonly property real hi: stylizer.levelHigh
            readonly property real contrast: stylizer.contrast
            readonly property color darkColor: stylizer.monochromeDark
            readonly property color lightColor: stylizer.monochromeLight
            readonly property color hoverColor: stylizer.hoverColor
            readonly property size itemSize: Qt.size(width, height)
            readonly property point mouse: stylizer.lightInCanvas
            readonly property real radius: stylizer.lightRadiusInCanvas
            readonly property real useSource: stylizer.hoverHighlight === 1 ? 1 : 0
            fragmentShader: Qt.resolvedUrl("shaders/monochrome.frag.qsb")
        }
    }
}
