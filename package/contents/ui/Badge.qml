/*
    SPDX-FileCopyrightText: 2018 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/singletones"

// This top-level item is an opaque background that goes behind the colored
// background, for contrast. It's not an Item since that it would be square,
// and not round, as required here
Rectangle {
    id: badgeRect

    property alias text: label.text
    property alias textColor: label.color
    property int number: 0
    property bool isRound: true
    property real fontPointSize: 1024

    implicitHeight: Kirigami.Units.gridUnit
    implicitWidth: {
        const textWidth = Math.round(label.contentWidth + Kirigami.Units.smallSpacing * 2);
        return isRound ? Math.max(Kirigami.Units.gridUnit, textWidth) : textWidth;
    }

    // Fix: keep it round even when scaled externally by TaskBadgeOverlay
    width: isRound ? Math.max(height, implicitWidth) : implicitWidth

    radius: isRound ? height / 2 : Kirigami.Units.smallSpacing / 2

    color: Kirigami.Theme.backgroundColor

    // Colored background
    Rectangle {
        anchors.fill: parent
        radius: height / 2

        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.3)
        border.color: Kirigami.Theme.highlightColor
        border.width: 1
    }

    // Number
    PlasmaComponents3.Label {
        id: label
        anchors.centerIn: parent
        width: height
        height: Math.min(Kirigami.Units.gridUnit * 2, Math.round(parent.height))
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.VerticalFit
        font.pointSize: badgeRect.fontPointSize
        minimumPointSize: 4
        text: {
            if (badgeRect.number < 0) {
                return Wrappers.i18nc("Invalid number of new messages, overlay, keep short", "—");
            } else if (badgeRect.number > 9999) {
                return Wrappers.i18nc("Over 9999 new messages, overlay, keep short", "9,999+");
            } else {
                return badgeRect.number.toLocaleString(Qt.locale(), 'f', 0);
            }
        }
        textFormat: Text.PlainText
    }
}
