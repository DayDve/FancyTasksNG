/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: containerWrapper

    property var cfg_page: null

    readonly property int gridUnit: (cfg_page && cfg_page.gridUnit !== undefined) ? cfg_page.gridUnit : Kirigami.Units.gridUnit
    readonly property int shortDuration: (cfg_page && cfg_page.shortDuration !== undefined) ? cfg_page.shortDuration : Kirigami.Units.shortDuration

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true

    default property alias innerContent: scrollView.contentData

    property int scrollDir: 0
    property real _lastY: 0

    Component.onCompleted: {
        let flick = scrollView.contentItem as Flickable
        if (flick) {
            _lastY = flick.contentY
        }
    }

    Connections {
        target: scrollView.contentItem as Flickable
        ignoreUnknownSignals: true
        function onContentYChanged() {
            let flick = scrollView.contentItem as Flickable
            if (!flick) return
            let dy = flick.contentY - containerWrapper._lastY
            if (Math.abs(dy) > 0.5) {
                containerWrapper.scrollDir = dy > 0 ? 1 : -1
                scrollDirTimer.restart()
            }
            containerWrapper._lastY = flick.contentY
        }
    }

    Timer {
        id: scrollDirTimer
        interval: 150
        onTriggered: containerWrapper.scrollDir = 0
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    }

    // Top edge shadow (visor style)
    Canvas {
        z: 99
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: scrollView.ScrollBar.vertical.width > 0 ? scrollView.ScrollBar.vertical.width : 0

        property real activeFactor: containerWrapper.scrollDir === -1 ? 1.0 : 0.0
        Behavior on activeFactor { NumberAnimation { duration: containerWrapper.shortDuration } }

        height: containerWrapper.gridUnit * 0.75 + (containerWrapper.gridUnit * 0.25 * activeFactor)
        opacity: scrollView.ScrollBar.vertical.position > 0.01 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: containerWrapper.shortDuration } }

        onPaint: {
            let ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            ctx.save();
            ctx.translate(width / 2, 0);
            ctx.scale((width / 2) / height, 1);

            let gradient = ctx.createRadialGradient(0, 0, 0, 0, 0, height);
            let alpha = 0.12 + (0.10 * activeFactor);
            gradient.addColorStop(0, "rgba(0, 0, 0, " + alpha.toFixed(3) + ")");
            gradient.addColorStop(1, "rgba(0, 0, 0, 0)");

            ctx.fillStyle = gradient;
            ctx.fillRect(-height, 0, height * 2, height);
            ctx.restore();
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onActiveFactorChanged: requestPaint()
    }

    // Bottom edge shadow (visor style)
    Canvas {
        z: 99
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: scrollView.ScrollBar.vertical.width > 0 ? scrollView.ScrollBar.vertical.width : 0

        property real activeFactor: containerWrapper.scrollDir === 1 ? 1.0 : 0.0
        Behavior on activeFactor { NumberAnimation { duration: containerWrapper.shortDuration } }

        height: containerWrapper.gridUnit * 0.75 + (containerWrapper.gridUnit * 0.25 * activeFactor)
        opacity: scrollView.ScrollBar.vertical.position < (1.0 - scrollView.ScrollBar.vertical.size) - 0.01 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: containerWrapper.shortDuration } }

        onPaint: {
            let ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            ctx.save();
            ctx.translate(width / 2, height);
            ctx.scale((width / 2) / height, 1);

            let gradient = ctx.createRadialGradient(0, 0, 0, 0, 0, height);
            let alpha = 0.12 + (0.10 * activeFactor);
            gradient.addColorStop(0, "rgba(0, 0, 0, " + alpha.toFixed(3) + ")");
            gradient.addColorStop(1, "rgba(0, 0, 0, 0)");

            ctx.fillStyle = gradient;
            ctx.fillRect(-height, -height, height * 2, height);
            ctx.restore();
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onActiveFactorChanged: requestPaint()
    }
}
