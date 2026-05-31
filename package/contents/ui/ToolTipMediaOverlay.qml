/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: overlayRoot

    required property var mediaController
    required property bool hoveredState

    width: parent.width
    height: controlsColumn.implicitHeight + (Kirigami.Units.smallSpacing * 2)

    readonly property bool isHovered: overlayHover.hovered

    HoverHandler {
        id: overlayHover
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        radius: Kirigami.Units.smallSpacing

        opacity: overlayRoot.hoveredState ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
            }
        }
    }

    ColumnLayout {
        id: controlsColumn
        anchors.centerIn: parent
        width: parent.width - (Kirigami.Units.smallSpacing * 2)
        spacing: Kirigami.Units.smallSpacing

        opacity: overlayRoot.hoveredState ? 1.0 : 0.4
        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
            }
        }

        // MPRIS Player Controls (with track name and scrolling)
        PlayerController {
            visible: overlayRoot.mediaController ? overlayRoot.mediaController.showPlayerControls : false
            Layout.fillWidth: true
            showText: true // Show track details in the visual overlay as it fits nicely on thumbnails
            playerData: overlayRoot.mediaController && overlayRoot.mediaController.playerData ? overlayRoot.mediaController.playerData : ({
                canControl: false,
                playbackStatus: 0,
                track: "",
                artist: "",
                canGoPrevious: false,
                canPlay: false,
                canPause: false,
                canGoNext: false
            })
            isWin: overlayRoot.mediaController && overlayRoot.mediaController.toolTipDelegate ? overlayRoot.mediaController.toolTipDelegate.isWin : false
        }

        // Volume Controls
        RowLayout {
            visible: overlayRoot.mediaController ? overlayRoot.mediaController.showVolumeControls : false
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
              
                icon.name: if (checked) {
                    "audio-volume-muted";
                } else if (Math.round(slider.value / slider.to * 100) <= 25) {
                    "audio-volume-low";
                } else if (Math.round(slider.value / slider.to * 100) <= 75) {
                    "audio-volume-medium";
                } else {
                    "audio-volume-high";
                }
                
                display: PlasmaComponents3.AbstractButton.IconOnly
                checkable: true
                checked: overlayRoot.mediaController ? overlayRoot.mediaController.muted : false
                onClicked: {
                    if (overlayRoot.mediaController) {
                        overlayRoot.mediaController.toggleMuted();
                    }
                }
            }

            PlasmaComponents3.Slider {
                id: slider
                Layout.fillWidth: true
                
                from: overlayRoot.mediaController && overlayRoot.mediaController.audioStreamManager ? overlayRoot.mediaController.audioStreamManager.item.minimalVolume : 0
                to: overlayRoot.mediaController && overlayRoot.mediaController.audioStreamManager ? overlayRoot.mediaController.audioStreamManager.item.normalVolume : 65536
                
                // Block built-in QML Slider wheel handling completely to prevent duplicate scroll bugs!
                WheelHandler {
                    acceptedButtons: Qt.NoButton
                    onWheel: (event) => {
                        event.accepted = true;
                    }
                }

                Binding {
                    target: slider
                    property: "value"
                    value: overlayRoot.mediaController ? overlayRoot.mediaController.appVolume : 0
                    when: !slider.pressed
                }
                
                onMoved: {
                    if (overlayRoot.mediaController) {
                        overlayRoot.mediaController.setVolume(value);
                    }
                }
            }
            
            PlasmaComponents3.Label {
                text: Math.round(slider.value / slider.to * 100) + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 1.5
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 99999
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            if (overlayRoot.mediaController && overlayRoot.mediaController.showVolumeControls) {
                let step = Math.round(65536 * 0.05 * wheel.angleDelta.y / 120);
                if (step !== 0) {
                    overlayRoot.mediaController.adjustAppVolume(step);
                }
                wheel.accepted = true;
            }
        }
    }
}
