/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2024 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "code/singletones"

Rectangle {
    id: badgeRect

    property alias text: label.text
    property alias textColor: label.color
    property string appId: ""
    property int number: appId !== "" ? ((BadgeManager.countVersion >= 0) ? BadgeManager.getUnreadCount(appId) : 0) : 0
    property bool isRound: true
    property real fontPointSize: 8 // Reduced for better fit in small circles
    property bool hovered: false
    property bool isUrgent: false
    property bool showBackground: true
    property bool isBold: false
    property real fontFactor: 0.75
    property int maxNumber: 999
    property string textSource: ""
    property string overlaySource: ""
    property bool shadowEnabled: false
    property bool mirrorText: false
    property bool showNumber: true



    // Cached theme colors to optimize lookups in child bindings
    readonly property color _highlightColor: Kirigami.Theme.highlightColor
    readonly property color _highlightedTextColor: Kirigami.Theme.highlightedTextColor
    readonly property color _textColor: Kirigami.Theme.textColor
    readonly property color _backgroundColor: Kirigami.Theme.backgroundColor
    readonly property color _negativeTextColor: Kirigami.Theme.negativeTextColor

    // Configurable color mode: 0 = Theme background, 1 = Fixed red, 2 = System accent, 3 = Custom color
    readonly property int badgeColorMode: (Plasmoid.configuration && Plasmoid.configuration.badgeColorMode !== undefined) ? Plasmoid.configuration.badgeColorMode : 0
    readonly property color badgeCustomColor: (Plasmoid.configuration && Plasmoid.configuration.badgeCustomColor) ? Plasmoid.configuration.badgeCustomColor : "#ff3b30"

    // Configurable color for the text-based icon, defaulting to theme logic
    property color textIconColor: (badgeColorMode === 1 || badgeColorMode === 2 || badgeColorMode === 3 || isUrgent) ? badgeRect._highlightedTextColor : badgeRect._textColor

    // Height should be set from outside, width is adaptive
    width: {
        const padding = Math.round(Kirigami.Units.gridUnit * 0.4);
        const contentWidth = badgeRect.textSource !== "" ? textIcon.contentWidth : (badgeRect.showNumber ? label.contentWidth : 0);
        return Math.max(height, Math.round(contentWidth + (badgeRect.showNumber || badgeRect.textSource !== "" ? padding : 0)));
    }

    radius: height / 2
    antialiasing: true
    // Mode 0: Theme background, red for urgent, highlightColor for dot mode
    // Mode 1: Fixed red (negativeTextColor)
    // Mode 2: System accent color (highlightColor)
    // Mode 3: Custom color
    color: {
        if (!showBackground) return "transparent";
        if (isUrgent) return badgeRect._negativeTextColor;
        if (badgeColorMode === 1) return badgeRect._negativeTextColor;
        if (badgeColorMode === 2) return badgeRect._highlightColor;
        if (badgeColorMode === 3) return badgeRect.badgeCustomColor;
        return badgeRect.showNumber ? badgeRect._backgroundColor : badgeRect._highlightColor;
    }

    // Bright border using highlight color, subtle when not urgent in Theme mode, transparent in Fixed modes
    border.color: {
        if (!showBackground || badgeColorMode === 1 || badgeColorMode === 2 || badgeColorMode === 3) return "transparent";
        return (isUrgent || !badgeRect.showNumber) ? "transparent" : badgeRect._highlightColor;
    }
    border.width: 1 // Keep it thin and elegant
    opacity: (badgeColorMode === 1 || badgeColorMode === 2 || badgeColorMode === 3 || isUrgent) ? 1.0 : 0.85
    
    visible: (number > 0) || (textSource !== "")

    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }


    // Shadow Layer for the textIcon (reliable "double-text" shadow)
    Text {
        id: shadowIcon
        // Positioned slightly offset from the main icon
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: textIcon.anchors.horizontalCenterOffset + 1
        anchors.verticalCenterOffset: 1
        
        text: badgeRect.textSource
        visible: badgeRect.textSource !== "" && badgeRect.shadowEnabled
        
        font.pixelSize: textIcon.font.pixelSize
        color: "black"
        opacity: 0.6
        
        renderType: Text.QtRendering
        antialiasing: true
        
        scale: textIcon.scale
        transformOrigin: textIcon.transformOrigin
        
        horizontalAlignment: textIcon.horizontalAlignment
        verticalAlignment: textIcon.verticalAlignment
    }

    // Overlay Icon Layer (e.g. for "⦸" symbol on top of audio)
    Text {
        id: overlayIcon
        anchors.centerIn: textIcon
        text: badgeRect.overlaySource
        visible: badgeRect.overlaySource !== ""
        
        font.pixelSize: Math.round(parent.height * 1.1) // Slightly larger than parent but not overwhelming
        font.bold: true
        color: badgeRect._negativeTextColor
        
        // Scale with the base icon
        scale: badgeRect.hovered ? 1.2 : 1.0
        transformOrigin: Item.Center
        
        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
        
        // Reset offsets to zero for perfect mathematical centering
        anchors.verticalCenterOffset: 0
        anchors.horizontalCenterOffset: 0
        
        renderType: Text.QtRendering
        antialiasing: true
        z: 20
        
        // Shadow for overlay
        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 1
            anchors.verticalCenterOffset: 1
            text: parent.text
            font: parent.font
            color: "black"
            opacity: 0.5
            z: -1
            renderType: parent.renderType
            visible: badgeRect.shadowEnabled
        }
    }

    // Text-based Icon Layer (e.g. for audio symbols)
    Text {
        id: textIcon
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 0
        // Vertical offset to compensate for font metric differences between symbols and numbers
        anchors.verticalCenterOffset: 0
        
        text: badgeRect.textSource
        visible: badgeRect.textSource !== ""
        
        font.pixelSize: Math.round(parent.height * badgeRect.fontFactor)
        color: badgeRect.textIconColor
        
        renderType: Text.QtRendering 
        antialiasing: true
        
        // Mirroring support with smooth hover scale
        scale: (badgeRect.mirrorText ? -1 : 1) * (badgeRect.hovered ? 1.2 : 1.0)
        transformOrigin: Item.Center
        
        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
        
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Text Layer
    Text {
        id: label
        anchors.centerIn: parent
        // Offset for ellipsis character to keep it visually centered
        anchors.verticalCenterOffset: text === "…" ? -Math.round(parent.height * 0.22) : 0
        
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        width: parent.width
        
        font.bold: badgeRect.isBold
        font.pixelSize: Math.round(parent.height * badgeRect.fontFactor)
        
        renderType: Text.QtRendering
        antialiasing: true
        color: (badgeRect.badgeColorMode === 1 || badgeRect.badgeColorMode === 2 || badgeRect.badgeColorMode === 3 || badgeRect.isUrgent) ? badgeRect._highlightedTextColor : badgeRect._textColor
        visible: badgeRect.number > 0 && badgeRect.showNumber
        
        text: {
            if (badgeRect.number < 0) {
                return Wrappers.i18nc("Invalid", "—");
            }
            // Show full number up to 999, then ellipsis as requested
            // Use "k" notation for numbers above maxNumber (or >= 1000) to save space
            if (badgeRect.maxNumber > 0 && badgeRect.number > badgeRect.maxNumber) {
                let val = badgeRect.number;
                if (val >= 1000) {
                    if (val < 10000) {
                        let kVal = val / 1000;
                        return kVal.toFixed(1).replace(".0", "") + "k";
                    }
                    return Math.floor(val / 1000) + "k";
                }
            }
            return badgeRect.number.toLocaleString(Qt.locale(), 'f', 0);
        }
    }
}
