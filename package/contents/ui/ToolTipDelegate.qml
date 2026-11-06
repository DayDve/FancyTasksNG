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
import org.kde.plasma.private.mpris as Mpris

import "code/singletones"

Loader {
    id: toolTipDelegate

    required property Task parentTask
    required property var rootIndex
    property var tasksModel
    property var mediaRegistry: null
    
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
    readonly property rect tooltipScreenGeometry: Plasmoid.containment?.screenGeometry ?? Qt.rect(0, 0, 0, 0)
    readonly property bool hasValidTooltipScreenGeometry: tooltipScreenGeometry.width > 0 && tooltipScreenGeometry.height > 0
    readonly property bool matchWindowAspectRatio: toolTipDelegate.config.tooltipMatchWindowAspectRatio
    // Deriving from Screen.width/height gives a snugger fit than a fixed
    // ratio for most monitors, but on an extreme ultrawide (e.g. 5120x1440,
    // ~3.56:1) it squashes the thumbnail into a sliver most windows render
    // tiny inside of. Clamped to the range of ordinary desktop monitor shapes
    // (4:3 up through 21:9) so normal - even slightly non-16:9 - screens
    // behave exactly as before, and only the pathological cases get capped (#55).
    readonly property real screenRatio: Math.max(4 / 3, Math.min(21 / 9, Screen.width / Screen.height))
    // Every thumbnail has this height, in both modes: a maximized window's
    // thumbnail is the reference, and in window mode a smaller or narrower
    // window only gets narrower, never taller.
    readonly property int tooltipThumbnailHeight: Math.round(tooltipInstanceMaximumWidth / screenRatio)
    // Room for the overlaid title and close button on narrow (portrait) windows.
    readonly property int minThumbnailWidth: Kirigami.Units.gridUnit * 6
    readonly property int maxThumbnailWidth: tooltipInstanceMaximumWidth * 2

    // Screen mode: the screen-shaped box. Window mode: as wide as the window's
    // own aspect ratio makes it at the shared height, so it has no empty
    // bands at the sides. Called from bindings with a live Geometry role
    // value, so it follows windows being resized while the tooltip is open.
    function thumbnailWidthFor(geometry): int {
        if (!toolTipDelegate.matchWindowAspectRatio || !geometry || geometry.width <= 0 || geometry.height <= 0) {
            return toolTipDelegate.tooltipInstanceMaximumWidth;
        }
        const width = Math.round(toolTipDelegate.tooltipThumbnailHeight * geometry.width / geometry.height);
        return Math.max(toolTipDelegate.minThumbnailWidth, Math.min(toolTipDelegate.maxThumbnailWidth, width));
    }

    // Bumped on geometry changes so the group's total width - summed over
    // model.data() lookups, which bindings can't track - is recomputed.
    property int geometryRevision: 0
    Connections {
        target: toolTipDelegate.matchWindowAspectRatio ? toolTipDelegate.tasksModel : null
        function onDataChanged(topLeft, bottomRight, roles): void {
            if (roles.length === 0 || roles.indexOf(TaskManager.AbstractTasksModel.Geometry) !== -1) {
                toolTipDelegate.geometryRevision++;
            }
        }
    }

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
            readonly property var mediaRegistry: toolTipDelegate.mediaRegistry

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
                        number: singleRoot.parentTask ? singleRoot.parentTask.badgeCount : 0
                        isUrgent: (singleRoot.config.badgeHighlightNew && singleRoot.parentTask) ? singleRoot.parentTask.hasUnseenNotifications : false
                        height: Math.round(Kirigami.Units.gridUnit * 0.85)
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
                    windowGeometry: singleRoot.parentTask?.model?.Geometry ?? Qt.rect(0, 0, 0, 0)
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

                    mediaRegistry: singleRoot.mediaRegistry
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
            readonly property int tooltipThumbnailHeight: toolTipDelegate.tooltipThumbnailHeight
            readonly property rect tooltipScreenGeometry: toolTipDelegate.tooltipScreenGeometry
            readonly property bool hasValidTooltipScreenGeometry: toolTipDelegate.hasValidTooltipScreenGeometry
            readonly property var windows: toolTipDelegate.windows
            readonly property bool isVerticalPanel: toolTipDelegate.isVerticalPanel
            
            readonly property var rootIndex: toolTipDelegate.rootIndex
            readonly property var tasksModel: toolTipDelegate.tasksModel
            readonly property var mediaRegistry: toolTipDelegate.mediaRegistry

            // PIDs with more than one window in this group (a browser runs all
            // its windows in one process). Their single MPRIS player and their
            // streams can't be pinned to one thumbnail, so they get one shared
            // panel below the thumbnails instead of controls on every window.
            readonly property var sharedPids: {
                const counts = {};
                const pids = [];
                for (let i = 0; i < groupRoot.windows.length; ++i) {
                    const childIndex = groupRoot.tasksModel.makeModelIndex(groupRoot.rootIndex.row, i);
                    const pid = groupRoot.tasksModel.data(childIndex, TaskManager.AbstractTasksModel.AppPid);
                    if (pid > 0) {
                        counts[pid] = (counts[pid] ?? 0) + 1;
                        if (counts[pid] === 2) {
                            pids.push(pid);
                        }
                    }
                }
                return pids;
            }
            readonly property bool showGroupMedia: groupRoot.config.showMediaControls && groupRoot.config.groupMediaControls === 0

            Instantiator {
                id: groupMediaControllers
                model: groupRoot.showGroupMedia ? groupRoot.sharedPids : []
                delegate: ToolTipMediaController {
                    required property int modelData
                    toolTipDelegate: toolTipDelegate
                    appPid: modelData
                    appId: groupRoot.appId
                    mediaRegistry: groupRoot.mediaRegistry
                    index: 0
                }
            }

            // Usually there's one shared process; if there are several, show
            // the one that's playing.
            readonly property var groupMediaController: {
                let best = null;
                let bestScore = 0;
                for (let i = 0; i < groupMediaControllers.count; ++i) {
                    const controller = groupMediaControllers.objectAt(i);
                    if (!controller || !controller.controlsAreEffective) {
                        continue;
                    }
                    const playing = controller.playerData && controller.playerData.playbackStatus === Mpris.PlaybackStatus.Playing;
                    const score = 1 + (controller.playingAudio ? 2 : 0) + (playing ? 4 : 0);
                    if (score > bestScore) {
                        best = controller;
                        bestScore = score;
                    }
                }
                return best;
            }

            // The panel's track title activates the window showing that track,
            // or else the process's first window.
            function activateMediaWindow(controller): void {
                const track = controller.playerData && controller.playerData.track ? controller.playerData.track : "";
                let target = null;
                for (let i = 0; i < groupRoot.windows.length; ++i) {
                    const childIndex = groupRoot.tasksModel.makeModelIndex(groupRoot.rootIndex.row, i);
                    if (groupRoot.tasksModel.data(childIndex, TaskManager.AbstractTasksModel.AppPid) !== controller.appPid) {
                        continue;
                    }
                    if (!target) {
                        target = childIndex;
                    }
                    const display = groupRoot.tasksModel.data(childIndex, Qt.DisplayRole);
                    if (track && display && display.includes(track)) {
                        target = childIndex;
                        break;
                    }
                }
                if (!target) {
                    return;
                }
                groupRoot.tasksModel.requestActivate(target);
                if (groupRoot.parentTask) {
                    groupRoot.parentTask.closeTooltip();
                    if (groupRoot.parentTask.tasksRoot) {
                        groupRoot.parentTask.tasksRoot.cancelHighlightWindows();
                    }
                }
            }

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
                readonly property int maxTooltipWidth: (groupRoot.hasValidTooltipScreenGeometry
                    ? groupRoot.tooltipScreenGeometry.width
                    : Screen.width) - Kirigami.Units.gridUnit * 2
                readonly property int maxTooltipHeight: (groupRoot.hasValidTooltipScreenGeometry
                    ? groupRoot.tooltipScreenGeometry.height
                    : Screen.height) - Kirigami.Units.gridUnit * 2
                // Thumbnails can differ in width (window aspect mode), so the row
                // is the sum of their widths - or the widest one when stacked.
                readonly property real contentTargetWidth: {
                    if (!groupRoot.showThumbnails) {
                        return groupRoot.tooltipInstanceMaximumWidth;
                    }
                    void toolTipDelegate.geometryRevision;
                    const widths = [];
                    for (let i = 0; i < safeCount; ++i) {
                        const childIndex = groupRoot.tasksModel.makeModelIndex(groupRoot.rootIndex.row, i);
                        widths.push(toolTipDelegate.thumbnailWidthFor(groupRoot.tasksModel.data(childIndex, TaskManager.AbstractTasksModel.Geometry)));
                    }
                    if (widths.length === 0) {
                        return groupRoot.tooltipInstanceMaximumWidth;
                    }
                    if (groupRoot.isVerticalPanel) {
                        return Math.max(...widths);
                    }
                    return Math.ceil(widths.reduce((sum, width) => sum + width, 0) + (widths.length - 1) * Kirigami.Units.smallSpacing);
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
                        number: groupRoot.parentTask ? groupRoot.parentTask.badgeCount : 0
                        isUrgent: (groupRoot.config.badgeHighlightNew && groupRoot.parentTask) ? groupRoot.parentTask.hasUnseenNotifications : false
                        height: Math.round(Kirigami.Units.gridUnit * 0.85)
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
                Layout.preferredHeight: Math.min(Math.max(groupToolTipListView.contentExtent, groupRoot.showThumbnails ? delegateModel.estimatedHeight : 0), groupLayout.maxTooltipHeight)
                Layout.fillWidth: false 
                
                implicitHeight: Math.min(Math.max(groupToolTipListView.contentExtent, groupRoot.showThumbnails ? delegateModel.estimatedHeight : 0), groupLayout.maxTooltipHeight)
                implicitWidth: Math.min(groupToolTipListView.width, groupLayout.maxTooltipWidth)

                ListView {
                    id: groupToolTipListView

                    // Content Width Logic
                    width: groupLayout.contentTargetWidth
                    // A horizontal ListView leaves contentHeight at -1, so take the
                    // tallest delegate instead - otherwise anything below a
                    // thumbnail (the under-thumbnail media bar) gets clipped (#60).
                    readonly property real contentExtent: orientation === ListView.Horizontal
                        ? contentItem.childrenRect.height : contentHeight
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

                    // If thumbnails disabled -> height is 0
                    readonly property int instanceThumbHeight: groupRoot.showThumbnails ?
                        groupRoot.tooltipThumbnailHeight : 0
                    
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
                        
                        // In a vertical list (vertical panel) every instance spans the
                        // column, which is as wide as the widest thumbnail, and its own
                        // thumbnail is centered inside it (Layout.alignment in
                        // ToolTipInstance). Moving the delegate instead doesn't work:
                        // ListView keeps resetting x on the axis it doesn't lay out.
                        width: !groupRoot.showThumbnails ? groupRoot.tooltipInstanceMaximumWidth
                            : groupToolTipListView.orientation === ListView.Vertical ? groupToolTipListView.width
                            : toolTipDelegate.thumbnailWidthFor(model.Geometry)
                        windowGeometry: model.Geometry ?? Qt.rect(0, 0, 0, 0)
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
                        isWindowActive: model.IsActive !== undefined ? model.IsActive : false

                        submodelIndex: groupRoot.tasksModel.makeModelIndex(groupRoot.rootIndex.row, index)
                        tasksModel: groupRoot.tasksModel
                        toolTipDelegate: toolTipDelegate

                        mediaRegistry: groupRoot.mediaRegistry
                        // The shared panel (or nothing, if it's turned off) stands
                        // in for this window's own controls.
                        sharesProcess: groupRoot.sharedPids.indexOf(appPid) !== -1
                    }
                }
            }

            Loader {
                id: groupMediaBarLoader
                readonly property var controller: groupRoot.groupMediaController
                active: controller !== null
                visible: active
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(groupRoot.tooltipInstanceMaximumWidth, scrollView.Layout.preferredWidth)
                Layout.bottomMargin: groupRoot.showThumbnails ? 0 : Kirigami.Units.smallSpacing

                sourceComponent: ToolTipMediaBar {
                    mediaController: groupMediaBarLoader.controller
                    onActivateRequested: groupRoot.activateMediaWindow(groupMediaBarLoader.controller)
                }
            }

            ToolTipStreamListLoader {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: groupMediaBarLoader.Layout.preferredWidth
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                mediaRegistry: groupRoot.mediaRegistry
                streams: groupRoot.groupMediaController ? groupRoot.groupMediaController.audioStreams : []
                playerPlaying: groupRoot.groupMediaController !== null && !!groupRoot.groupMediaController.playerData
                    && groupRoot.groupMediaController.playerData.playbackStatus === Mpris.PlaybackStatus.Playing
                onStreamActivated: {
                    if (groupRoot.parentTask) {
                        groupRoot.parentTask.closeTooltip();
                        if (groupRoot.parentTask.tasksRoot) {
                            groupRoot.parentTask.tasksRoot.cancelHighlightWindows();
                        }
                    }
                }
            }
        }
    }
}
}
