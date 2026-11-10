/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: controlsRoot

    required property var mediaController

    readonly property int smallSpacing: Kirigami.Units.smallSpacing
    readonly property int gridUnit: Kirigami.Units.gridUnit

    spacing: controlsRoot.smallSpacing
    
    // Strict width constraint for text mode to prevent stretching tooltips
    Layout.maximumWidth: mediaController && mediaController.toolTipDelegate ? mediaController.toolTipDelegate.tooltipInstanceMaximumWidth : controlsRoot.gridUnit * 14
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

    MediaVolumeRow {
        visible: controlsRoot.mediaController ? controlsRoot.mediaController.showVolumeControls : false
        Layout.fillWidth: true
        mediaController: controlsRoot.mediaController
    }
}
