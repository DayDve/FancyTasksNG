/*
    SPDX-FileCopyrightText: 2018 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "code/singletones"

Rectangle {
    id: badgeRect

    property alias text: label.text
    property alias textColor: label.color
    property int number: 0
    property bool isRound: true
    property real fontPointSize: 1024
    property string iconSource: ""
    property bool hovered: false

    // Allow overriding the main highlight color (e.g. for muted state)
    property color highlightColor: Kirigami.Theme.highlightColor

    implicitHeight: Kirigami.Units.gridUnit
    implicitWidth: {
        if (iconSource !== "") {
            return height > 0 ? height : implicitHeight; 
        }
        const padding = Math.round(Kirigami.Units.smallSpacing * 1.5);
        const textWidth = Math.round(label.contentWidth + padding);
        return isRound ? Math.max(height > 0 ? height : implicitHeight, textWidth) : textWidth;
    }

    width: isRound ? Math.max(height, implicitWidth) : implicitWidth
    radius: isRound ? height / 2 : Kirigami.Units.smallSpacing / 2
    color: Kirigami.Theme.backgroundColor

    // Background Layer: The colored semi-transparent surface
    Rectangle {
        id: coloredBackground
        anchors.fill: parent
        radius: parent.radius
        
        // Use the custom highlightColor property
        color: badgeRect.hovered ? Qt.alpha(badgeRect.highlightColor, 0.8) : Qt.alpha(badgeRect.highlightColor, 0.3)
        border.color: badgeRect.hovered ? badgeRect.highlightColor : Qt.alpha(badgeRect.highlightColor, 0.6)
        border.width: badgeRect.hovered ? 2 : 1

        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        Behavior on border.width { NumberAnimation { duration: Kirigami.Units.shortDuration } }
    }

    // Plasma Glow Effect
    PlasmaExtras.Highlight {
        anchors.fill: parent
        visible: badgeRect.hovered
        enabled: visible
    }

    // Icon (for audio indicator)
    Kirigami.Icon {
        id: icon
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.65)
        height: width
        source: badgeRect.iconSource
        visible: badgeRect.iconSource !== ""
        
        // Make the icon follow the text color or be high-contrast
        color: Kirigami.Theme.textColor
    }

    // Number (for original badges)
    PlasmaComponents.Label {
        id: label
        anchors.centerIn: parent
        width: implicitWidth
        height: Math.min(Kirigami.Units.gridUnit * 2, Math.round(parent.height))
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.VerticalFit
        font.pointSize: badgeRect.fontPointSize
        minimumPointSize: 4
        visible: badgeRect.iconSource === ""
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
