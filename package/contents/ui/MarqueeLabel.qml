/*
    SPDX-FileCopyrightText: 2024 Jules
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    property alias text: label.text
    property alias font: label.font
    property alias color: label.color
    property alias lineHeight: label.lineHeight
    property alias maximumLineCount: label.maximumLineCount // Should be 1 usually

    // Pass through common text properties
    implicitHeight: label.implicitHeight

    // We default to strictly the label width, but this component is intended to be constrained
    implicitWidth: label.implicitWidth

    clip: true

    PlasmaComponents3.Label {
        id: label

        // Ensure no elision or wrapping for marquee
        elide: Text.ElideNone
        wrapMode: Text.NoWrap
        maximumLineCount: 1

        anchors.verticalCenter: parent.verticalCenter

        // Reset position when not scrolling
        x: 0
    }

    SequentialAnimation {
        id: scrollAnim
        // Run only if content overflows and component is visible
        running: label.implicitWidth > root.width && root.visible && root.width > 0
        loops: Animation.Infinite

        PauseAnimation { duration: 2000 }

        NumberAnimation {
            target: label
            property: "x"
            // Scroll until the right edge of text touches right edge of container
            to: root.width - label.implicitWidth
            // Speed: 20ms per pixel seems reasonable
            duration: Math.max(1000, (label.implicitWidth - root.width) * 20)
            easing.type: Easing.InOutQuad
        }

        PauseAnimation { duration: 2000 }

        NumberAnimation {
            target: label
            property: "x"
            to: 0
            duration: Math.max(1000, (label.implicitWidth - root.width) * 20)
            easing.type: Easing.InOutQuad
        }
    }

    // Reset position when animation stops
    onWidthChanged: {
        if (!scrollAnim.running) label.x = 0;
    }
    Connections {
        target: label
        function onImplicitWidthChanged() {
             if (!scrollAnim.running) label.x = 0;
        }
    }
}
