/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

// A key name drawn as a keyboard key, for options about modifier keys.
Item {
    id: keyCap

    property alias text: label.text

    implicitWidth: label.implicitWidth + Kirigami.Units.smallSpacing * 3
    implicitHeight: label.implicitHeight + Kirigami.Units.smallSpacing

    // The key's side: a slightly thicker bottom edge.
    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
    }
    Rectangle {
        anchors {
            fill: parent
            leftMargin: 1
            rightMargin: 1
            topMargin: 1
            bottomMargin: 2
        }
        radius: Kirigami.Units.cornerRadius - 1
        color: Kirigami.Theme.alternateBackgroundColor
    }
    Label {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -0.5
        font: Kirigami.Theme.smallFont
    }
}
