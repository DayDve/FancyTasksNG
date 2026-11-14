/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A size in pixels: a spin box with "px" after it.
RowLayout {
    id: pxSpinBox
    property alias from: spinBox.from
    property alias to: spinBox.to
    property alias value: spinBox.value
    // The user changed the value (not a binding update).
    signal valueModified()

    spacing: Kirigami.Units.smallSpacing

    SpinBox {
        id: spinBox
        onValueModified: pxSpinBox.valueModified()
    }
    Label {
        text: "px"
    }
}
