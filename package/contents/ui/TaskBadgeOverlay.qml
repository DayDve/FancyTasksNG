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

    // Audio Indicator (Top-Left)
    Badge {
        id: audioBadge
        anchors.left: parent.left
        anchors.top: parent.top
        // Diving deeper and moving closer to center when hovered
        anchors.topMargin: (root.parentTask && root.parentTask.tasksRoot.iconsOnly && root.parentTask.highlighted) 
            ? Math.round(height / 4) 
            : 0
        anchors.leftMargin: (root.parentTask && root.parentTask.tasksRoot.iconsOnly && root.parentTask.highlighted) 
            ? Math.round(width / 6) 
            : 0
        
        Behavior on anchors.topMargin {
            enabled: root.parentTask && root.parentTask.tasksRoot.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.leftMargin {
            enabled: root.parentTask && root.parentTask.tasksRoot.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        
        width: Math.min(Math.round(parent.height * 0.35), Kirigami.Units.gridUnit)
        height: width
        
        visible: root.parentTask ? (root.parentTask.playingAudio || root.parentTask.muted) : false
        
        iconSource: root.parentTask?.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
        highlightColor: root.parentTask?.muted ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
        
        showBackground: root.parentTask ? root.parentTask.muted : false
        hovered: !!audioMouseArea.containsMouse
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
        anchors.top: parent.top
        anchors.topMargin: (root.parentTask && root.parentTask.tasksRoot.iconsOnly && root.parentTask.highlighted) 
            ? Math.round(height / 4) 
            : 0
        anchors.rightMargin: (root.parentTask && root.parentTask.tasksRoot.iconsOnly && root.parentTask.highlighted) 
            ? Math.round(width / 6) 
            : 0

        Behavior on anchors.topMargin {
            enabled: root.parentTask && root.parentTask.tasksRoot.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.rightMargin {
            enabled: root.parentTask && root.parentTask.tasksRoot.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }

        height: Math.min(Math.round(parent.height * 0.35), Kirigami.Units.gridUnit)
        
        visible: !!root.parentTask?.badgeVisible
        number: root.parentTask?.badgeCount || 0
        
        isUrgent: !!root.parentTask?.demandsAttention
        isRound: true
        isBold: false
        fontFactor: 0.85
    }
}
