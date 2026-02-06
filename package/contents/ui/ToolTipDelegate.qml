/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQml.Models
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

import org.kde.plasma.plasmoid

import "code/singletones"

Loader {
    id: toolTipDelegate

    required property Task parentTask
    required property var rootIndex
    property var tasksModel
    property var mpris2Model
    property var pulseAudio: null
    
    // Pass Cache from Root (tasks) down to Instances
    property var thumbnailCache: tasks.thumbnailCache
    
    function getHovered(target) {
        return target && target.isHovered;
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

        if (!Plasmoid.configuration.showOnlyCurrentDesktop && virtualDesktopInfo.numberOfDesktops > 1) {
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
            if (Plasmoid.configuration.showOnlyCurrentActivity) {
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
    property bool smartLauncherCountVisible
    property int smartLauncherCount
    property bool isPlayingAudio
    property bool isMuted

    readonly property string calculatedAppName: {
        if (appName && appName.length > 0) return appName;

        const text = display;
        if (!text) return "";
        
        const versionRegex = /\s+(?:—|-|–)\s+([^\s(—|-|–)]+)\s+(?:—|-|–)\s+v?\d+(?:\.\d+)+.*$/i;
        const matchVersion = text.match(versionRegex);
        if (matchVersion && matchVersion[1]) {
            return matchVersion[1];
        }

        const lastSepRegex = /.*(?:—|-|–)\s+(.*)$/;
        const matchLast = text.match(lastSepRegex);
        if (matchLast && matchLast[1]) {
            return matchLast[1];
        }

        return "";
    }

    readonly property bool isVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int tooltipInstanceMaximumWidth: Kirigami.Units.gridUnit * 14

    readonly property Mpris.PlayerContainer playerData: mpris2Model && mpris2Model.playerForLauncherUrl ? mpris2Model.playerForLauncherUrl(launcherUrl, pidParent) : null
    
    // Using showToolTips as the toggle for "Show Thumbnails"
    readonly property bool showThumbnails: Plasmoid.configuration.showToolTips

    function getAppLayoutDirection(app) {
        return app.layoutDirection;
    }
    LayoutMirroring.enabled: getAppLayoutDirection(Qt.application) === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    active: rootIndex !== undefined
    asynchronous: false

    sourceComponent: isGroup ? groupToolTip : singleTooltip

    Component {
        id: singleTooltip

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            
            Layout.margins: Kirigami.Units.mediumSpacing
            
            property alias isHovered: singleHover.hovered
            
            HoverHandler {
                id: singleHover
            }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.maximumWidth: toolTipDelegate.tooltipInstanceMaximumWidth
                horizontalAlignment: Text.AlignHCenter
                
                text: toolTipDelegate.calculatedAppName
                font.bold: true
                elide: Text.ElideRight
                visible: toolTipDelegate.showThumbnails && text.length > 0
                opacity: 0.8
            }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.maximumWidth: toolTipDelegate.tooltipInstanceMaximumWidth
                horizontalAlignment: Text.AlignHCenter
                
                text: toolTipDelegate.generateSubText()
                wrapMode: Text.Wrap
                visible: toolTipDelegate.showThumbnails && text.length > 0
                opacity: 0.6
                textFormat: Text.PlainText
            }

            ToolTipInstance {
                visible: toolTipDelegate.windows.length > 0
                
                index: 0 
                submodelIndex: toolTipDelegate.rootIndex
                appPid: toolTipDelegate.pidParent
                appId: (toolTipDelegate.parentTask && toolTipDelegate.parentTask.appId) ? toolTipDelegate.parentTask.appId : "" // Fallback
                display: toolTipDelegate.display
                isMinimized: toolTipDelegate.isMinimized
                isOnAllVirtualDesktops: toolTipDelegate.isOnAllVirtualDesktops
                virtualDesktops: toolTipDelegate.virtualDesktops
                activities: toolTipDelegate.activities
                
                tasksModel: toolTipDelegate.tasksModel
                toolTipDelegate: toolTipDelegate

                mpris2Model: toolTipDelegate.mpris2Model
                pulseAudio: toolTipDelegate.pulseAudio
                
                isPlayingAudio: toolTipDelegate.isPlayingAudio
                isMuted: toolTipDelegate.isMuted
            }
        }
    }

    Component {
        id: groupToolTip

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            property alias isHovered: groupHover.hovered
            
            readonly property int safeCount: toolTipDelegate.windows.length > 0 ? toolTipDelegate.windows.length : 1
            readonly property int maxTooltipWidth: Screen.width - Kirigami.Units.gridUnit * 2
            readonly property int maxTooltipHeight: Screen.height - Kirigami.Units.gridUnit * 2
            readonly property real contentTargetWidth: {
                 // Use same logic as DelegateModel
                 const count = (!toolTipDelegate.showThumbnails || toolTipDelegate.isVerticalPanel) ? 1 : safeCount;
                 return Math.ceil(count * toolTipDelegate.tooltipInstanceMaximumWidth + Math.max(0, count - 1) * Kirigami.Units.smallSpacing);
            }

            HoverHandler {
                id: groupHover
            }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.maximumWidth: parent.contentTargetWidth
                horizontalAlignment: Text.AlignHCenter
                
                text: toolTipDelegate.calculatedAppName
                font.bold: true
                elide: Text.ElideRight
                visible: toolTipDelegate.showThumbnails && text.length > 0
                opacity: 0.8
            }

            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.maximumWidth: parent.contentTargetWidth
                horizontalAlignment: Text.AlignHCenter
                
                text: toolTipDelegate.generateSubText()
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
                visible: toolTipDelegate.showThumbnails && text.length > 0
                opacity: 0.6
                textFormat: Text.PlainText
            }

            PlasmaComponents3.ScrollView {
                id: scrollView
                // hovered is now handled by groupHover on the parent ColumnLayout
                

                
                // Remove default padding/background to prevent size mismatch
                padding: 0
                background: null
                
                // Hide scrollbars unless content strictly exceeds screen limits (prevents resize flickering)
                ScrollBar.horizontal.policy: (parent.contentTargetWidth > parent.maxTooltipWidth) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: (groupToolTipListView.contentHeight > parent.maxTooltipHeight) ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                // Explicitly bind ListView as the scrollable content item for native wheel/touch handling
                contentItem: groupToolTipListView

                // Enable clipping to ensure scrollbars render correctly within bounds
                clip: true
                
                // Match content size strictly, but cap at screen limits
                Layout.preferredWidth: Math.min(parent.contentTargetWidth, parent.maxTooltipWidth)
                Layout.preferredHeight: Math.min(Math.max(groupToolTipListView.contentHeight, delegateModel.estimatedHeight), parent.maxTooltipHeight)
                Layout.fillWidth: false 
                
                implicitHeight: Math.min(Math.max(groupToolTipListView.contentHeight, delegateModel.estimatedHeight), parent.maxTooltipHeight)
                implicitWidth: Math.min(groupToolTipListView.width, parent.maxTooltipWidth)

                ListView {
                    id: groupToolTipListView

                    // Content Width Logic
                    width: parent.contentTargetWidth
                    // Height is managed by ScrollView (fills viewport)
     
                    model: delegateModel
                    
                    // FORCE VERTICAL LIST if thumbnails are disabled
                    orientation: (!toolTipDelegate.showThumbnails || toolTipDelegate.isVerticalPanel) ?
                        ListView.Vertical : ListView.Horizontal
                        
                    reuseItems: true
                    spacing: Kirigami.Units.smallSpacing
                    
                    clip: false
                }

                DelegateModel {
                    id: delegateModel

                    readonly property int safeCount: toolTipDelegate.windows.length > 0 ? toolTipDelegate.windows.length : count

                    readonly property real screenRatio: Screen.width / Screen.height
                    
                    // If thumbnails disabled -> height is 0
                    readonly property int instanceThumbHeight: toolTipDelegate.showThumbnails ? 
                        Math.round(toolTipDelegate.tooltipInstanceMaximumWidth / screenRatio) : 0
                    
                    // Reduced padding for overlay style (was * 3)
                    readonly property real singleItemHeight: instanceThumbHeight


                    
                    readonly property real estimatedHeight: {
                        const count = (!toolTipDelegate.showThumbnails || toolTipDelegate.isVerticalPanel) ? safeCount : 1;
                        return count * singleItemHeight + Math.max(0, count - 1) * Kirigami.Units.smallSpacing;
                    }

                    model: toolTipDelegate.tasksModel
                    rootIndex: toolTipDelegate.rootIndex
                    onRootIndexChanged: groupToolTipListView.positionViewAtBeginning()

                    delegate: ToolTipInstance {
                        required property var model
                        
                        width: toolTipDelegate.tooltipInstanceMaximumWidth
                        
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

                        submodelIndex: tasksModel.makeModelIndex(toolTipDelegate.rootIndex.row, index)
                        tasksModel: toolTipDelegate.tasksModel
                        toolTipDelegate: toolTipDelegate

                        mpris2Model: toolTipDelegate.mpris2Model
                        pulseAudio: toolTipDelegate.pulseAudio
                    }
                }
            }
        }
    }
}
