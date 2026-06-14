/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

RowLayout {
    id: playerControllerRoot
    required property var playerData
    required property bool isWin
    property bool showText: true

    enabled: playerData.canControl

    readonly property bool isPlaying: playerData.playbackStatus === Mpris.PlaybackStatus.Playing

    readonly property int smallSpacing: Kirigami.Units.smallSpacing
    readonly property int gridUnit: Kirigami.Units.gridUnit
    readonly property int iconSmall: Kirigami.Units.iconSizes.small
    readonly property int iconSmallMedium: Kirigami.Units.iconSizes.smallMedium
    readonly property font smallFont: Kirigami.Theme.smallFont

    ColumnLayout {
        visible: playerControllerRoot.showText
        Layout.fillWidth: playerControllerRoot.showText
        Layout.topMargin: playerControllerRoot.smallSpacing
        Layout.bottomMargin: playerControllerRoot.smallSpacing
        Layout.rightMargin: playerControllerRoot.isWin ? playerControllerRoot.smallSpacing : playerControllerRoot.gridUnit
        spacing: 0

        ScrollableTextWrapper {
            id: songTextWrapper

            Layout.fillWidth: true
            Layout.preferredHeight: songText.height
            implicitWidth: songText.implicitWidth

            textItem: PlasmaComponents3.Label {
                id: songText
                maximumLineCount: artistText.visible ? 1 : 2
                wrapMode: Text.NoWrap
                elide: parent.state ? Text.ElideNone : Text.ElideRight
                text: playerControllerRoot.playerData.track
                textFormat: Text.PlainText
            }
        }

        ScrollableTextWrapper {
            id: artistTextWrapper

            Layout.fillWidth: true
            Layout.preferredHeight: artistText.height
            implicitWidth: artistText.implicitWidth
            visible: artistText.text.length > 0

            textItem: PlasmaExtras.DescriptiveLabel {
                id: artistText
                wrapMode: Text.NoWrap
                elide: parent.state ? Text.ElideNone : Text.ElideRight
                text: playerControllerRoot.playerData.artist
                font: playerControllerRoot.smallFont
                textFormat: Text.PlainText
            }
        }
    }

    PlasmaComponents3.ToolButton {
        implicitWidth: playerControllerRoot.showText ? playerControllerRoot.gridUnit * 1.6 : playerControllerRoot.gridUnit * 1.2
        implicitHeight: playerControllerRoot.showText ? playerControllerRoot.gridUnit * 1.6 : playerControllerRoot.gridUnit * 1.2
        padding: playerControllerRoot.showText ? playerControllerRoot.smallSpacing : 0
        icon.width: playerControllerRoot.showText ? playerControllerRoot.iconSmallMedium : playerControllerRoot.iconSmall
        icon.height: playerControllerRoot.showText ? playerControllerRoot.iconSmallMedium : playerControllerRoot.iconSmall

        enabled: playerControllerRoot.playerData.canGoPrevious
        icon.name: mirrored ? "media-skip-forward" : "media-skip-backward"
        onClicked: playerControllerRoot.playerData.Previous()
    }

    PlasmaComponents3.ToolButton {
        implicitWidth: playerControllerRoot.showText ? playerControllerRoot.gridUnit * 1.6 : playerControllerRoot.gridUnit * 1.2
        implicitHeight: playerControllerRoot.showText ? playerControllerRoot.gridUnit * 1.6 : playerControllerRoot.gridUnit * 1.2
        padding: playerControllerRoot.showText ? playerControllerRoot.smallSpacing : 0
        icon.width: playerControllerRoot.showText ? playerControllerRoot.iconSmallMedium : playerControllerRoot.iconSmall
        icon.height: playerControllerRoot.showText ? playerControllerRoot.iconSmallMedium : playerControllerRoot.iconSmall

        enabled: playerControllerRoot.isPlaying ? playerControllerRoot.playerData.canPause : playerControllerRoot.playerData.canPlay
        icon.name: playerControllerRoot.isPlaying ? "media-playback-pause" : "media-playback-start"
        onClicked: {
            if (!playerControllerRoot.isPlaying) {
                playerControllerRoot.playerData.Play();
            } else {
                playerControllerRoot.playerData.Pause();
            }
        }
    }

    PlasmaComponents3.ToolButton {
        implicitWidth: playerControllerRoot.showText ? playerControllerRoot.gridUnit * 1.6 : playerControllerRoot.gridUnit * 1.2
        implicitHeight: playerControllerRoot.showText ? playerControllerRoot.gridUnit * 1.6 : playerControllerRoot.gridUnit * 1.2
        padding: playerControllerRoot.showText ? playerControllerRoot.smallSpacing : 0
        icon.width: playerControllerRoot.showText ? playerControllerRoot.iconSmallMedium : playerControllerRoot.iconSmall
        icon.height: playerControllerRoot.showText ? playerControllerRoot.iconSmallMedium : playerControllerRoot.iconSmall

        enabled: playerControllerRoot.playerData.canGoNext
        icon.name: mirrored ? "media-skip-backward" : "media-skip-forward"
        onClicked: playerControllerRoot.playerData.Next()
    }
}
