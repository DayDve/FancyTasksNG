/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import "code/singletones"

RowLayout {
    id: controlsRoot

    required property var mediaController

    spacing: Kirigami.Units.smallSpacing
    
    // Strict width constraint for text mode to prevent stretching tooltips
    Layout.maximumWidth: mediaController && mediaController.toolTipDelegate ? mediaController.toolTipDelegate.tooltipInstanceMaximumWidth : Kirigami.Units.gridUnit * 14
    Layout.fillWidth: true

    // MPRIS Player Controls (Compact: no text, just buttons)
    PlayerController {
        visible: controlsRoot.mediaController ? controlsRoot.mediaController.showPlayerControls : false
        showText: false // Keep text mode ultra-compact by hiding duplicate/long track details
        playerData: controlsRoot.mediaController && controlsRoot.mediaController.playerData ? controlsRoot.mediaController.playerData : ({
            canControl: false,
            playbackStatus: 0,
            track: "",
            artist: "",
            canGoPrevious: false,
            canPlay: false,
            canPause: false,
            canGoNext: false
        })
        isWin: controlsRoot.mediaController && controlsRoot.mediaController.toolTipDelegate ? controlsRoot.mediaController.toolTipDelegate.isWin : false
    }

    // Volume Controls (Inline inside the same row)
    RowLayout {
        visible: controlsRoot.mediaController ? controlsRoot.mediaController.showVolumeControls : false
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.ToolButton {
            implicitWidth: Kirigami.Units.gridUnit * 1.2
            implicitHeight: Kirigami.Units.gridUnit * 1.2
            padding: 0
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
          
            icon.name: if (checked) {
                "audio-volume-muted";
            } else if (Math.round(sliderInline.value / sliderInline.to * 100) <= 25) {
                "audio-volume-low";
            } else if (Math.round(sliderInline.value / sliderInline.to * 100) <= 75) {
                "audio-volume-medium";
            } else {
                "audio-volume-high";
            }
            
            text: Wrappers.i18n("Mute")
            display: PlasmaComponents3.AbstractButton.IconOnly
            checkable: true
            checked: controlsRoot.mediaController ? controlsRoot.mediaController.muted : false
            onClicked: {
                if (controlsRoot.mediaController) {
                    controlsRoot.mediaController.toggleMuted();
                }
            }
        }

        PlasmaComponents3.Slider {
            id: sliderInline
            Layout.fillWidth: true
            
            from: controlsRoot.mediaController && controlsRoot.mediaController.audioStreamManager ? controlsRoot.mediaController.audioStreamManager.item.minimalVolume : 0
            to: controlsRoot.mediaController && controlsRoot.mediaController.audioStreamManager ? controlsRoot.mediaController.audioStreamManager.item.normalVolume : 65536
            
            // Block built-in QML Slider wheel handling completely to prevent duplicate scroll bugs!
            WheelHandler {
                acceptedButtons: Qt.NoButton
                onWheel: (event) => {
                    event.accepted = true;
                }
            }

            Binding {
                target: sliderInline
                property: "value"
                value: controlsRoot.mediaController ? controlsRoot.mediaController.appVolume : 0
                when: !sliderInline.pressed
            }
            
            onMoved: {
                if (controlsRoot.mediaController) {
                    controlsRoot.mediaController.setVolume(value);
                }
            }
        }
        
        PlasmaComponents3.Label {
            text: Math.round(sliderInline.value / sliderInline.to * 100) + "%"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 1.5
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
