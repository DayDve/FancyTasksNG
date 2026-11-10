/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import "code/singletones"

// A tooltip's app volume row: mute button, slider and percentage, with the
// wheel anywhere over it stepping the volume.
Item {
    id: volumeRow

    required property var mediaController

    readonly property var mediaRegistry: mediaController ? mediaController.mediaRegistry : null

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: rowLayout.implicitHeight

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.ToolButton {
            implicitWidth: Kirigami.Units.gridUnit * 1.2
            implicitHeight: Kirigami.Units.gridUnit * 1.2
            padding: 0
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small

            icon.name: {
                if (checked)
                    return "audio-volume-muted";
                const percent = Math.round(slider.value / slider.to * 100);
                if (percent <= 25)
                    return "audio-volume-low";
                if (percent <= 75)
                    return "audio-volume-medium";
                return "audio-volume-high";
            }

            text: Wrappers.i18n("Mute")
            display: PlasmaComponents3.AbstractButton.IconOnly
            checkable: true
            checked: volumeRow.mediaController ? volumeRow.mediaController.muted : false
            onClicked: {
                if (volumeRow.mediaController)
                    volumeRow.mediaController.toggleMuted();
            }
        }

        ToolTipVolumeSlider {
            id: slider
            Layout.fillWidth: true

            from: volumeRow.mediaRegistry ? volumeRow.mediaRegistry.minimalVolume : 0
            to: volumeRow.mediaRegistry ? volumeRow.mediaRegistry.normalVolume : 65536

            // Moving the slider replaces a plain value binding; this one
            // keeps following the streams whenever the slider isn't held.
            Binding on value {
                value: volumeRow.mediaController ? volumeRow.mediaController.appVolume : 0
                when: !slider.pressed
            }

            onMoved: {
                if (volumeRow.mediaController)
                    volumeRow.mediaController.setVolume(value);
            }
        }

        PlasmaComponents3.Label {
            text: Math.round(slider.value / slider.to * 100) + "%"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 1.5
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            if (volumeRow.mediaController) {
                volumeRow.mediaController.wheelVolume(wheel.angleDelta.y);
                wheel.accepted = true;
            }
        }
    }
}
