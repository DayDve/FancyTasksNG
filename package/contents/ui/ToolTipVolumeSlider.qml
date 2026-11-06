/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

// The tooltips' thin horizontal volume slider; the theme's own slider is
// built for full-size panels and its handle dwarfs a tooltip row.
PlasmaComponents3.Slider {
    id: slider

    topPadding: 4
    bottomPadding: 4

    // The tooltip handles the wheel itself; the slider's own would step twice.
    WheelHandler {
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            event.accepted = true;
        }
    }

    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + (slider.availableHeight - height) / 2

        width: handleHover.hovered || slider.pressed ? 10 : 6
        height: width
        radius: width / 2

        color: slider.pressed ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        border.color: Kirigami.Theme.backgroundColor
        border.width: 1

        HoverHandler { id: handleHover }

        Behavior on width {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: slider.availableWidth
        height: 2
        radius: 1
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)

        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            color: Kirigami.Theme.highlightColor
            radius: 1
        }
    }
}
