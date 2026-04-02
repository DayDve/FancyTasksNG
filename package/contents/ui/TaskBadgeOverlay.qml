/*
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.graphicaleffects as KGraphicalEffects
import org.kde.plasma.plasmoid

Item {
    id: root
    property var parentTask: parent.parent

    // Fix: Anchor directly to the icon to sync scaling and position automatically
    anchors.fill: root.parentTask.taskIcon

    // Stable offset calculation
    readonly property int badgeOffset: Math.round(Math.max(Kirigami.Units.smallSpacing / 2, root.width / 32))

    Item {
        id: badgeMask
        anchors.fill: parent

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: -root.badgeOffset
            anchors.top: parent.top
            anchors.topMargin: -root.badgeOffset

            visible: root.parentTask.smartLauncherItem.countVisible
            width: badgeRect.width + root.badgeOffset * 2
            height: badgeRect.height + root.badgeOffset * 2
            radius: height / 2

            // Force update the shader mask when geometry changes
            onWidthChanged: maskShaderSource.scheduleUpdate()
            onHeightChanged: maskShaderSource.scheduleUpdate()
            onVisibleChanged: maskShaderSource.scheduleUpdate()
        }
    }

    ShaderEffectSource {
        id: iconShaderSource
        sourceItem: root.parentTask.taskIcon
        hideSource: GraphicsInfo.api !== GraphicsInfo.Software
    }

    ShaderEffectSource {
        id: maskShaderSource
        sourceItem: badgeMask
        hideSource: true
        live: false
    }

    KGraphicalEffects.BadgeEffect {
        id: shader

        anchors.fill: parent
        source: iconShaderSource
        mask: maskShaderSource

        onWidthChanged: maskShaderSource.scheduleUpdate()
        onHeightChanged: maskShaderSource.scheduleUpdate()
    }

    Badge {
        id: badgeRect

        anchors.right: parent.right
        anchors.top: parent.top

        height: Math.round(parent.height * 0.4)
        visible: root.parentTask.smartLauncherItem.countVisible
        number: root.parentTask.smartLauncherItem.count
    }
}
