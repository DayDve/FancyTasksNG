/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2024 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import QtQuick.Effects
import "code/singletones"

Rectangle {
    id: badgeRect

    property alias text: label.text
    property alias textColor: label.color
    property string appId: ""
    property int number: appId !== "" ? ((BadgeManager.countVersion >= 0) ? BadgeManager.getUnreadCount(appId) : 0) : 0
    property bool isRound: true
    property real fontPointSize: 8 // Reduced for better fit in small circles
    property string iconSource: ""
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
    property bool isCrossed: false
    property bool showNumber: true

    readonly property string defaultNotificationIcon: "notifications-symbolic"

    // Visual state coloring - Bound to theme palette
    property color highlightColor: Kirigami.Theme.highlightColor
    property color themeTextColor: showBackground ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
    property color themeBgColor: Kirigami.Theme.backgroundColor
    
    // Configurable color for the text-based icon, defaulting to theme logic
    property color textIconColor: isUrgent ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor

    // Height should be set from outside, width is adaptive
    width: {
        const padding = Math.round(Kirigami.Units.gridUnit * 0.4);
        const contentWidth = badgeRect.textSource !== "" ? textIcon.contentWidth : (badgeRect.showNumber ? label.contentWidth : 0);
        return Math.max(height, Math.round(contentWidth + (badgeRect.showNumber || badgeRect.textSource !== "" ? padding : 0)));
    }

    radius: height / 2
    antialiasing: true
    // Theme-aware background: uses system background color, but stays red for urgent items
    // When showNumber is false (dot mode), we use highlight color directly for better saturation
    color: showBackground ? (isUrgent ? Kirigami.Theme.negativeTextColor : (badgeRect.showNumber ? Kirigami.Theme.backgroundColor : Kirigami.Theme.highlightColor)) : "transparent"

    // Bright border using highlight color, but subtle when not urgent
    border.color: showBackground ? ((isUrgent || !badgeRect.showNumber) ? "transparent" : Kirigami.Theme.highlightColor) : "transparent"
    border.width: 1 // Keep it thin and elegant
    opacity: isUrgent ? 1 : 0.85
    
    visible: (number > 0) || (iconSource !== "") || (textSource !== "")

    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

    // Icon Layer: Using Kirigami.Icon
    Kirigami.Icon {
        id: icon
        anchors.centerIn: parent
        // Scale up the icon if there is no background to keep it visible
        width: Math.round(parent.height * (badgeRect.showBackground ? 0.65 : 0.85))
        height: width
        
        source: badgeRect.iconSource
        visible: (badgeRect.iconSource !== "") && (badgeRect.number <= 0) && (badgeRect.textSource === "")
        opacity: badgeRect.shadowEnabled ? 0 : 1 // Keep visible for MultiEffect source, but hide from view
        
        smooth: true // Enable smooth for best quality
        roundToIconSize: false

        // Adaptive icon color: white on red background, theme-aware otherwise
        color: badgeRect.isUrgent ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        
        // Visual feedback for interaction and mirroring support
        scale: (badgeRect.mirrorText ? -1 : 1) * (badgeRect.hovered ? 1.2 : 1.0)
        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
    }

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
        color: Kirigami.Theme.negativeTextColor
        
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

    // Diagonal cross line for "muted" or "disabled" states
    Rectangle {
        id: crossLine
        // Anchor to textIcon to stay synchronized with the font-based symbol
        anchors.centerIn: textIcon
        width: Math.round(parent.height * 1.05)
        height: Math.max(2, Math.round(parent.height * 0.15)) // Even thicker
        color: Kirigami.Theme.negativeTextColor
        rotation: 45 
        visible: badgeRect.isCrossed
        antialiasing: true
        z: 10 // Ensure it's above the text
        
        // Stronger shadow/border for the line to make it pop
        layer.enabled: badgeRect.shadowEnabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1.0
            shadowColor: "black"
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
        }
    }

    // Shadow effect for the icon when requested (e.g. for visibility on light backgrounds)
    MultiEffect {
        anchors.fill: icon
        source: icon
        visible: (badgeRect.iconSource !== "") && (badgeRect.number <= 0) && (badgeRect.textSource === "") && badgeRect.shadowEnabled
        shadowEnabled: true
        shadowBlur: 1.0
        shadowHorizontalOffset: 1
        shadowVerticalOffset: 1.5 
        shadowColor: "black" // Solid black for maximum contrast
        
        scale: icon.scale
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
        color: badgeRect.isUrgent ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
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
