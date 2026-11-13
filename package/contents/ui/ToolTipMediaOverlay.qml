/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: overlayRoot

    required property var mediaController
    required property bool hoveredState

    readonly property int smallSpacing: Kirigami.Units.smallSpacing
    readonly property int longDuration: Kirigami.Units.longDuration

    width: parent.width
    height: controlsColumn.implicitHeight + (overlayRoot.smallSpacing * 2)

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        radius: overlayRoot.smallSpacing

        opacity: overlayRoot.hoveredState ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: overlayRoot.longDuration
            }
        }
    }

    ColumnLayout {
        id: controlsColumn
        anchors.centerIn: parent
        width: parent.width - (overlayRoot.smallSpacing * 2)
        spacing: overlayRoot.smallSpacing

        opacity: overlayRoot.hoveredState ? 1.0 : 0.4
        Behavior on opacity {
            NumberAnimation {
                duration: overlayRoot.longDuration
            }
        }

        // MPRIS Player Controls (with track name and scrolling)
        PlayerController {
            visible: overlayRoot.mediaController ? overlayRoot.mediaController.showPlayerControls : false
            Layout.fillWidth: true
            showText: true // Show track details in the visual overlay as it fits nicely on thumbnails
            playerData: overlayRoot.mediaController ? overlayRoot.mediaController.playerData : null
            mediaRegistry: overlayRoot.mediaController ? overlayRoot.mediaController.mediaRegistry : null
            isWin: overlayRoot.mediaController && overlayRoot.mediaController.toolTipDelegate ? overlayRoot.mediaController.toolTipDelegate.isWin : false
        }

        MediaVolumeRow {
            visible: overlayRoot.mediaController ? overlayRoot.mediaController.showVolumeControls : false
            Layout.fillWidth: true
            mediaController: overlayRoot.mediaController
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 99999
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            if (overlayRoot.mediaController && overlayRoot.mediaController.showVolumeControls) {
                overlayRoot.mediaController.wheelVolume(wheel.angleDelta.y);
                wheel.accepted = true;
            }
        }
    }
}
