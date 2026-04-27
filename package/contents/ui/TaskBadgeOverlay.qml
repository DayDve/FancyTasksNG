/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: root
    property var parentTask: null // Set by Loader in Task.qml
    
    // This overlay now fills the contentWrapper which fills the whole button.
    // It inherits the jump animation and zoom from contentWrapper.
    anchors.fill: parent

    // Use gridUnit as base for consistent physical size across different screens
    readonly property real badgeHeight: Math.min(Math.round(Kirigami.Units.gridUnit * 0.85), Math.round(Math.min(parent.width, parent.height) * 0.5))
    
    // Simple shared margin
    readonly property real badgeTopMargin: root.divingMargin
    
    readonly property bool compactMode: root.badgeHeight < 14
    
    // Common diving offset when task is highlighted
    readonly property real divingMargin: (root.parentTask && root.parentTask.tasksRoot.iconsOnly && root.parentTask.highlighted) 
        ? Math.round(badgeHeight / 5) 
        : 0
 
    // Audio Indicator (Top-Left)
    Badge {
        id: audioBadge
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: root.badgeTopMargin
        
        // Horizontal shift when task is highlighted
        anchors.leftMargin: 0
        
        Behavior on anchors.topMargin {
            enabled: root.parentTask && root.parentTask.tasksRoot.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.leftMargin {
            enabled: root.parentTask && root.parentTask.tasksRoot.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        
        height: root.badgeHeight
        visible: root.parentTask ? (root.parentTask.playingAudio || root.parentTask.muted) : false
        
        textSource: "🕪"
        mirrorText: true
        overlaySource: root.parentTask?.muted ? "⦸" : ""
        opacity: root.parentTask?.muted ? 0.7 : 1.0
        hovered: !!audioMouseArea.containsMouse
        
        textIconColor: Kirigami.Theme.textColor
        showBackground: false
        shadowEnabled: true 
        isRound: true
        fontFactor: 0.7
        isBold: false
 
        MouseArea {
            id: audioMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            
            onContainsMouseChanged: {
                if (root.parentTask) {
                    root.parentTask.isAudioHovered = audioMouseArea.containsMouse;
                }
            }
            
            onExited: {
                if (root.parentTask) {
                    root.parentTask.isAudioHovered = false;
                }
            }
 
            onClicked: (mouse) => {
                mouse.accepted = true;
                if (root.parentTask) {
                    root.parentTask.toggleMuted();
                }
            }
        }
    }
 
    // Notification Badge (Top-Right)
    Badge {
        id: notificationBadge
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.badgeTopMargin

        // Horizontal shift when task is highlighted
        anchors.rightMargin: 0
 
        Behavior on anchors.topMargin {
            enabled: root.parentTask && root.parentTask.tasksRoot.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.rightMargin {
            enabled: root.parentTask && root.parentTask.tasksRoot.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
 
        height: root.compactMode ? Math.round(root.badgeHeight * 0.5) : root.badgeHeight
        visible: !!root.parentTask?.badgeVisible
        appId: root.parentTask?.model?.AppId || ""
        
        isUrgent: (Plasmoid.configuration.badgeHighlightNew && !!root.parentTask?.hasUnseenNotifications) || !!root.parentTask?.model?.DemandsAttention
        isRound: true
        isBold: false
        fontFactor: 0.7
        showNumber: !root.compactMode
    }
}
