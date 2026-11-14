/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../ui/code/singletones"

// The icon size in the unit chosen under Task Layout › Buttons: a percentage
// (iconScale) or pixels (iconSizePx). One row for both units, so the form
// doesn't shift when they change.
RowLayout {
    id: control

    required property ConfigPage page
    // The slider's width; it fills the row when not set.
    property real sliderWidth: -1
    property bool showReset: false

    readonly property bool absolute: page.cfg_iconSizeOverride

    function setSize(size: int): void {
        if (absolute)
            page.cfg_iconSizePx = size;
        else
            page.cfg_iconScale = size;
    }

    spacing: Kirigami.Units.smallSpacing

    // No stepSize: with it the style draws a tick per step.
    Slider {
        id: iconSize
        Layout.fillWidth: control.sliderWidth < 0
        Layout.preferredWidth: control.sliderWidth
        from: control.absolute ? 8 : 10
        to: control.absolute ? 100 : 300
        value: control.absolute ? control.page.cfg_iconSizePx : control.page.cfg_iconScale
        onMoved: control.setSize(Math.round(value))
    }
    SpinBox {
        from: iconSize.from
        to: iconSize.to
        editable: true
        value: Math.round(iconSize.value)
        onValueModified: control.setSize(value)
    }
    Label {
        // Both units take the same room.
        Layout.minimumWidth: unitMetrics.advanceWidth
        text: control.absolute ? "px" : "%"
        TextMetrics {
            id: unitMetrics
            text: "px"
        }
    }
    Button {
        visible: control.showReset
        icon.name: "edit-reset"
        flat: true
        onClicked: control.setSize(control.absolute ? control.page.cfg_iconSizePxDefault : control.page.cfg_iconScaleDefault)
        ToolTip.text: Wrappers.i18n("Reset to default")
        ToolTip.visible: hovered
        ToolTip.delay: 1000
    }
}
