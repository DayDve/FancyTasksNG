/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Speaker drawn on a 16-unit grid. Theme speaker icons are drawn with
// margins and thin waves that blur at badge sizes, and font glyphs depend
// on which font has them; this fills the whole square at any size.
Item {
    id: glyph

    property bool muted: false
    property color color: Kirigami.Theme.textColor

    Shape {
        width: 16
        height: 16
        scale: glyph.width / 16
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: glyph.color
            strokeColor: glyph.color
            strokeWidth: 0.6
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M0.8 5.6 H3.6 L8 1.6 V14.4 L3.6 10.4 H0.8 Z" }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: glyph.color
            strokeWidth: 1.6
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M10.1 5.6 A3.2 3.2 0 0 1 10.1 10.4 M12.2 3.4 A6.2 6.2 0 0 1 12.2 12.6" }
        }

        // "No" sign over the speaker; always there, transparent when not muted.
        ShapePath {
            fillColor: "transparent"
            strokeColor: glyph.muted ? Kirigami.Theme.negativeTextColor : "transparent"
            strokeWidth: 2
            capStyle: ShapePath.FlatCap
            PathSvg { path: "M8 1 A7 7 0 1 1 7.99 1 Z M3.05 3.05 L12.95 12.95" }

            Behavior on strokeColor {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
    }
}
