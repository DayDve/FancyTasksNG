/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2024 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

// Notification count: a circle that widens into a pill for longer numbers,
// or a plain dot when showNumber is off. Height is set from outside.
Rectangle {
    id: badgeRect

    property int number: 0
    property bool isUrgent: false
    property bool showNumber: true
    // Above this the count is shortened ("1.2k"); 0 shows it in full.
    property int maxNumber: 999

    // 0 = Theme background, 1 = Fixed red, 2 = System accent, 3 = Custom color
    property int colorMode: 0
    property color customColor: "transparent"
    readonly property bool highlightMode: colorMode !== 0 || isUrgent

    width: showNumber ? Math.max(height, Math.round(label.contentWidth + height * 0.5)) : height
    radius: height / 2
    antialiasing: true
    visible: number > 0

    color: {
        if (isUrgent || colorMode === 1) return Kirigami.Theme.negativeTextColor;
        if (colorMode === 2) return Kirigami.Theme.highlightColor;
        if (colorMode === 3) return badgeRect.customColor;
        return showNumber ? Kirigami.Theme.backgroundColor : Kirigami.Theme.highlightColor;
    }
    // A thin highlight ring only on the theme-colored badge, to set it off the icon.
    border.color: (colorMode === 0 && !isUrgent && showNumber) ? Kirigami.Theme.highlightColor : "transparent"
    border.width: 1
    opacity: highlightMode ? 1.0 : 0.85

    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

    // Text centers its line box, ascent and descent included, so digits sit
    // high; center the drawn glyphs instead.
    FontMetrics {
        id: fontMetrics
        font: label.font
    }
    TextMetrics {
        id: textMetrics
        font: label.font
        text: label.text
    }

    Text {
        id: label
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: textMetrics.advanceWidth / 2
                                        - (textMetrics.tightBoundingRect.x + textMetrics.tightBoundingRect.width / 2)
        anchors.verticalCenterOffset: label.contentHeight / 2
                                      - (fontMetrics.ascent + textMetrics.tightBoundingRect.y + textMetrics.tightBoundingRect.height / 2)
        visible: badgeRect.showNumber
        font.pixelSize: Math.max(1, Math.round(parent.height * 0.7))
        renderType: Text.QtRendering
        color: badgeRect.highlightMode ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        text: {
            const n = badgeRect.number;
            if (badgeRect.maxNumber > 0 && n > badgeRect.maxNumber && n >= 1000) {
                // Floor, not round: 9999 must not read "10k".
                return n < 10000 ? (Math.floor(n / 100) / 10).toLocaleString(Qt.locale(), 'f', n % 1000 < 100 ? 0 : 1) + "k"
                                 : Math.floor(n / 1000) + "k";
            }
            return n.toLocaleString(Qt.locale(), 'f', 0);
        }
    }
}
