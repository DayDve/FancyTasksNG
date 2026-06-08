/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2024 Nicolas Fella <nicolas.fella@gmx.de>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2023 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQml.Models
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

import "code/singletones"

Loader {
    id: toolTipDelegate

    required property Task parentTask
    required property var rootIndex
    property var tasksModel
    property var mpris2Model
    property var audioStreamManager: null
    
    // Pass Cache from Root (tasks) down to Instances
    property var thumbnailCache: tasks.thumbnailCache

    readonly property var config: Plasmoid.configuration

    readonly property bool isActive: (tasksModel && rootIndex.valid) ? tasksModel.data(rootIndex, TaskManager.AbstractTasksModel.IsActive) === true : false
    
    property int innerDragCount: 0
    
    function getHovered(target) {
        return (target && target.isHovered) || innerDragCount > 0;
    }
    readonly property bool containsMouse: getHovered(item)
    onContainsMouseChanged: {
        if (!containsMouse && parentTask && parentTask.tasksRoot) {
             parentTask.tasksRoot.cancelHighlightWindows();
        }
    }

    function generateSubText(): string {
        const subTextEntries = [];
        
        // Include Generic Name (Description) for Pinned Apps (no windows) or if relevant
        if (!isWin && genericName.length > 0 && genericName !== calculatedAppName) {
            subTextEntries.push(genericName);
        }

        if (!toolTipDelegate.config.showOnlyCurrentDesktop && virtualDesktopInfo.numberOfDesktops > 1) {
            if (!isOnAllVirtualDesktops && virtualDesktops.length > 0) {
                const virtualDesktopNameList = virtualDesktops.map(virtualDesktop => {
                    const index = virtualDesktopInfo.desktopIds.indexOf(virtualDesktop);
                    return virtualDesktopInfo.desktopNames[index];
                });

                subTextEntries.push(Wrappers.i18nc("Comma-separated list of desktops", "On %1", virtualDesktopNameList.join(", ")));
            } else if (isOnAllVirtualDesktops) {
                subTextEntries.push(Wrappers.i18nc("Comma-separated list of desktops", "Pinned to all desktops"));
            }
        }

        if (activities.length === 0 && activityInfo.numberOfRunningActivities > 1) {
            subTextEntries.push(Wrappers.i18nc("Which virtual desktop a window is currently on", "Available on all activities"));
        } else if (activities.length > 0) {
            const activityNames = activities.filter(activity => activity !== activityInfo.currentActivity).map(activity => activityInfo.activityName(activity)).filter(activityName => activityName !== "");
            if (toolTipDelegate.config.showOnlyCurrentActivity) {
                if (activityNames.length > 0) {
                    subTextEntries.push(Wrappers.i18nc("Activities a window is currently on (apart from the current one)", "Also available on %1", activityNames.join(", ")));
                }
            } else if (activityNames.length > 0) {
                subTextEntries.push(Wrappers.i18nc("Which activities a window is currently on", "Available on %1", activityNames.join(", ")));
            }
        }

        return subTextEntries.join("\n");
    }

    property string appName
    property int pidParent
    property bool isGroup
    property var windows: []
    readonly property bool isWin: windows.length > 0
    property var icon
    property url launcherUrl
    property bool isLauncher
    property bool isMinimized
    property string display
    property string genericName
    property var virtualDesktops: []
    property bool isOnAllVirtualDesktops
    property list<string> activities: []
    property string appId: (tasksModel && rootIndex.valid) ? tasksModel.data(rootIndex, TaskManager.AbstractTasksModel.AppId) : ""
    property bool isPlayingAudio
    property bool isMuted

    readonly property string calculatedAppName: {
        let name = "";
        if (appName && appName.length > 0) {
            name = appName;
        } else {
            const text = display;
            if (text) {
                const versionRegex = /\s+(?:—|-|–)\s+([^\s(—|-|–)]+)\s+(?:—|-|–)\s+v?\d+(?:\.\d+)+.*$/i;
                const matchVersion = text.match(versionRegex);
                if (matchVersion && matchVersion[1]) {
                    name = matchVersion[1];
                } else {
                    const lastSepRegex = /.*(?:—|-|–)\s+(.*)$/;
                    const matchLast = text.match(lastSepRegex);
                    if (matchLast && matchLast[1]) {
                        name = matchLast[1];
                    }
                }
            }
        }
        return name;
    }

    readonly property bool isVerticalPanel: tasks.vertical
    readonly property int tooltipInstanceMaximumWidth: Kirigami.Units.gridUnit * 14

    property bool forceTextMode: false

    // Thumbnails are shown only when both the parent tooltip toggle and the thumbnail sub-option are enabled.
    readonly property bool showThumbnails: toolTipDelegate.config.enableToolTips && toolTipDelegate.config.showToolTips && !forceTextMode

    function getAppLayoutDirection(app) {
        return app.layoutDirection;
    }
    LayoutMirroring.enabled: getAppLayoutDirection(Qt.application) === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // Do not load the tooltip at all when tooltips are disabled — prevents PipeWireThumbnail from
    // attempting to grab invisible window images and emitting "grabToImage: item's window is not visible".
    active: rootIndex !== undefined && toolTipDelegate.config.enableToolTips
    asynchronous: false

    sourceComponent: isGroup ? groupToolTip : singleTooltip

    Component {
        id: singleTooltip

        Item {
            id: singleRoot
            implicitWidth: singleLayout.implicitWidth
            implicitHeight: singleLayout.implicitHeight

            property bool isHovered: singleHover.hovered || singleDrop.containsDrag

            // Cached delegate properties
            readonly property bool showThumbnails: toolTipDelegate.showThumbnails
            readonly property bool isWin: toolTipDelegate.isWin
            readonly property string calculatedAppName: toolTipDelegate.calculatedAppName
            readonly property string appId: toolTipDelegate.appId
            readonly property var config: toolTipDelegate.config
            readonly property var parentTask: toolTipDelegate.parentTask
            readonly property int tooltipInstanceMaximumWidth: toolTipDelegate.tooltipInstanceMaximumWidth
            readonly property var windows: toolTipDelegate.windows
            
            readonly property var rootIndex: toolTipDelegate.rootIndex
            readonly property int pidParent: toolTipDelegate.pidParent
            readonly property string display: toolTipDelegate.display
            readonly property bool isMinimized: toolTipDelegate.isMinimized
            readonly property bool isOnAllVirtualDesktops: toolTipDelegate.isOnAllVirtualDesktops
            readonly property var virtualDesktops: toolTipDelegate.virtualDesktops
            readonly property var activities: toolTipDelegate.activities
            readonly property bool isActive: toolTipDelegate.isActive
            readonly property var tasksModel: toolTipDelegate.tasksModel
            readonly property var mpris2Model: toolTipDelegate.mpris2Model
            readonly property var audioStreamManager: toolTipDelegate.audioStreamManager
            readonly property bool isPlayingAudio: toolTipDelegate.isPlayingAudio
            readonly property bool isMuted: toolTipDelegate.isMuted

            HoverHandler {
                id: singleHover
            }

            DropArea {
                id: singleDrop
                anchors.fill: parent
            }

            ColumnLayout {
                id: singleLayout
                spacing: Kirigami.Units.smallSpacing

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    visible: singleRoot.calculatedAppName.length > 0 && (!singleRoot.isWin || singleRoot.showThumbnails)
                    opacity: 0.8
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Label {
                        id: nameLabel
                        text: singleRoot.calculatedAppName
                        font.bold: true
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, singleRoot.tooltipInstanceMaximumWidth - (badge.visible ? badge.width + parent.spacing : 0) - Kirigami.Units.gridUnit)
                    }

                    Badge {
                        id: badge
                        visible: singleRoot.config.showBadges && (singleRoot.parentTask ? singleRoot.parentTask.badgeVisible : false)
                        appId: singleRoot.appId
                        isUrgent: (singleRoot.config.badgeHighlightNew && singleRoot.parentTask) ? singleRoot.parentTask.hasUnseenNotifications : false
                        height: Math.round(Kirigami.Units.gridUnit * 0.85)
                        isRound: false
                        fontPointSize: 8
                        maxNumber: 0
                    }
                }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.gridUnit / 2
                Layout.rightMargin: Kirigami.Units.gridUnit / 2
                Layout.maximumWidth: singleRoot.tooltipInstanceMaximumWidth - Layout.leftMargin - Layout.rightMargin
                horizontalAlignment: Text.AlignHCenter
                
                text: toolTipDelegate.generateSubText()
                wrapMode: Text.Wrap
                visible: text.length > 0 && (!singleRoot.isWin || singleRoot.showThumbnails)
                opacity: 0.6
                textFormat: Text.PlainText
            }

            Loader {
                id: singleInstanceLoader
                visible: singleRoot.windows.length > 0
                
                property var currentWin: singleRoot.isWin ? singleRoot.windows[0] : undefined
                
                Timer {
                    id: reloadTimer
                    interval: 1
                    onTriggered: singleInstanceLoader.active = true
                }

                onCurrentWinChanged: {
                    active = false;
                    reloadTimer.restart();
                }
                
                sourceComponent: ToolTipInstance {    
                    index: 0 
                    height: implicitHeight
                    submodelIndex: singleRoot.rootIndex
                    explicitWinId: singleInstanceLoader.currentWin
                    
                    appPid: singleRoot.pidParent
                    appId: (singleRoot.parentTask && singleRoot.parentTask.appId) ? singleRoot.parentTask.appId : ""
                    display: singleRoot.display
                    isMinimized: singleRoot.isMinimized
                    isOnAllVirtualDesktops: singleRoot.isOnAllVirtualDesktops
                    virtualDesktops: singleRoot.virtualDesktops
                    activities: singleRoot.activities
                    
                    isWindowActive: singleRoot.isActive
                    
                    tasksModel: singleRoot.tasksModel
                    toolTipDelegate: toolTipDelegate

                    mpris2Model: singleRoot.mpris2Model
                    audioStreamManager: singleRoot.audioStreamManager
                    
                    isPlayingAudio: singleRoot.isPlayingAudio
                    isMuted: singleRoot.isMuted
                }
            }
        }
    }
}

    Component {
        id: groupToolTip

        Item {
            id: groupRoot
            implicitWidth: groupLayout.implicitWidth
            implicitHeight: groupLayout.implicitHeight

            property bool isHovered: groupHover.hovered || groupDrop.containsDrag

            // Cached delegate properties
            readonly property bool showThumbnails: toolTipDelegate.showThumbnails
            readonly property bool isWin: toolTipDelegate.isWin
            readonly property string calculatedAppName: toolTipDelegate.calculatedAppName
            readonly property string appId: toolTipDelegate.appId
            readonly property var config: toolTipDelegate.config
            readonly property var parentTask: toolTipDelegate.parentTask
            readonly property int tooltipInstanceMaximumWidth: toolTipDelegate.tooltipInstanceMaximumWidth
            readonly property var windows: toolTipDelegate.windows
            readonly property bool isVerticalPanel: toolTipDelegate.isVerticalPanel
            
            readonly property var rootIndex: toolTipDelegate.rootIndex
            readonly property var tasksModel: toolTipDelegate.tasksModel
            readonly property var mpris2Model: toolTipDelegate.mpris2Model
            readonly property var audioStreamManager: toolTipDelegate.audioStreamManager
            
            HoverHandler {
                id: groupHover
            }

            DropArea {
                id: groupDrop
                anchors.fill: parent
            }

            ColumnLayout {
                id: groupLayout
                spacing: Kirigami.Units.smallSpacing
                
                readonly property int safeCount: groupRoot.isWin ? groupRoot.windows.length : 1
                readonly property int maxTooltipWidth: Screen.width - Kirigami.Units.gridUnit * 2
                readonly property int maxTooltipHeight: Screen.height - Kirigami.Units.gridUnit * 2
                readonly property real contentTargetWidth: {
                     // Use same logic as DelegateModel
                     const count = (!groupRoot.showThumbnails || groupRoot.isVerticalPanel) ? 1 : safeCount;
                     return Math.ceil(count * groupRoot.tooltipInstanceMaximumWidth + Math.max(0, count - 1) * Kirigami.Units.smallSpacing);
                }
                
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    visible: groupRoot.calculatedAppName.length > 0 && groupRoot.showThumbnails
                    opacity: 0.8
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Label {
                        id: groupNameLabel
                        text: groupRoot.calculatedAppName
                        font.bold: true
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, groupLayout.contentTargetWidth - (groupBadge.visible ? groupBadge.width + parent.spacing : 0) - Kirigami.Units.gridUnit)
                    }

                    Badge {
                        id: groupBadge
                        visible: groupRoot.config.showBadges && (groupRoot.parentTask ? groupRoot.parentTask.badgeVisible : false)
                        appId: groupRoot.appId
                        isUrgent: (groupRoot.config.badgeHighlightNew && groupRoot.parentTask) ? groupRoot.parentTask.hasUnseenNotifications : false
                        height: Math.round(Kirigami.Units.gridUnit * 0.85)
                        isRound: false
                        fontPointSize: 8
                        maxNumber: 0
                    }
                }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.gridUnit / 2
                Layout.rightMargin: Kirigami.Units.gridUnit / 2
                Layout.maximumWidth: groupLayout.contentTargetWidth - Layout.leftMargin - Layout.rightMargin
                horizontalAlignment: Text.AlignHCenter
                
                text: toolTipDelegate.generateSubText()
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
                visible: groupRoot.showThumbnails && text.length > 0
                opacity: 0.6
                textFormat: Text.PlainText
            }

            PlasmaComponents3.ScrollView {
                id: scrollView
                // hovered is now handled by groupHover on the parent ColumnLayout
                
                // In text mode (no thumbnails), extend to tooltip edges
                Layout.leftMargin: groupRoot.showThumbnails ? 0 : -6
                Layout.rightMargin: groupRoot.showThumbnails ? 0 : -6
                Layout.bottomMargin: groupRoot.showThumbnails ? 0 : -6
                
                // Remove default padding/background to prevent size mismatch
                padding: 0
                background: null
                
                // Hide scrollbars unless content strictly exceeds screen limits (prevents resize flickering)
                ScrollBar.horizontal.policy: (groupLayout.contentTargetWidth > groupLayout.maxTooltipWidth) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: (groupToolTipListView.contentHeight > groupLayout.maxTooltipHeight) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                // Explicitly bind ListView as the scrollable content item for native wheel/touch handling
                contentItem: groupToolTipListView

                // Enable clipping to ensure scrollbars render correctly within bounds
                clip: true
                
                // Match content size strictly, but cap at screen limits
                Layout.preferredWidth: Math.min(groupLayout.contentTargetWidth, groupLayout.maxTooltipWidth)
                Layout.preferredHeight: Math.min(Math.max(groupToolTipListView.contentHeight, groupRoot.showThumbnails ? delegateModel.estimatedHeight : 0), groupLayout.maxTooltipHeight)
                Layout.fillWidth: false 
                
                implicitHeight: Math.min(Math.max(groupToolTipListView.contentHeight, groupRoot.showThumbnails ? delegateModel.estimatedHeight : 0), groupLayout.maxTooltipHeight)
                implicitWidth: Math.min(groupToolTipListView.width, groupLayout.maxTooltipWidth)

                ListView {
                    id: groupToolTipListView

                    // Content Width Logic
                    width: groupLayout.contentTargetWidth
                    // Height is managed by ScrollView (fills viewport)
     
                    model: delegateModel
                    
                    // FORCE VERTICAL LIST if thumbnails are disabled
                    orientation: (!groupRoot.showThumbnails || groupRoot.isVerticalPanel) ?
                        ListView.Vertical : ListView.Horizontal
                        
                    reuseItems: true
                    spacing: Kirigami.Units.smallSpacing
                    
                    clip: false
                }

                DelegateModel {
                    id: delegateModel

                    readonly property int safeCount: groupRoot.isWin ? groupRoot.windows.length : count

                    readonly property real screenRatio: Screen.width / Screen.height
                    
                    // If thumbnails disabled -> height is 0
                    readonly property int instanceThumbHeight: groupRoot.showThumbnails ? 
                        Math.round(groupRoot.tooltipInstanceMaximumWidth / screenRatio) : 0
                    
                    // Reduced padding for overlay style (was * 3)
                    // Fallback to 2 grid units for Text Mode items
                    readonly property real singleItemHeight: instanceThumbHeight > 0 ? instanceThumbHeight : Kirigami.Units.gridUnit * 2


                    
                    readonly property real estimatedHeight: {
                        const count = (!groupRoot.showThumbnails || groupRoot.isVerticalPanel) ? safeCount : 1;
                        return count * singleItemHeight + Math.max(0, count - 1) * Kirigami.Units.smallSpacing;
                    }

                    model: groupRoot.tasksModel
                    rootIndex: groupRoot.rootIndex
                    onRootIndexChanged: groupToolTipListView.positionViewAtBeginning()

                    delegate: ToolTipInstance {
                        required property var model
                        
                        width: groupRoot.tooltipInstanceMaximumWidth
                        height: implicitHeight
                        
                        index: index 
                        
                        // FIX: Get Window ID from current task model
                        explicitWinId: (model.WinIdList !== undefined && model.WinIdList.length > 0) ? model.WinIdList[0] : undefined

                        display: model.display !== undefined ? model.display : ""
                        appPid: model.AppPid !== undefined ? model.AppPid : 0
                        appId: model.AppId !== undefined ? model.AppId : ""
                        isMinimized: model.IsMinimized !== undefined ? model.IsMinimized : false
                        isOnAllVirtualDesktops: model.IsOnAllVirtualDesktops !== undefined ? model.IsOnAllVirtualDesktops : false
                        virtualDesktops: model.VirtualDesktops !== undefined ? model.VirtualDesktops : []
                        activities: model.Activities !== undefined ? model.Activities : []
                        
                        isPlayingAudio: model.IsPlayingAudio !== undefined ? model.IsPlayingAudio : false
                        isMuted: model.IsMuted !== undefined ? model.IsMuted : false
                        isWindowActive: model.IsActive !== undefined ? model.IsActive : false

                        submodelIndex: groupRoot.tasksModel.makeModelIndex(groupRoot.rootIndex.row, index)
                        tasksModel: groupRoot.tasksModel
                        toolTipDelegate: toolTipDelegate

                        mpris2Model: groupRoot.mpris2Model
                        audioStreamManager: groupRoot.audioStreamManager
                    }
                }
            }
        }
    }
}
}
