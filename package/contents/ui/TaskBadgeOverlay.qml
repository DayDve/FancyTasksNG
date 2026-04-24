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

    // Common height calculation to keep both badges perfectly aligned
    readonly property real badgeHeight: 14
    // Common diving offset when task is highlighted
    readonly property real divingMargin: (root.parentTask && root.parentTask.tasksRoot.iconsOnly && root.parentTask.highlighted) 
        ? Math.round(badgeHeight / 6) 
        : 0
    // Shared Y coordinate for perfect alignment
    readonly property real badgeY: root.divingMargin
 
    // Audio Indicator (Top-Left)
    Badge {
        id: audioBadge
        anchors.left: parent.left
        y: root.badgeY
        
        // Horizontal shift when task is highlighted
        anchors.leftMargin: 0
        
        Behavior on y {
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
        y: root.badgeY
 
        // Horizontal shift when task is highlighted
        anchors.rightMargin: 0
 
        Behavior on y {
            enabled: root.parentTask && root.parentTask.tasksRoot.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.rightMargin {
            enabled: root.parentTask && root.parentTask.tasksRoot.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
 
        height: root.badgeHeight
        visible: !!root.parentTask?.badgeVisible
        appId: root.parentTask?.model?.AppId || ""
        
        isUrgent: !!root.parentTask?.hasUnseenNotifications || !!root.parentTask?.model?.DemandsAttention
        isRound: true
        isBold: false
        fontFactor: 0.7
    }
}
