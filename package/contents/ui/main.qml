/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2025 SushiTrash <namanrajhans@gmail.com>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2023-2024 Niccolò Venerandi <niccolo@venerandi.com>
    SPDX-FileCopyrightText: 2024 David Edmundson <kde@davidedmundson.co.uk>
    SPDX-FileCopyrightText: 2024 David Redondo <kde@david-redondo.de>
    SPDX-FileCopyrightText: 2024 Ismael Asensio <isma.af@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Bharadwaj Raju <bharadwaj.raju777@protonmail.com>
    SPDX-FileCopyrightText: 2023 Nicolas Fella <nicolas.fella@gmx.de>
    SPDX-FileCopyrightText: 2023 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2023 Taro Tanaka <mkrmdk@gmail.com>
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.ksvg as KSvg
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

import org.kde.plasma.workspace.trianglemousefilter

import org.kde.taskmanager as TaskManager
// import org.kde.plasma.private.taskmanager as TaskManagerApplet
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kitemmodels as KItemModels

import "code/layoutmetrics.js" as LayoutMetrics
import "code/tools.js" as TaskTools
import "code/FloatingLogic.js" as FloatingLogic

PlasmoidItem {
    id: tasks

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var config: Plasmoid.configuration
    readonly property int location: Plasmoid.location
    readonly property var containment: Plasmoid.containment

    rotation: tasks.config.reverseMode && tasks.vertical ? 180 : 0

    // Prevent shrinking to zero during startup before the tasks model is fully initialized.
    // Otherwise, in Wayland with "Fit Content" panel, the panel shrinks to zero size
    // and becomes invisible until edit mode is entered.
    readonly property bool shouldShrinkToZero: !tasks._initialStartup && !!tasks.effectiveTasksModel && tasks.effectiveTasksModel.count === 0
    readonly property int effectiveLocation: FloatingLogic.getEffectiveLocation(tasks.location, tasks.config, PlasmaCore.Types)

    readonly property bool vertical: {
        if (effectiveLocation === PlasmaCore.Types.LeftEdge || effectiveLocation === PlasmaCore.Types.RightEdge) {
            return true;
        }
        if (effectiveLocation === PlasmaCore.Types.TopEdge || effectiveLocation === PlasmaCore.Types.BottomEdge) {
            return false;
        }
        return Plasmoid.formFactor === PlasmaCore.Types.Vertical;
    }
    readonly property bool iconsOnly: tasks.config.iconOnly
    property bool showBadges: tasks.config.showBadges

    property alias globalVolumeOverlay: globalVolumeOverlayLoader
    property Item dropIndicator: dropIndicatorRect
    property int dropIndex: -1
    property Item dragSource: null
    property bool dragEndedOutsidePanel: false

    property bool _isApplyingConfig: false
    property bool _initialStartup: true
    property bool _isDestroying: false

    Timer {
        id: startupTimer
        interval: 1500
        repeat: false
        onTriggered: {
            tasks._initialStartup = false;
            tasks.applyModelConfiguration();
        }
    }

    Connections {
        target: tasks.config
        function onShowBadgesChanged() {
            tasks.showBadges = tasks.config.showBadges;
        }

        function onShowOnlyCurrentDesktopChanged() {
            modelUpdateTimer.restart();
            tasks.filteredTasksModel.invalidateFilter();
        }
        function onShowOnlyCurrentScreenChanged() {
            modelUpdateTimer.restart();
            tasks.filteredTasksModel.invalidateFilter();
        }
        function onShowOnlyCurrentActivityChanged() {
            modelUpdateTimer.restart();
            tasks.filteredTasksModel.invalidateFilter();
        }
        function onReverseFiltersChanged() {
            modelUpdateTimer.restart();
            tasks.filteredTasksModel.invalidateFilter();
        }

        function onSortingStrategyChanged() {
            modelUpdateTimer.restart();
        }
        function onGroupingStrategyChanged() {
            modelUpdateTimer.restart();
        }

        function onMinimizedFilterChanged() {
            tasks.filteredTasksModel.invalidateFilter();
        }

        function onLaunchersChanged(): void {
            if (tasks.tasksModel && !tasks._isInternalLauncherUpdate) {
                tasks.tasksModel.launcherList = tasks.config.launchers;
                tasks.tasksModel.syncLaunchers();
            }
        }
    }

    property Task toolTipOpenedByClick
    property Task toolTipAreaItem

    property Task currentHoveredTask: null
    property Task instantHoveredTask: null
    property int instantHoveredIndex: instantHoveredTask ? instantHoveredTask.index : -1
    property real instantHoveredFraction: 0.5
    property bool isTooltipHovered: false

    // PERSIST PARENT FOR FADE-OUT ANIMATION
    property Item lastTooltipParent: null

    property bool tooltipAnimationEnabled: true

    function hideTooltipImmediately() {
        tasks.tooltipAnimationEnabled = false;
        tasks.currentHoveredTask = null;
        tasks.toolTipOpenedByClick = null;
        Qt.callLater(() => {
            if (tasks) {
                tasks.tooltipAnimationEnabled = true;
            }
        });
    }

    // Key: WinId, Value: { result: ItemGrabResult, stamp: ms }
    // Capped at THUMBNAIL_CACHE_MAX entries; entries older than THUMBNAIL_CACHE_TTL_MS are treated as stale.
    property var thumbnailCache: ({})
    readonly property int thumbnailCacheMax: 48
    readonly property int thumbnailCacheTtlMs: 120000

    function cacheThumbnail(winId, result) {
        const now = Date.now();
        // Evict entries older than TTL first, then enforce cap by dropping oldest
        const keys = Object.keys(thumbnailCache);
        for (const k of keys) {
            if (now - thumbnailCache[k].stamp > thumbnailCacheTtlMs) {
                delete thumbnailCache[k];
            }
        }
        const remaining = Object.keys(thumbnailCache);
        if (remaining.length >= thumbnailCacheMax) {
            // Drop the oldest entry
            let oldest = null, oldestStamp = Infinity;
            for (const k of remaining) {
                if (thumbnailCache[k].stamp < oldestStamp) {
                    oldestStamp = thumbnailCache[k].stamp;
                    oldest = k;
                }
            }
            if (oldest !== null) delete thumbnailCache[oldest];
        }
        thumbnailCache[winId] = { result: result, stamp: now };
        thumbnailCacheChanged(); // notify bindings
    }

    onCurrentHoveredTaskChanged: {
        if (currentHoveredTask) {
            lastTooltipParent = currentHoveredTask.tooltipAnchor;
        }
    }

    Timer {
        id: tooltipCloseTimer
        interval: 500
        running: !tasks.isTooltipHovered && tasks.currentHoveredTask !== null && !tasks.currentHoveredTask.containsMouse && tasks.currentHoveredTask !== mouseHandler.hoveredItem
        onTriggered: {
            if (!tasks.isTooltipHovered && (tasks.currentHoveredTask && !tasks.currentHoveredTask.containsMouse && tasks.currentHoveredTask !== mouseHandler.hoveredItem)) {
                tasks.currentHoveredTask = null;
            }
        }
    }

    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")
    readonly property Component audioStreamManagerComponent: Qt.createComponent("AudioStreamManager.qml")


    property alias taskList: taskListView
    property alias effectWatcher: windowViewEffectWatcher
    property alias audioStreamManager: audioStreamManagerLoader
    property alias mpris2Source: mpris2SourceModel
    property alias dragHelper: dragHelper
    property alias taskFrame: taskFrame
    property alias filteredTasksModel: internalFilteredTasksModel
    property alias busyIndicator: busyIndicator
    property alias virtualDesktopInfo: virtualDesktopInfo
    property alias mouseHandler: mouseHandler
    FancyTasksExplosion {
        id: explosionManager
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    Layout.fillWidth: vertical ? true : tasks.config.fill
    Layout.fillHeight: !vertical ? true : tasks.config.fill
    Layout.minimumWidth: {
        if (shouldShrinkToZero)
            return Kirigami.Units.gridUnit;
        return vertical ? 0 : LayoutMetrics.preferredMinWidth();
    }
    Layout.minimumHeight: {
        if (shouldShrinkToZero)
            return Kirigami.Units.gridUnit;
        return !vertical ? 0 : LayoutMetrics.preferredMinHeight();
    }
    Layout.preferredWidth: {
        if (shouldShrinkToZero)
            return 0.01;
        if (tasks.location === PlasmaCore.Types.Floating)
            return -1; // Let Plasma manage and persist manual resizes
        if (vertical)
            return Kirigami.Units.gridUnit * (iconsOnly ? 2.5 : 10);
        return taskListView.Layout.maximumWidth;
    }
    Layout.preferredHeight: {
        if (shouldShrinkToZero)
            return 0.01;
        if (tasks.location === PlasmaCore.Types.Floating)
            return -1; // Let Plasma manage and persist manual resizes
        if (vertical)
            return taskListView.Layout.maximumHeight;
        return Kirigami.Units.gridUnit * 2;
    }

    signal requestLayout
    signal windowsHovered(var winIds, bool hovered)
    function activateWindowView(winIds) {
        if (!windowViewEffectWatcher.registered)
            return;
        cancelHighlightWindows();
        return DBus.SessionBus.asyncCall({
            service: "org.kde.KWin.Effect.WindowView1",
            path: "/org/kde/KWin/Effect/WindowView1",
            iface: "org.kde.KWin.Effect.WindowView1",
            member: "activate",
            arguments: [winIds.map(s => String(s))],
            signature: "(as)"
        });
    }

    onWindowsHovered: (winIds, hovered) => {
        if (!tasks.config.highlightWindows || !tasks.config.enableToolTips)
            return;
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin.HighlightWindow",
            path: "/org/kde/KWin/HighlightWindow",
            iface: "org.kde.KWin.HighlightWindow",
            member: "highlightWindows",
            arguments: [hovered ? winIds : []],
            signature: "(as)"
        });
    }

    function cancelHighlightWindows(): DBus.DBusPendingReply {
        return DBus.SessionBus.asyncCall({
            service: "org.kde.KWin.HighlightWindow",
            path: "/org/kde/KWin/HighlightWindow",
            iface: "org.kde.KWin.HighlightWindow",
            member: "highlightWindows",
            arguments: [[]],
            signature: "(as)"
        });
    }

    onDragSourceChanged: {
        if (tasks.dragSource === null && tasks.tasksModel)
            tasks.tasksModel.syncLaunchers();
    }

    property bool _isInternalLauncherUpdate: false
    property bool _isPublishingGeometries: false

    function publishIconGeometries(taskItems: var): void {
        if (_isPublishingGeometries || tasks._isDestroying)
            return;
        if (TaskTools.taskManagerInstanceCount >= 2)
            return;

        _isPublishingGeometries = true;
        try {
            for (let i = 0; i < taskItems.length; ++i) {
                const task = taskItems[i];
                if (task.getGlobalRect && task.model && !task.model.IsLauncher && !task.model.IsStartup && tasks.tasksModel) {
                    const idx = task.modelIndex();
                    if (idx && idx.valid) {
                        tasks.tasksModel.requestPublishDelegateGeometry(idx, task.getGlobalRect(), task);
                    }
                }
            }
        } finally {
            _isPublishingGeometries = false;
        }
    }

    readonly property TaskManager.TasksModel tasksModel: internalTasksModel
    TaskManager.TasksModel {
        id: internalTasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: tasks.containment.screenGeometry
        activity: activityInfo.currentActivity

        onLauncherListChanged: {
            if (!tasks._isApplyingConfig) {
                tasks._isInternalLauncherUpdate = true;
                tasks.config.launchers = launcherList;
                // Defer reset to ensure the config change signal has finished propagating
                Qt.callLater(() => {
                    if (tasks)
                        tasks._isInternalLauncherUpdate = false;
                });
            }
        }
        onGroupingAppIdBlacklistChanged: {
            if (!tasks._isApplyingConfig) {
                tasks.config.groupingAppIdBlacklist = groupingAppIdBlacklist;
            }
        }
        onGroupingLauncherUrlBlacklistChanged: {
            if (!tasks._isApplyingConfig) {
                tasks.config.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
            }
        }

        Component.onCompleted: {
            launcherList = tasks.config.launchers;
            groupingAppIdBlacklist = tasks.config.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = tasks.config.groupingLauncherUrlBlacklist;
            tasks.applyModelConfiguration();
            startupTimer.start();
        }
    }

    KItemModels.KSortFilterProxyModel {
        id: internalFilteredTasksModel
        sourceModel: internalTasksModel
        filterRowCallback: (source_row, source_parent) => {
            const idx = internalTasksModel.index(source_row, 0, source_parent);

            // Minimized Filter
            const isMinimized = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized) === true;
            if (tasks.config.minimizedFilter === 1) { // Only Minimized
                if (!isMinimized)
                    return false;
            } else if (tasks.config.minimizedFilter === 2) { // Only Not Minimized
                if (isMinimized)
                    return false;
            }

            // Reverse Filters (hide instead of show)
            if (tasks.config.reverseFilters) {
                // Screen Filter: hide tasks on the current screen
                if (tasks.config.showOnlyCurrentScreen) {
                    const taskScreen = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.ScreenGeometry);
                    const currentScreen = tasks.tasksModel.screenGeometry;
                    if (taskScreen && taskScreen.x === currentScreen.x && taskScreen.y === currentScreen.y && taskScreen.width === currentScreen.width && taskScreen.height === currentScreen.height) {
                        return false;
                    }
                }

                // Desktop Filter: hide tasks on the current virtual desktop
                if (tasks.config.showOnlyCurrentDesktop) {
                    const isOnAllDesktops = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops) === true;
                    const demandsAttention = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.IsDemandingAttention) === true;
                    if (!isOnAllDesktops && !demandsAttention) {
                        const virtualDesktops = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.VirtualDesktops);
                        const currentDesktop = tasks.tasksModel.virtualDesktop;
                        if (Array.isArray(virtualDesktops) && virtualDesktops.indexOf(currentDesktop) !== -1) {
                            return false;
                        }
                    }
                }

                // Activity Filter: hide tasks on the current activity
                if (tasks.config.showOnlyCurrentActivity) {
                    const demandsAttention = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.IsDemandingAttention) === true;
                    if (!demandsAttention) {
                        const activities = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.Activities);
                        const currentActivity = tasks.tasksModel.activity;
                        if (Array.isArray(activities) && activities.length > 0) {
                            const isOnAllActivities = activities.indexOf("00000000-0000-0000-0000-000000000000") !== -1;
                            if (!isOnAllActivities && activities.indexOf(currentActivity) !== -1) {
                                return false;
                            }
                        }
                    }
                }
            }

            return true;
        }
    }

    readonly property var effectiveTasksModel: (tasks.config.minimizedFilter === 0 && !tasks.config.reverseFilters) ? internalTasksModel : internalFilteredTasksModel

    Timer {
        id: modelUpdateTimer
        interval: 100
        repeat: false
        onTriggered: tasks.applyModelConfiguration()
    }

    function applyModelConfiguration() {
        if (!tasks.tasksModel)
            return;

        tasks._isApplyingConfig = true;

        tasks.tasksModel.filterByVirtualDesktop = tasks.config.showOnlyCurrentDesktop && !tasks.config.reverseFilters;
        tasks.tasksModel.filterByScreen = tasks.config.showOnlyCurrentScreen && !tasks.config.reverseFilters;
        tasks.tasksModel.filterByActivity = tasks.config.showOnlyCurrentActivity && !tasks.config.reverseFilters;
        // tasks.tasksModel.filterNotMinimized = tasks.config.showOnlyMinimized;
        // The above is now handled by filteredTasksModel proxy to prevent crashes.
        tasks.tasksModel.filterNotMinimized = false;

        tasks.tasksModel.hideActivatedLaunchers = tasks.iconsOnly || tasks.tasksModel.launchInPlace;
        tasks.tasksModel.sortMode = tasks.sortModeEnumValue(tasks.config.sortingStrategy);
        tasks.tasksModel.launchInPlace = (tasks.config.sortingStrategy === 1 || tasks.config.sortingStrategy === 0);
        tasks.tasksModel.separateLaunchers = (tasks.config.sortingStrategy !== 1);

        tasks.tasksModel.groupMode = tasks.groupModeEnumValue(tasks.config.groupingStrategy);
        tasks.tasksModel.groupInline = !tasks.config.groupPopups;
        tasks.tasksModel.groupingWindowTasksThreshold = 0;

        internalFilteredTasksModel.invalidateFilter();

        tasks._isApplyingConfig = false;
    }

    function sortModeEnumValue(index) {
        switch (Number(index)) {
        case 0:
            return TaskManager.TasksModel.SortDisabled;
        case 1:
            return TaskManager.TasksModel.SortManual;
        case 2:
            return TaskManager.TasksModel.SortAlpha;
        case 3:
            return TaskManager.TasksModel.SortVirtualDesktop;
        case 4:
            return TaskManager.TasksModel.SortActivity;
        case 5:
            return TaskManager.TasksModel.SortWindowPositionHorizontal;
        default:
            return TaskManager.TasksModel.SortDisabled;
        }
    }

    function groupModeEnumValue(index) {
        switch (Number(index)) {
        case 0:
            return TaskManager.TasksModel.GroupDisabled;
        case 1:
            return TaskManager.TasksModel.GroupApplications;
        default:
            return TaskManager.TasksModel.GroupApplications;
        }
    }

    DBus.DBusServiceWatcher {
        id: windowViewEffectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    readonly property Component taskInitComponent: Component {
        Item {}
    }

    Connections {
        target: Plasmoid
        function onLocationChanged(): void {
            if (TaskTools.taskManagerInstanceCount >= 2)
                return;
            iconGeometryTimer.start();
        }
    }

    Connections {
        target: tasks.containment
        function onScreenGeometryChanged(): void {
            iconGeometryTimer.start();
        }
    }

    Mpris.Mpris2Model {
        id: mpris2SourceModel
    }

    function handleItemRemoval(taskItem) {
        if (!taskItem || !taskItem.model)
            return;

        // Do not spawn ghosts for Launchers or Startups, as their removal is typically
        // a model transition (e.g. Launcher -> Startup -> Window), not a real closure.
        if (taskItem.model.IsLauncher || taskItem.model.IsStartup)
            return;

        if (tasks.config.smokeExplosionOnClose && tasks.config.iconOnly === 1) {
            if (taskItem.wasMiddleClicked) {
                explosionManager.spawn(tasks, taskItem, true);
            }
        }
    }

    function addLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable && tasks.tasksModel)
            tasks.tasksModel.requestAddLauncher(url);
    }
    function removeLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable && tasks.tasksModel)
            tasks.tasksModel.requestRemoveLauncher(url);
    }
    function adjustGlobalVolume(increment: int) {
        const audioManager = audioStreamManagerLoader.item;
        const pSink = "preferredSink";
        const pAdj = "adjustObjectVolume";
        if (!audioManager || !audioManager[pSink])
            return;

        const lastResult = audioManager[pAdj](audioManager[pSink], increment);
        if (lastResult && globalVolumeOverlayLoader.item) {
            const pVol = "volume";
            const pMute = "muted";
            const pShow = "show";
            globalVolumeOverlayLoader.item[pVol] = lastResult.volume;
            globalVolumeOverlayLoader.item[pMute] = lastResult.muted;
            globalVolumeOverlayLoader.item[pShow]();
        }
    }
    function createContextMenu(rootTask, modelIndex, args = {}) {
        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            mpris2Source: mpris2SourceModel,
            tasksModel: tasks.tasksModel,
            virtualDesktopInfo,
            activityInfo,
            tasksRoot: tasks
        });
        return tasks.contextMenuComponent.createObject(rootTask, initialArgs);
    }
    function shouldBeMirrored(reverseMode, layoutDirection, vertical): bool {
        if (vertical)
            return layoutDirection === Qt.RightToLeft;
        if (layoutDirection === Qt.LeftToRight)
            return reverseMode;
        return !reverseMode;
    }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: rootHoverHandler
        }

        TaskManager.VirtualDesktopInfo {
            id: virtualDesktopInfo
        }
        TaskManager.ActivityInfo {
            id: activityInfo
            readonly property string nullUuid: "00000000-0000-0000-0000-000000000000"
        }

        Loader {
            id: audioStreamManagerLoader
            sourceComponent: tasks.audioStreamManagerComponent
            active: tasks.audioStreamManagerComponent.status === Component.Ready
        }

        Loader {
            id: globalVolumeOverlayLoader
            anchors.fill: parent
            source: "TaskVolumeOverlay.qml"
        }

        Timer {
            id: iconGeometryTimer
            interval: 500
            repeat: false
            onTriggered: tasks.publishIconGeometries(taskListView.children)
        }

        Timer {
            id: startupSortFixTimer
            interval: 2000
            running: true
            repeat: false
            onTriggered: {
                tasks.tasksModel.launcherList = tasks.config.launchers;
                tasks.tasksModel.syncLaunchers();
            }
        }

        Binding {
            target: Plasmoid
            property: "status"
            value: (tasks.tasksModel && tasks.tasksModel.anyTaskDemandsAttention && tasks.config.unhideOnAttention ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus)
            restoreMode: Binding.RestoreBinding
        }

        Component {
            id: busyIndicator
            PlasmaComponents3.BusyIndicator {
                anchors.fill: parent
                running: true
            }
        }

        Item {
            id: dragHelper
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction

            // Holds the launcher URL while waiting for the unpin animation to finish.
            property string pendingUnpinUrl: ""

            // Delays the actual model removal so the explosion animation has time to play.
            Timer {
                id: unpinDelayTimer
                interval: 300
                repeat: false
                onTriggered: {
                    if (dragHelper.pendingUnpinUrl !== "") {
                        tasks.removeLauncher(dragHelper.pendingUnpinUrl);
                        dragHelper.pendingUnpinUrl = "";
                    }
                }
            }

            Drag.onDragFinished: dropAction => {
                // If a pure launcher (no running windows) is dragged outside the panel,
                // treat it as an "unpin" gesture.
                // We check both Qt.IgnoreAction (nothing accepted the drop) AND
                // dragEndedOutsidePanel (set by position check in Task.qml's DragHandler),
                // because Plasma desktop or other shell components may accept the drag
                // and return a non-IgnoreAction even when the user clearly dropped outside.
                const source = tasks.dragSource;
                let pModel = "model";
                let pWinIdList = "winIdList";
                if (tasks.config.unpinByDrag && (dropAction === Qt.IgnoreAction || tasks.dragEndedOutsidePanel) && source && source[pModel] && source[pModel].IsLauncher && source[pWinIdList].length === 0) {
                    if (tasks.config.unpinByDragExplosion && tasks.config.iconOnly === 1) {
                        explosionManager.spawn(tasks, source, true);
                        // Delay removal so the explosion animation plays before the item disappears.
                        dragHelper.pendingUnpinUrl = source[pModel].LauncherUrlWithoutIcon.toString();
                        unpinDelayTimer.start();
                    } else {
                        tasks.removeLauncher(source[pModel].LauncherUrlWithoutIcon);
                    }
                }
                tasks.dragEndedOutsidePanel = false;
                tasks.dragSource = null;
                tasks.dropIndicator.visible = false;
            }
        }

        Rectangle {
            id: dropIndicatorRect
            color: Kirigami.Theme.highlightColor
            width: tasks.vertical ? parent.width : 2
            height: tasks.vertical ? 2 : parent.height
            visible: false
            z: 999

            Behavior on x {
                enabled: tasks.dropIndicator.visible
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on y {
                enabled: tasks.dropIndicator.visible
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutQuad
                }
            }
        }

        KSvg.FrameSvgItem {
            id: taskFrame
            visible: false
            imagePath: "widgets/tasks"
            prefix: TaskTools.taskPrefix("normal", tasks.effectiveLocation)
        }

        MouseHandler {
            id: mouseHandler
            anchors.fill: parent
            target: taskList
            tasks: tasks
            tasksModel: tasks.tasksModel
            proxyModel: internalFilteredTasksModel
            onUrlsDropped: urls => {
                const isApp = url => {
                    let s = url.toString();
                    return s.endsWith(".desktop") || s.startsWith("applications:") || s.startsWith("application://");
                };
                const createLaunchers = urls.every(isApp);
                if (createLaunchers) {
                    urls.forEach(item => tasks.addLauncher(item));
                    return;
                }
                if (!hoveredItem)
                    return;
                const task = hoveredItem as Task;
                if (tasks.tasksModel)
                    tasks.tasksModel.requestOpenUrls(task.modelIndex(), urls);
            }
        }

        TriangleMouseFilter {
            id: tmf
            filterTimeOut: 300
            active: tasks.currentHoveredTask !== null
            blockFirstEnter: false
            edge: {
                switch (tasks.location) {
                case PlasmaCore.Types.BottomEdge:
                    return Qt.TopEdge;
                case PlasmaCore.Types.TopEdge:
                    return Qt.BottomEdge;
                case PlasmaCore.Types.LeftEdge:
                    return Qt.RightEdge;
                case PlasmaCore.Types.RightEdge:
                    return Qt.LeftEdge;
                default:
                    return Qt.TopEdge;
                }
            }
            readonly property bool centerAlign: tasks.iconsOnly && tasks.config.fill && tasks.config.fillAlignment === 1
            LayoutMirroring.enabled: tasks.shouldBeMirrored(tasks.config.reverseMode, Qt.locale().textDirection, tasks.vertical)
            x: centerAlign && !tasks.vertical ? Math.round((parent.width - width) / 2) : 0
            y: centerAlign && tasks.vertical ? Math.round((parent.height - height) / 2) : 0
            height: taskListView.height
            width: taskListView.width

            TaskList {
                id: taskListView
                tasks: tasks
                tasksModel: tasks.effectiveTasksModel
                LayoutMirroring.enabled: tasks.shouldBeMirrored(tasks.config.reverseMode, Qt.locale().textDirection, tasks.vertical)
                anchors {
                    left: parent.left
                    top: parent.top
                }
                readonly property real widthOccupation: internalTaskRepeater.count / columns
                readonly property real heightOccupation: internalTaskRepeater.count / rows
                Layout.maximumWidth: {
                    if (widthOccupation <= 0)
                        return 0;
                    if (tasks.iconsOnly) {
                        return Math.round((internalTaskRepeater.count * LayoutMetrics.preferredMaxWidth()) / widthOccupation);
                    }
                    return Math.round(children.reduce((acc, child) => (child && child.visible && isFinite(child.Layout.maximumWidth)) ? acc + child.Layout.maximumWidth : acc, 0) / widthOccupation);
                }
                Layout.maximumHeight: {
                    if (heightOccupation <= 0)
                        return 0;
                    if (tasks.iconsOnly) {
                        return Math.round((internalTaskRepeater.count * LayoutMetrics.preferredMaxHeight()) / heightOccupation);
                    }
                    return Math.round(children.reduce((acc, child) => (child && child.visible && isFinite(child.Layout.maximumHeight)) ? acc + child.Layout.maximumHeight : acc, 0) / heightOccupation);
                }
                width: tasks.shouldShrinkToZero ? 0 : (tasks.vertical ? tasks.width * Math.min(1, widthOccupation) : Math.min(tasks.width, Layout.maximumWidth))
                height: tasks.shouldShrinkToZero ? 0 : (tasks.vertical ? Math.min(tasks.height, Layout.maximumHeight) : tasks.height * Math.min(1, heightOccupation))
                flow: tasks.vertical ? (tasks.config.forceStripes ? Grid.LeftToRight : Grid.TopToBottom) : (tasks.config.forceStripes ? Grid.TopToBottom : Grid.LeftToRight)
                onAnimatingChanged: if (!animating)
                    iconGeometryTimer.restart()

                Repeater {
                    id: internalTaskRepeater
                    model: tasks.effectiveTasksModel
                    delegate: Task {
                        tasksRoot: tasks
                    }
                }

                Connections {
                    target: tasks.effectiveTasksModel
                    function onRowsAboutToBeRemoved(parent, first, last) {
                        for (let i = first; i <= last; ++i) {
                            tasks.handleItemRemoval(internalTaskRepeater.itemAt(i));
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        TaskTools.taskManagerInstanceCount += 1;
        requestLayout.connect(iconGeometryTimer.restart);
    }
    Component.onDestruction: TaskTools.taskManagerInstanceCount -= 1

    PlasmaCore.Dialog {
        id: windowTooltipDialog

        location: tasks.effectiveLocation
        type: PlasmaCore.Dialog.Tooltip

        backgroundHints: PlasmaCore.Types.NoBackground
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WA_TranslucentBackground | Qt.BypassWindowManagerHint
        hideOnWindowDeactivate: false

        readonly property bool shouldShow: tasks.config.enableToolTips && tasks.currentHoveredTask !== null && !tasks.currentHoveredTask.inPopup
        visible: (shouldShow && toolTipInstance.implicitWidth > 0) || winContainer.opacity > 0
        visualParent: tasks.currentHoveredTask ? tasks.currentHoveredTask.tooltipAnchor : tasks.lastTooltipParent

        mainItem: Item {
            id: winContainer

            readonly property real targetWidth: toolTipInstance.implicitWidth + winBgFrame.margins.left + winBgFrame.margins.right
            readonly property real targetHeight: toolTipInstance.implicitHeight + winBgFrame.margins.top + winBgFrame.margins.bottom

            readonly property bool isTop: tasks.effectiveLocation === PlasmaCore.Types.TopEdge
            readonly property bool isLeft: tasks.effectiveLocation === PlasmaCore.Types.LeftEdge
            readonly property bool isRight: tasks.effectiveLocation === PlasmaCore.Types.RightEdge
            readonly property bool isBottom: !isLeft && !isRight && !isTop

            // Shadow needs transparent space on free sides to prevent clipping.
            readonly property int shadowPadding: 16
            // 8px gap allows an 8px radius shadow to render fully on the panel side
            readonly property int gapSize: 8

            readonly property int marginTop: isTop ? gapSize : shadowPadding
            readonly property int marginBottom: isBottom ? gapSize : shadowPadding
            readonly property int marginLeft: isLeft ? gapSize : shadowPadding
            readonly property int marginRight: isRight ? gapSize : shadowPadding

            // Cache the last valid dimensions when the tooltip was loaded.
            // When toolTipInstance.implicitWidth drops to 0 during closure or reload,
            // we use the cached dimensions to prevent the dialog window from
            // instantly shrinking to borders (margins) size.
            property real lastWidth: 0
            property real lastHeight: 0

            onTargetWidthChanged: {
                if (toolTipInstance.implicitWidth > 0) {
                    lastWidth = targetWidth;
                }
            }
            onTargetHeightChanged: {
                if (toolTipInstance.implicitHeight > 0) {
                    lastHeight = targetHeight;
                }
            }

            implicitWidth: (toolTipInstance.implicitWidth > 0 ? targetWidth : lastWidth) + marginLeft + marginRight
            implicitHeight: (toolTipInstance.implicitHeight > 0 ? targetHeight : lastHeight) + marginTop + marginBottom
            width: implicitWidth
            height: implicitHeight

            Behavior on implicitWidth {
                enabled: tasks.tooltipAnimationEnabled && windowTooltipDialog.shouldShow
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on implicitHeight {
                enabled: tasks.tooltipAnimationEnabled && windowTooltipDialog.shouldShow
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            opacity: windowTooltipDialog.shouldShow ? 1 : 0
            Behavior on opacity {
                enabled: tasks.tooltipAnimationEnabled
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }

            Kirigami.ShadowedRectangle {
                id: winBgFrame

                Kirigami.Theme.colorSet: Kirigami.Theme.Tooltip
                Kirigami.Theme.inherit: false

                width: winContainer.targetWidth
                height: winContainer.targetHeight

                color: Kirigami.Theme.backgroundColor
                radius: 4

                shadow.size: 16
                shadow.color: Qt.rgba(0, 0, 0, 0.6)
                shadow.xOffset: 0
                shadow.yOffset: 0

                anchors.fill: parent
                anchors.topMargin: winContainer.marginTop
                anchors.bottomMargin: winContainer.marginBottom
                anchors.leftMargin: winContainer.marginLeft
                anchors.rightMargin: winContainer.marginRight

                readonly property int tooltipFramePadding: 4
                readonly property var margins: ({
                        left: tooltipFramePadding,
                        top: tooltipFramePadding,
                        right: tooltipFramePadding,
                        bottom: tooltipFramePadding
                    })

                ToolTipDelegate {
                    id: toolTipInstance
                    clip: true
                    anchors.fill: parent
                    anchors.margins: winBgFrame.tooltipFramePadding

                    onContainsMouseChanged: tasks.isTooltipHovered = containsMouse

                    parentTask: tasks.currentHoveredTask
                    tasksModel: tasks.tasksModel
                    mpris2Model: mpris2Source
                    audioStreamManager: tasks.audioStreamManager

                    readonly property var taskModel: parentTask ? parentTask.model : null

                    // parentTask.index is a row in the filtered proxy; map it to the source model,
                    // otherwise lookups below read the wrong task whenever filters are active
                    rootIndex: (parentTask && parentTask.modelIndex()) || internalTasksModel.makeModelIndex(parentTask ? parentTask.index : 0, -1)
                    appName: taskModel ? taskModel.AppName : ""
                    pidParent: taskModel ? taskModel.AppPid : 0
                    windows: taskModel ? taskModel.WinIdList : []
                    isGroup: taskModel ? taskModel.IsGroupParent : false
                    icon: taskModel ? taskModel.decoration : ""
                    launcherUrl: taskModel ? taskModel.LauncherUrlWithoutIcon : ""
                    isLauncher: taskModel ? taskModel.IsLauncher : false
                    isMinimized: taskModel ? taskModel.IsMinimized : false
                    display: taskModel ? taskModel.display : ""
                    genericName: taskModel ? taskModel.GenericName : ""
                    virtualDesktops: taskModel ? taskModel.VirtualDesktops : []
                    isOnAllVirtualDesktops: taskModel ? taskModel.IsOnAllVirtualDesktops : false
                    activities: taskModel ? taskModel.Activities : []

                    isPlayingAudio: taskModel ? (taskModel.IsPlayingAudio === true) : false
                    isMuted: taskModel ? (taskModel.IsMuted === true) : false

                    forceTextMode: tasks.toolTipOpenedByClick !== null && tasks.config.groupedTaskVisualization !== 1
                }
            }
        }
    }
}
