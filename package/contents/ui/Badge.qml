/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "code/singletones"

/**
 * Badge: Premium multi-layered indicator.
 * Restored to the visually superior version from earlier commits.
 */
Rectangle {
    id: badgeRect

    property alias text: label.text
    property int number: 0
    property bool isRound: true
    property real fontPointSize: 1024 // Large base for VerticalFit
    property string iconSource: ""
    property bool hovered: false
    property bool isUrgent: false
    property bool isBold: false
    property bool showBackground: true
    property real fontFactor: 1.0

    // Allow overriding colors
    property color highlightColor: isUrgent ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor

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
    antialiasing: true

    // Base background for contrast
    color: showBackground ? Kirigami.Theme.backgroundColor : "transparent"

    // Background Layer: The colored semi-transparent surface
    Rectangle {
        id: coloredBackground
        anchors.fill: parent
        radius: parent.radius
        visible: badgeRect.showBackground
        
        // Classic FancyTasksNG alpha logic
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

    // Icon Layer (for audio)
    Kirigami.Icon {
        id: icon
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.65)
        height: width
        source: badgeRect.iconSource
        visible: badgeRect.iconSource !== ""
        color: Kirigami.Theme.textColor
    }

    // Text Layer (the number)
    PlasmaComponents.Label {
        id: label
        anchors.centerIn: parent
        width: implicitWidth
        height: Math.min(Kirigami.Units.gridUnit * 2, Math.round(parent.height))
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.VerticalFit
        font.pointSize: badgeRect.fontPointSize * badgeRect.fontFactor
        font.bold: badgeRect.isBold
        minimumPointSize: 4
        visible: badgeRect.iconSource === ""
        
        text: {
            if (badgeRect.number < 0) {
                return Wrappers.i18nc("Invalid", "—");
            }
            if (badgeRect.number > 999) {
                return "…";
            }
            return badgeRect.number.toLocaleString(Qt.locale(), 'f', 0);
        }
    }
}
