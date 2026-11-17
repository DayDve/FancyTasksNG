/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A group of options on a panel: centered, no wider than maxWidth (narrower
// with the window), its rows at the left edge.
Rectangle {
    id: panel

    default property alias content: column.data
    property alias spacing: column.spacing
    // Off: no background and no padding, just the width and centering.
    property bool framed: true
    readonly property real padding: framed ? Kirigami.Units.largeSpacing * 2 : 0
    readonly property real maxWidth: Kirigami.Units.gridUnit * 40

    Layout.fillWidth: true
    Layout.maximumWidth: maxWidth
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: column.implicitWidth + padding * 2
    implicitHeight: column.implicitHeight + padding * 2

    radius: Kirigami.Units.cornerRadius
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false
    color: framed ? Kirigami.Theme.backgroundColor : "transparent"
    border.width: framed ? 1 : 0
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)

    ColumnLayout {
        id: column
        x: panel.padding
        y: panel.padding
        width: panel.width - panel.padding * 2
        // Taller when the panel is stretched (side by side with a taller
        // one), so an item can be pushed to the bottom.
        height: Math.max(implicitHeight, panel.height - panel.padding * 2)
    }
}
