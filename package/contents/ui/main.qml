/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts


import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

import org.kde.plasma.workspace.trianglemousefilter

import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.taskmanager as TaskManagerApplet
import org.kde.plasma.workspace.dbus as DBus

import "code/layoutmetrics.js" as LayoutMetrics
import "code/tools.js" as TaskTools

PlasmoidItem {
    id: tasks

    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    readonly property bool shouldShrinkToZero: tasksModel.count === 0
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconsOnly: Plasmoid.configuration.iconOnly

    property Task toolTipOpenedByClick
    property Task toolTipAreaItem

    property Task currentHoveredTask: null
    property bool isTooltipHovered: false

    // PERSIST PARENT FOR FADE-OUT ANIMATION
    property Item lastTooltipParent: null
    
    // Key: WinId, Value: ItemGrabResult
    property var thumbnailCache: ({})

    onCurrentHoveredTaskChanged: {
        if (currentHoveredTask) {
            lastTooltipParent = currentHoveredTask.tooltipAnchor;
        }
    }

    Timer {
        id: tooltipCloseTimer
        interval: 250
        running: !tasks.isTooltipHovered && tasks.currentHoveredTask !== null && !tasks.currentHoveredTask.containsMouse
        onTriggered: {
            if (!tasks.isTooltipHovered && (tasks.currentHoveredTask && !tasks.currentHoveredTask.containsMouse)) {
                tasks.currentHoveredTask = null;
            }
        }
    }

    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")
    readonly property Component pulseAudioComponent: Qt.createComponent("PulseAudio.qml")

    property bool needLayoutRefresh: false
    property var taskClosedWithMouseMiddleButton: []
    property alias taskList: taskList
    property alias effectWatcher: effectWatcher
    property alias pulseAudio: pulseAudio
    property alias mpris2Source: mpris2Source
    property alias dragHelper: dragHelper
    property alias taskFrame: taskFrame
    property alias busyIndicator: busyIndicator

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    Plasmoid.onUserConfiguringChanged: {
        if (Plasmoid.userConfiguring && groupDialog !== null) {
            groupDialog.visible = false;
        }
    }

    Layout.fillWidth: vertical ? true : Plasmoid.configuration.fill
    Layout.fillHeight: !vertical ? true : Plasmoid.configuration.fill
    Layout.minimumWidth: {
        if (shouldShrinkToZero) return Kirigami.Units.gridUnit;
        return vertical ? 0 : LayoutMetrics.preferredMinWidth();
    }
    Layout.minimumHeight: {
        if (shouldShrinkToZero) return Kirigami.Units.gridUnit;
        return !vertical ? 0 : LayoutMetrics.preferredMinHeight();
    }
    Layout.preferredWidth: {
        if (shouldShrinkToZero) return 0.01;
        if (vertical) return Kirigami.Units.gridUnit * 10;
        return taskList.Layout.maximumWidth;
    }
    Layout.preferredHeight: {
        if (shouldShrinkToZero) return 0.01;
        if (vertical) return taskList.Layout.maximumHeight;
        return Kirigami.Units.gridUnit * 2;
    }

    property Item dragSource

    signal requestLayout
    signal windowsHovered(var winIds, bool hovered)
    signal activateWindowView(var winIds)

    onWindowsHovered: (winIds, hovered) => {
        if (!Plasmoid.configuration.highlightWindows) return;
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
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [[]], signature: "(as)"});
    }

    onDragSourceChanged: {
        if (dragSource === null) tasksModel.syncLaunchers();
    }

    function publishIconGeometries(taskItems: var): void {
        if (TaskTools.taskManagerInstanceCount >= 2) return;
        for (let i = 0; i < taskItems.length - 1; ++i) {
            const task = taskItems[i];
            if (!task.model.IsLauncher && !task.model.IsStartup) {
                tasksModel.requestPublishDelegateGeometry(tasksModel.makeModelIndex(task.index), backend.globalRect(task), task);
            }
        }
    }

    readonly property TaskManager.TasksModel tasksModel: TaskManager.TasksModel {
        id: tasksModel

        readonly property int logicalLauncherCount: {
            if (Plasmoid.configuration.separateLaunchers) return launcherCount;
            let startupsWithLaunchers = 0;
            const isStartup = (item) => item && item["isStartup"] && item["hasLauncher"];
            for (let i = 0; i < taskRepeater.count; ++i) {
                const item = taskRepeater.itemAt(i);
                if (isStartup(item)) ++startupsWithLaunchers;
            }
            return launcherCount + startupsWithLaunchers;
        }

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity
        filterByVirtualDesktop: Plasmoid.configuration.showOnlyCurrentDesktop
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen
        filterByActivity: Plasmoid.configuration.showOnlyCurrentActivity
        filterNotMinimized: Plasmoid.configuration.showOnlyMinimized
        hideActivatedLaunchers: tasks.iconsOnly || Plasmoid.configuration.hideLauncherOnStart
        sortMode: sortModeEnumValue(Plasmoid.configuration.sortingStrategy)
        launchInPlace: tasks.iconsOnly && Plasmoid.configuration.sortingStrategy === 1
        separateLaunchers: !tasks.iconsOnly && !Plasmoid.configuration.separateLaunchers && Plasmoid.configuration.sortingStrategy === 1 ? false : true
        groupMode: groupModeEnumValue(Plasmoid.configuration.groupingStrategy)
        groupInline: !Plasmoid.configuration.groupPopups && !tasks.iconsOnly
        groupingWindowTasksThreshold: (Plasmoid.configuration.onlyGroupWhenFull && !tasks.iconsOnly ? LayoutMetrics.optimumCapacity(tasks.width, tasks.height) + 1 : -1)

        onLauncherListChanged: Plasmoid.configuration.launchers = launcherList;
        onGroupingAppIdBlacklistChanged: Plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
        onGroupingLauncherUrlBlacklistChanged: Plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;

        function sortModeEnumValue(index: int): int {
            switch (index) {
            case 0: return TaskManager.TasksModel.SortDisabled;
            case 1: return TaskManager.TasksModel.SortManual;
            case 2: return TaskManager.TasksModel.SortAlpha;
            case 3: return TaskManager.TasksModel.SortVirtualDesktop;
            case 4: return TaskManager.TasksModel.SortActivity;
            default: return TaskManager.TasksModel.SortDisabled;
            }
        }

        function groupModeEnumValue(index: int): int {
            switch (index) {
            case 0: return TaskManager.TasksModel.GroupDisabled;
            case 1: return TaskManager.TasksModel.GroupApplications;
            }
        }

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers;
            groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;
            taskRepeater.model = tasksModel;
        }
    }

    readonly property TaskManagerApplet.Backend backend: TaskManagerApplet.Backend {
        id: backend
        onAddLauncher: (url) => tasks.addLauncher(url);
    }

    DBus.DBusServiceWatcher {
        id: effectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    readonly property Component taskInitComponent: Component {
        Timer {
            interval: Kirigami.Units.longDuration
            running: true
            onTriggered: {
                const task = parent as Task;
                if (task) tasks.tasksModel.requestPublishDelegateGeometry(task.modelIndex(), backend.globalRect(task), task);
                destroy();
            }
        }
    }

    Connections {
        target: Plasmoid
        function onLocationChanged(): void {
            if (TaskTools.taskManagerInstanceCount >= 2) return;
            iconGeometryTimer.start();
        }
    }

    Connections {
        target: Plasmoid.containment
        function onScreenGeometryChanged(): void {
            iconGeometryTimer.start();
        }
    }

    Mpris.Mpris2Model { id: mpris2Source }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: rootHoverHandler
        }
        TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
        TaskManager.ActivityInfo {
            id: activityInfo
            readonly property string nullUuid: "00000000-0000-0000-0000-000000000000"
        }

        Loader {
            id: pulseAudio
            sourceComponent: tasks.pulseAudioComponent
            active: tasks.pulseAudioComponent.status === Component.Ready
            onLoaded: item.backend = backend
        }

        Timer {
            id: iconGeometryTimer
            interval: 500
            repeat: false
            onTriggered: tasks.publishIconGeometries(taskList.children, tasks);
        }
        Timer {
            id: startupSortFixTimer
            interval: 2000
            running: true
            repeat: false
            onTriggered: {
                tasksModel.launcherList = Plasmoid.configuration.launchers;
                tasksModel.syncLaunchers();
            }
        }



        Binding {
            target: Plasmoid
            property: "status"
            value: (tasksModel.anyTaskDemandsAttention && Plasmoid.configuration.unhideOnAttention ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus)
            restoreMode: Binding.RestoreBinding
        }

        Connections {
            target: Plasmoid.configuration
            function onLaunchersChanged(): void { tasksModel.launcherList = Plasmoid.configuration.launchers; }
            function onGroupingAppIdBlacklistChanged(): void { tasksModel.groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist; }
            function onGroupingLauncherUrlBlacklistChanged(): void { tasksModel.groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist; }
        }

        Component { id: busyIndicator; PlasmaComponents3.BusyIndicator {} }

        Item {
            id: dragHelper
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
            Drag.onDragFinished: dropAction => { tasks.dragSource = null; }
        }

        KSvg.FrameSvgItem {
            id: taskFrame
            visible: false
            imagePath: "widgets/tasks"
            prefix: TaskTools.taskPrefix("normal", Plasmoid.location)
        }

        MouseHandler {
            id: mouseHandler
            anchors.fill: parent
            target: taskList
            tasks: tasks
            tasksModel: tasksModel
            onUrlsDropped: urls => {
                const createLaunchers = urls.every(item => backend.isApplication(item));
                if (createLaunchers) {
                    urls.forEach(item => tasks.addLauncher(item));
                    return;
                }
                if (!hoveredItem) return;
                const task = hoveredItem as Task;
                tasksModel.requestOpenUrls(task.modelIndex(), urls);
            }
        }

        TriangleMouseFilter {
            id: tmf
            filterTimeOut: 300
            active: tasks.currentHoveredTask !== null
            blockFirstEnter: false
            edge: {
                switch (Plasmoid.location) {
                case PlasmaCore.Types.BottomEdge: return Qt.TopEdge;
                case PlasmaCore.Types.TopEdge: return Qt.BottomEdge;
                case PlasmaCore.Types.LeftEdge: return Qt.RightEdge;
                case PlasmaCore.Types.RightEdge: return Qt.LeftEdge;
                default: return Qt.TopEdge;
                }
            }
            LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Qt.locale().textDirection, tasks.vertical)
            anchors { left: parent.left; top: parent.top }
            height: taskList.childrenRect.height
            width: taskList.childrenRect.width

            TaskList {
                id: taskList
                tasks: tasks
                tasksModel: tasksModel
                LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Qt.locale().textDirection, tasks.vertical)
                anchors { left: parent.left; top: parent.top }
                readonly property real widthOccupation: taskRepeater.count / columns
                readonly property real heightOccupation: taskRepeater.count / rows
                Layout.maximumWidth: Math.round(children.reduce((acc, child) => isFinite(child.Layout.maximumWidth) ? acc + child.Layout.maximumWidth : acc, 0) / widthOccupation)
                Layout.maximumHeight: Math.round(children.reduce((acc, child) => isFinite(child.Layout.maximumHeight) ? acc + child.Layout.maximumHeight : acc, 0) / heightOccupation)
                width: tasks.shouldShrinkToZero ? 0 : (tasks.vertical ? tasks.width * Math.min(1, widthOccupation) : Math.min(tasks.width, Layout.maximumWidth))
                height: tasks.shouldShrinkToZero ? 0 : (tasks.vertical ? Math.min(tasks.height, Layout.maximumHeight) : tasks.height * Math.min(1, heightOccupation))
                flow: tasks.vertical ? (Plasmoid.configuration.forceStripes ? Grid.LeftToRight : Grid.TopToBottom) : (Plasmoid.configuration.forceStripes ? Grid.TopToBottom : Grid.LeftToRight)
                onAnimatingChanged: if (!animating) tasks.publishIconGeometries(children, tasks);

                Repeater {
                    id: taskRepeater
                    delegate: Task { tasksRoot: tasks }
                    onItemRemoved: (index, item) => {
                        const task = item as Task;
                        if (rootHoverHandler.hovered && index !== taskRepeater.count && task.model.WinIdList.length > 0 && tasks.taskClosedWithMouseMiddleButton.includes(task.model.WinIdList[0])) {
                            tasks.needLayoutRefresh = true;
                        }
                        tasks.taskClosedWithMouseMiddleButton = [];
                    }
                }
            }
        }
    }

    readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
    property GroupDialog groupDialog
    readonly property bool supportsLaunchers: true

    function hasLauncher(url: url): bool { return tasksModel.launcherPosition(url) !== -1; }
    function addLauncher(url: url): void { if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) tasksModel.requestAddLauncher(url); }
    function removeLauncher(url: url): void { if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) tasksModel.requestRemoveLauncher(url); }
    function activateTaskAtIndex(index: var): void {
        if (typeof index !== "number") return;
        const task = taskRepeater.itemAt(index) as Task;
        if (task) TaskTools.activateTask(task.modelIndex(), task.model, null, task, Plasmoid, this, effectWatcher.registered);
    }
    function createContextMenu(rootTask, modelIndex, args = {}) {
        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            mpris2Source,
            backend,
            tasksModel,
            virtualDesktopInfo,
            activityInfo
        });
        return contextMenuComponent.createObject(rootTask, initialArgs);
    }
    function shouldBeMirrored(reverseMode, layoutDirection, vertical): bool {
        if (vertical) return layoutDirection === Qt.RightToLeft;
        if (layoutDirection === Qt.LeftToRight) return reverseMode;
        return !reverseMode;
    }

    Component.onCompleted: {
        TaskTools.taskManagerInstanceCount += 1;
        requestLayout.connect(iconGeometryTimer.restart);
    }
    Component.onDestruction: TaskTools.taskManagerInstanceCount -= 1;

    // --- SHARED TOOLTIP IMPLEMENTATION ---

    // 1. DIALOG FOR RUNNING WINDOWS
    PlasmaCore.Dialog {
        id: windowTooltipDialog
        
        // Use lastTooltipParent to keep position during FadeOut
        visualParent: tasks.currentHoveredTask ? tasks.currentHoveredTask.tooltipAnchor : tasks.lastTooltipParent
        
        location: Plasmoid.location
        type: PlasmaCore.Dialog.Tooltip

        backgroundHints: PlasmaCore.Types.NoBackground
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WA_TranslucentBackground
        
        // LOGIC: Show if condition met OR if we are currently fading out (opacity > 0)
        readonly property bool shouldShow: tasks.currentHoveredTask !== null && !tasks.currentHoveredTask.inPopup && !tasks.groupDialog && tasks.currentHoveredTask.isWindow
        visible: shouldShow || winContainer.opacity > 0

        mainItem: Item {
            id: winContainer
            
            // TARGET DIMENSIONS (What the content wants to be)
            readonly property real targetWidth: toolTipInstance.implicitWidth + winBgFrame.margins.left + winBgFrame.margins.right
            readonly property real targetHeight: toolTipInstance.implicitHeight + winBgFrame.margins.top + winBgFrame.margins.bottom

            // Container dimensions are max of current animated size and target size
            // This ensures stable centering during resize animation
            width: Math.max(winBgFrame.width, targetWidth)
            height: Math.max(winBgFrame.height, targetHeight)

            // FADE ANIMATION
            opacity: windowTooltipDialog.shouldShow ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }

            KSvg.FrameSvgItem {
                id: winBgFrame
                imagePath: "widgets/tooltip"

                // Frame animates to the TARGET size
                width: winContainer.targetWidth
                height: winContainer.targetHeight
                
                anchors.centerIn: parent
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutExpo
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutExpo
                    }
                }

                ToolTipDelegate {
                    id: toolTipInstance
                    anchors.centerIn: parent

                    // BINDING TO UPDATE GLOBAL HOVER STATE
                    onContainsMouseChanged: tasks.isTooltipHovered = containsMouse

                    parentTask: tasks.currentHoveredTask
                    tasksModel: tasks.tasksModel
                    mpris2Model: mpris2Source
                    pulseAudio: pulseAudio
                    
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
                    smartLauncherCountVisible: parentTask && parentTask.smartLauncherItem ? parentTask.smartLauncherItem["countVisible"] : false
                    smartLauncherCount: smartLauncherCountVisible ? parentTask.smartLauncherItem["count"] : 0
                    
                    isPlayingAudio: taskModel ? (taskModel.IsPlayingAudio === true) : false
                    isMuted: taskModel ? (taskModel.IsMuted === true) : false
                }
            }
        }
    }

    // 2. DIALOG FOR PINNED APPS
    PlasmaCore.Dialog {
        id: pinnedTooltipDialog
        visualParent: tasks.currentHoveredTask ? tasks.currentHoveredTask.tooltipAnchor : tasks.lastTooltipParent
        location: Plasmoid.location
        type: PlasmaCore.Dialog.Tooltip

        backgroundHints: PlasmaCore.Types.NoBackground
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WA_TranslucentBackground
        
        readonly property bool shouldShow: tasks.currentHoveredTask !== null && !tasks.currentHoveredTask.inPopup && !tasks.groupDialog && !tasks.currentHoveredTask.isWindow
        visible: shouldShow || pinnedContainer.opacity > 0

        mainItem: Item {
            id: pinnedContainer

            readonly property real targetWidth: pinnedLabel.implicitWidth + pinnedBgFrame.margins.left + pinnedBgFrame.margins.right
            readonly property real targetHeight: pinnedLabel.implicitHeight + pinnedBgFrame.margins.top + pinnedBgFrame.margins.bottom

            width: Math.max(pinnedBgFrame.width, targetWidth)
            height: Math.max(pinnedBgFrame.height, targetHeight)

            // FADE ANIMATION
            opacity: pinnedTooltipDialog.shouldShow ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }

            KSvg.FrameSvgItem {
                id: pinnedBgFrame
                imagePath: "widgets/tooltip"

                width: pinnedContainer.targetWidth
                height: pinnedContainer.targetHeight
                anchors.centerIn: parent
                
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutExpo
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutExpo
                    }
                }

                PlasmaComponents3.Label {
                    id: pinnedLabel
                    text: tasks.currentHoveredTask ? tasks.currentHoveredTask.model.display : ""
                    anchors.centerIn: parent
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                    elide: Text.ElideRight
                }
            }
        }
    }
}
