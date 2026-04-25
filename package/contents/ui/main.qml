/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
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

    rotation: Plasmoid.configuration.reverseMode && tasks.vertical ? 180 : 0

    readonly property bool shouldShrinkToZero: !!tasks.tasksModel && tasks.tasksModel.count === 0
    readonly property int effectiveLocation: FloatingLogic.getEffectiveLocation(Plasmoid.location, Plasmoid.configuration, PlasmaCore.Types)

    readonly property bool vertical: {
        if (effectiveLocation === PlasmaCore.Types.LeftEdge || effectiveLocation === PlasmaCore.Types.RightEdge) {
            return true;
        }
        if (effectiveLocation === PlasmaCore.Types.TopEdge || effectiveLocation === PlasmaCore.Types.BottomEdge) {
            return false;
        }
        return Plasmoid.formFactor === PlasmaCore.Types.Vertical;
    }
    readonly property bool iconsOnly: Plasmoid.configuration.iconOnly
    property bool showBadges: Plasmoid.configuration.showBadges

    property Item dropIndicator: dropIndicator
    property int dropIndex: -1
    property Item dragSource: null

    property bool _isApplyingConfig: false
    property bool _initialStartup: true

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
        target: Plasmoid.configuration
        function onShowBadgesChanged() {
            tasks.showBadges = Plasmoid.configuration.showBadges;
        }

        function onShowOnlyCurrentDesktopChanged() {
            modelUpdateTimer.restart();
        }
        function onShowOnlyCurrentScreenChanged() {
            modelUpdateTimer.restart();
        }
        function onShowOnlyCurrentActivityChanged() {
            modelUpdateTimer.restart();
        }
        function onShowOnlyMinimizedChanged() {
            modelUpdateTimer.restart();
        }
        function onSortingStrategyChanged() {
            modelUpdateTimer.restart();
        }
        function onGroupingStrategyChanged() {
            modelUpdateTimer.restart();
        }
        function onGroupPopupsChanged() {
            modelUpdateTimer.restart();
        }
        function onOnlyGroupWhenFullChanged() {
            modelUpdateTimer.restart();
        }
    }

    property Task toolTipOpenedByClick
    property Task toolTipAreaItem

    property Task currentHoveredTask: null
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

    // Key: WinId, Value: ItemGrabResult
    property var thumbnailCache: ({})

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

    property bool needLayoutRefresh: false

    property alias taskList: taskList
    property alias effectWatcher: effectWatcher
    property alias audioStreamManager: audioStreamManager
    property alias mpris2Source: mpris2Source
    property alias dragHelper: dragHelper
    property alias taskFrame: taskFrame
    property alias filteredTasksModel: filteredTasksModel
    property alias busyIndicator: busyIndicator
    FancyTasksExplosion {
        id: explosionManager
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    Plasmoid.onUserConfiguringChanged: {
        if (Plasmoid.userConfiguring) {
            // No action needed for group dialog since it's removed
        }
    }

    Layout.fillWidth: vertical ? true : Plasmoid.configuration.fill
    Layout.fillHeight: !vertical ? true : Plasmoid.configuration.fill
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
        if (Plasmoid.location === PlasmaCore.Types.Floating)
            return -1; // Let Plasma manage and persist manual resizes
        if (vertical)
            return Kirigami.Units.gridUnit * (iconsOnly ? 2.5 : 10);
        return taskList.Layout.maximumWidth;
    }
    Layout.preferredHeight: {
        if (shouldShrinkToZero)
            return 0.01;
        if (Plasmoid.location === PlasmaCore.Types.Floating)
            return -1; // Let Plasma manage and persist manual resizes
        if (vertical)
            return taskList.Layout.maximumHeight;
        return Kirigami.Units.gridUnit * 2;
    }

    signal requestLayout
    signal windowsHovered(var winIds, bool hovered)
    function activateWindowView(winIds) {
        if (!effectWatcher.registered)
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
        if (!Plasmoid.configuration.highlightWindows)
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
        if (_isPublishingGeometries)
            return;
        if (TaskTools.taskManagerInstanceCount >= 2)
            return;

        _isPublishingGeometries = true;
        try {
            for (let i = 0; i < taskItems.length; ++i) {
                const task = taskItems[i];
                // Check if it's a Task delegate and has the method
                if (task.getGlobalRect && task.model && !task.model.IsLauncher && !task.model.IsStartup && tasks.tasksModel) {
                    tasks.tasksModel.requestPublishDelegateGeometry(task.modelIndex(), task.getGlobalRect(), task);
                }
            }
        } finally {
            _isPublishingGeometries = false;
        }
    }

    readonly property TaskManager.TasksModel tasksModel: TaskManager.TasksModel {
        id: tasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        onLauncherListChanged: {
            if (!tasks._isApplyingConfig) {
                tasks._isInternalLauncherUpdate = true;
                Plasmoid.configuration.launchers = launcherList;
                Plasmoid.configuration.writeConfig(); // Force save to disk for KCM sync
                // Defer reset to ensure the config change signal has finished propagating
                Qt.callLater(() => {
                    if (tasks)
                        tasks._isInternalLauncherUpdate = false;
                });
            }
        }
        onGroupingAppIdBlacklistChanged: {
            if (!tasks._isApplyingConfig) {
                Plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
            }
        }
        onGroupingLauncherUrlBlacklistChanged: {
            if (!tasks._isApplyingConfig) {
                Plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
            }
        }

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers;
            groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;
            tasks.applyModelConfiguration();
            startupTimer.start();
        }
    }

    KItemModels.KSortFilterProxyModel {
        id: filteredTasksModel
        sourceModel: tasksModel
        filterRowCallback: (source_row, source_parent) => {
            const idx = tasksModel.index(source_row, 0, source_parent);
            const isMinimized = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized) === true;

            if (Plasmoid.configuration.minimizedFilter === 1) { // Only Minimized
                return isMinimized;
            } else if (Plasmoid.configuration.minimizedFilter === 2) { // Only Not Minimized
                return !isMinimized;
            }

            return true;
        }
    }

    // Invalidate filter when config changes
    Connections {
        target: Plasmoid.configuration
        function onMinimizedFilterChanged() {
            filteredTasksModel.invalidateFilter();
        }
    }

    readonly property alias tasksModelAlias: tasksModel // keep compatibility if needed

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

        tasks.tasksModel.filterByVirtualDesktop = Plasmoid.configuration.showOnlyCurrentDesktop;
        tasks.tasksModel.filterByScreen = Plasmoid.configuration.showOnlyCurrentScreen;
        tasks.tasksModel.filterByActivity = Plasmoid.configuration.showOnlyCurrentActivity;
        // tasks.tasksModel.filterNotMinimized = Plasmoid.configuration.showOnlyMinimized;
        // The above is now handled by filteredTasksModel proxy to prevent crashes.
        tasks.tasksModel.filterNotMinimized = false;

        tasks.tasksModel.hideActivatedLaunchers = tasks.iconsOnly || tasks.tasksModel.launchInPlace;
        tasks.tasksModel.sortMode = tasks.sortModeEnumValue(Plasmoid.configuration.sortingStrategy);
        tasks.tasksModel.launchInPlace = (Plasmoid.configuration.sortingStrategy === 1);
        tasks.tasksModel.separateLaunchers = (Plasmoid.configuration.sortingStrategy === 0);

        tasks.tasksModel.groupMode = tasks.groupModeEnumValue(Plasmoid.configuration.groupingStrategy);
        tasks.tasksModel.groupInline = !Plasmoid.configuration.groupPopups && !tasks.iconsOnly;
        tasks.tasksModel.groupingWindowTasksThreshold = (Plasmoid.configuration.onlyGroupWhenFull && !tasks.iconsOnly ? LayoutMetrics.optimumCapacity(tasks.width, tasks.height) + 1 : -1);

        tasks._isApplyingConfig = false;
    }

    function sortModeEnumValue(index) {
        return (index === 1) ? TaskManager.TasksModel.SortManual : TaskManager.TasksModel.SortDisabled;
    }

    function groupModeEnumValue(index) {
        switch (index) {
        case 0:
            return TaskManager.TasksModel.GroupDisabled;
        case 1:
            return TaskManager.TasksModel.GroupApplications;
        default:
        }
    }

    DBus.DBusServiceWatcher {
        id: effectWatcher
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
        target: Plasmoid.containment
        function onScreenGeometryChanged(): void {
            iconGeometryTimer.start();
        }
    }

    Mpris.Mpris2Model {
        id: mpris2Source
    }

    function handleItemRemoval(taskItem) {
        if (Plasmoid.configuration.smokeExplosionOnClose && Plasmoid.configuration.iconOnly === 1) {
            explosionManager.spawn(tasks, taskItem, taskItem.wasMiddleClicked);
        }
    }

    function hasLauncher(url: url): bool {
        return tasks.tasksModel ? tasks.tasksModel.launcherPosition(url) !== -1 : false;
    }
    function addLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable && tasks.tasksModel)
            tasks.tasksModel.requestAddLauncher(url);
    }
    function removeLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable && tasks.tasksModel)
            tasks.tasksModel.requestRemoveLauncher(url);
    }
    function activateTaskAtIndex(index: var): void {
        if (typeof index !== "number")
            return;
        const task = taskRepeater.itemAt(index) as Task;
        if (task)
            TaskTools.activateTask(task.modelIndex(), task.model, null, task, Plasmoid, tasks, effectWatcher.registered);
    }
    function createContextMenu(rootTask, modelIndex, args = {}) {
        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            mpris2Source,
            tasksModel: tasks.tasksModel,
            virtualDesktopInfo,
            activityInfo
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
            id: audioStreamManager
            sourceComponent: tasks.audioStreamManagerComponent
            active: tasks.audioStreamManagerComponent.status === Component.Ready
        }

        Timer {
            id: iconGeometryTimer
            interval: 500
            repeat: false
            onTriggered: tasks.publishIconGeometries(taskList.children)
        }

        Timer {
            id: startupSortFixTimer
            interval: 2000
            running: true
            repeat: false
            onTriggered: {
                tasks.tasksModel.launcherList = Plasmoid.configuration.launchers;
                tasks.tasksModel.syncLaunchers();
            }
        }

        Binding {
            target: Plasmoid
            property: "status"
            value: (tasks.tasksModel && tasks.tasksModel.anyTaskDemandsAttention && Plasmoid.configuration.unhideOnAttention ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus)
            restoreMode: Binding.RestoreBinding
        }

        Connections {
            target: Plasmoid.configuration
            function onLaunchersChanged(): void {
                if (tasks.tasksModel && !tasks._isInternalLauncherUpdate) {
                    tasks.tasksModel.launcherList = Plasmoid.configuration.launchers;
                    tasks.tasksModel.syncLaunchers();
                }
            }
        }

        Component {
            id: busyIndicator
            PlasmaComponents3.BusyIndicator {}
        }

        Item {
            id: dragHelper
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
            Drag.onDragFinished: dropAction => {
                tasks.dragSource = null;
                tasks.dropIndicator.visible = false;
            }
        }

        Rectangle {
            id: dropIndicator
            color: Kirigami.Theme.highlightColor
            width: tasks.vertical ? parent.width : 2
            height: tasks.vertical ? 2 : parent.height
            visible: false
            z: 999

            Behavior on x {
                enabled: dropIndicator.visible
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on y {
                enabled: dropIndicator.visible
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
            proxyModel: filteredTasksModel
            onUrlsDropped: urls => {
                const isApp = (url) => {
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
                switch (Plasmoid.location) {
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
            readonly property bool centerAlign: tasks.iconsOnly && Plasmoid.configuration.fill && Plasmoid.configuration.fillAlignment === 1
            LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Qt.locale().textDirection, tasks.vertical)
            x: centerAlign && !tasks.vertical ? Math.round((parent.width - width) / 2) : 0
            y: centerAlign && tasks.vertical ? Math.round((parent.height - height) / 2) : 0
            height: taskList.childrenRect.height
            width: taskList.childrenRect.width

            TaskList {
                id: taskList
                tasks: tasks
                tasksModel: filteredTasksModel
                LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Qt.locale().textDirection, tasks.vertical)
                anchors {
                    left: parent.left
                    top: parent.top
                }
                readonly property real widthOccupation: taskRepeater.count / columns
                readonly property real heightOccupation: taskRepeater.count / rows
                Layout.maximumWidth: widthOccupation > 0 ? Math.round(children.reduce((acc, child) => isFinite(child.Layout.maximumWidth) ? acc + child.Layout.maximumWidth : acc, 0) / widthOccupation) : 0
                Layout.maximumHeight: heightOccupation > 0 ? Math.round(children.reduce((acc, child) => isFinite(child.Layout.maximumHeight) ? acc + child.Layout.maximumHeight : acc, 0) / heightOccupation) : 0
                width: tasks.shouldShrinkToZero ? 0 : (tasks.vertical ? tasks.width * Math.min(1, widthOccupation) : Math.min(tasks.width, Layout.maximumWidth))
                height: tasks.shouldShrinkToZero ? 0 : (tasks.vertical ? Math.min(tasks.height, Layout.maximumHeight) : tasks.height * Math.min(1, heightOccupation))
                flow: tasks.vertical ? (Plasmoid.configuration.forceStripes ? Grid.LeftToRight : Grid.TopToBottom) : (Plasmoid.configuration.forceStripes ? Grid.TopToBottom : Grid.LeftToRight)
                onAnimatingChanged: if (!animating) iconGeometryTimer.restart()

                Repeater {
                    id: taskRepeater
                    model: filteredTasksModel
                    delegate: Task {
                        tasksRoot: tasks
                    }
                    onItemRemoved: (index, item) => {
                        tasks.needLayoutRefresh = true;
                    }
                }

                Connections {
                    target: filteredTasksModel
                    function onRowsAboutToBeRemoved(parent, first, last) {
                        for (let i = first; i <= last; ++i) {
                            tasks.handleItemRemoval(taskRepeater.itemAt(i));
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

        readonly property bool shouldShow: tasks.currentHoveredTask !== null && !tasks.currentHoveredTask.inPopup
        visible: shouldShow || winContainer.opacity > 0
        visualParent: tasks.currentHoveredTask ? tasks.currentHoveredTask.tooltipAnchor : tasks.lastTooltipParent

        mainItem: Item {
            id: winContainer

            readonly property real targetWidth: toolTipInstance.implicitWidth + winBgFrame.margins.left + winBgFrame.margins.right
            readonly property real targetHeight: toolTipInstance.implicitHeight + winBgFrame.margins.top + winBgFrame.margins.bottom

            readonly property bool isBottom: tasks.effectiveLocation === PlasmaCore.Types.BottomEdge
            readonly property bool isTop: tasks.effectiveLocation === PlasmaCore.Types.TopEdge
            readonly property bool isLeft: tasks.effectiveLocation === PlasmaCore.Types.LeftEdge
            readonly property bool isRight: tasks.effectiveLocation === PlasmaCore.Types.RightEdge

            readonly property int gapSize: 2

            readonly property int marginTop: isTop ? gapSize : 0
            readonly property int marginBottom: isBottom ? gapSize : 0
            readonly property int marginLeft: isLeft ? gapSize : 0
            readonly property int marginRight: isRight ? gapSize : 0

            implicitWidth: targetWidth + marginLeft + marginRight
            implicitHeight: targetHeight + marginTop + marginBottom
            width: implicitWidth
            height: implicitHeight

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

                shadow.size: 12
                shadow.color: Qt.rgba(0, 0, 0, 0.3)
                shadow.xOffset: 0
                shadow.yOffset: 2

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
                    anchors.fill: parent
                    anchors.margins: winBgFrame.tooltipFramePadding

                    onContainsMouseChanged: tasks.isTooltipHovered = containsMouse

                    parentTask: tasks.currentHoveredTask
                    tasksModel: tasks.tasksModel
                    mpris2Model: mpris2Source
                    audioStreamManager: audioStreamManager

                    readonly property var taskModel: parentTask ? parentTask.model : null

                    rootIndex: tasksModel.makeModelIndex(parentTask ? parentTask.index : 0, -1)
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

                    forceTextMode: tasks.toolTipOpenedByClick !== null && Plasmoid.configuration.groupedTaskVisualization !== 1
                }
            }
        }
    }
}
