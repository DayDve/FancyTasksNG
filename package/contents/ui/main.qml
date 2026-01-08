/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

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

    // For making a bottom to top layout since qml flow can't do that.
    // We just hang the task manager upside down to achieve that.
    // This mirrors the tasks as well, so we just rotate them again to fix that (see Task.qml).
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    readonly property bool shouldShrinkToZero: tasksModel.count === 0
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconsOnly: plasmoid.configuration.iconOnly

    property Task toolTipOpenedByClick
    property Task toolTipAreaItem

    // --- Tooltip Logic Properties ---
    property Item currentHoveredTask: null
    property bool isTooltipHovered: false

    // Timer to close tooltip when mouse leaves both task and tooltip
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
    // --------------------------------

    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")
    readonly property Component pulseAudioComponent: Qt.createComponent("PulseAudio.qml")

    property bool needLayoutRefresh: false
    property /*list<WId> where WId = int|string*/   var taskClosedWithMouseMiddleButton: []
    property alias taskList: taskList

    preferredRepresentation: fullRepresentation

    Plasmoid.constraintHints: Plasmoid.CanFillArea

    Plasmoid.onUserConfiguringChanged: {
        if (Plasmoid.userConfiguring && groupDialog !== null) {
            groupDialog.visible = false;
        }
    }

    Layout.fillWidth: vertical ? true : Plasmoid.configuration.fill
    Layout.fillHeight: !vertical ?
        true : Plasmoid.configuration.fill
    Layout.minimumWidth: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit;
            // For edit mode
        }
        return vertical ?
            0 : LayoutMetrics.preferredMinWidth();
    }
    Layout.minimumHeight: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit;
            // For edit mode
        }
        return !vertical ?
            0 : LayoutMetrics.preferredMinHeight();
    }

    //BEGIN TODO: this is not precise enough: launchers are smaller than full tasks
    Layout.preferredWidth: {
        if (shouldShrinkToZero) {
            return 0.01;
        }
        if (vertical) {
            return Kirigami.Units.gridUnit * 10;
        }
        return taskList.Layout.maximumWidth;
    }
    Layout.preferredHeight: {
        if (shouldShrinkToZero) {
            return 0.01;
        }
        if (vertical) {
            return taskList.Layout.maximumHeight;
        }
        return Kirigami.Units.gridUnit * 2;
    }
    //END TODO

    property Item dragSource

    signal requestLayout
    signal windowsHovered(var winIds, bool hovered)
    signal activateWindowView(var winIds)

    onWindowsHovered: (winIds, hovered) => {
        if (!Plasmoid.configuration.highlightWindows) {
            return;
        }
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
        if (dragSource === null) {
            tasksModel.syncLaunchers();
        }
    }

    function publishIconGeometries(taskItems: /*list<Item>*/var): void {
        if (TaskTools.taskManagerInstanceCount >= 2) {
            return;
        }
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
            if (Plasmoid.configuration.separateLaunchers) {
                return launcherCount;
            }

            let startupsWithLaunchers = 0;
            for (let i = 0; i < taskRepeater.count; ++i) {
                const item = taskRepeater.itemAt(i);
                // During destruction required properties such as item.model can go null for a while,
                // so in paths that can trigger on those moments, they need to be guarded
                if (item?.model?.IsStartup && item.model.HasLauncher) {
                    ++startupsWithLaunchers;
                }
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

        hideActivatedLaunchers: tasks.iconsOnly ||
            Plasmoid.configuration.hideLauncherOnStart
        sortMode: sortModeEnumValue(Plasmoid.configuration.sortingStrategy)
        launchInPlace: tasks.iconsOnly && Plasmoid.configuration.sortingStrategy === 1
        separateLaunchers: {
            if (!tasks.iconsOnly && !Plasmoid.configuration.separateLaunchers && Plasmoid.configuration.sortingStrategy === 1) {
                return false;
            }

            return true;
        }

        groupMode: groupModeEnumValue(Plasmoid.configuration.groupingStrategy)
        groupInline: !Plasmoid.configuration.groupPopups && !tasks.iconsOnly
        groupingWindowTasksThreshold: (Plasmoid.configuration.onlyGroupWhenFull && !tasks.iconsOnly ? LayoutMetrics.optimumCapacity(width, height) + 1 : -1)

        onLauncherListChanged: {
            Plasmoid.configuration.launchers = launcherList;
        }

        onGroupingAppIdBlacklistChanged: {
            Plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
        }

        onGroupingLauncherUrlBlacklistChanged: {
            Plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
        }

        function sortModeEnumValue(index: int): /*TaskManager.TasksModel.SortMode*/ int {
            switch (index) {
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
            default:
                return TaskManager.TasksModel.SortDisabled;
            }
        }

        function groupModeEnumValue(index: int): /*TaskManager.TasksModel.GroupMode*/ int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.GroupDisabled;
            case 1:
                return TaskManager.TasksModel.GroupApplications;
            }
        }

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers;
            groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;

            // Only hook up view only after the above churn is done.
            taskRepeater.model = tasksModel;
        }
    }

    readonly property TaskManagerApplet.Backend backend: TaskManagerApplet.Backend {
        id: backend

        onAddLauncher: {
            tasks.addLauncher(url);
        }
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
                if (task) {
                    tasksModel.requestPublishDelegateGeometry(task.modelIndex(), backend.globalRect(task), task);
                }
                destroy();
            }
        }
    }

    Connections {
        target: Plasmoid

        function onLocationChanged(): void {
            if (TaskTools.taskManagerInstanceCount >= 2) {
                return;
            }
            // This is on a timer because the panel may not have
            // settled into position yet when the location prop-
            // erty updates.
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

    Item {
        anchors.fill: parent

        TaskManager.VirtualDesktopInfo {
            id: virtualDesktopInfo
        }

        TaskManager.ActivityInfo {
            id: activityInfo
            
            readonly property string nullUuid: "00000000-0000-0000-0000-000000000000"
        }

        Loader {
            id: pulseAudio
            sourceComponent: pulseAudioComponent
            active: pulseAudioComponent.status === Component.Ready
        }

        Timer {
            id: iconGeometryTimer

            interval: 500
            repeat: false

            onTriggered: {
                tasks.publishIconGeometries(taskList.children, tasks);
            }
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

            function onLaunchersChanged(): void {
                tasksModel.launcherList = Plasmoid.configuration.launchers;
            }
            function onGroupingAppIdBlacklistChanged(): void {
                tasksModel.groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            }
            function onGroupingLauncherUrlBlacklistChanged(): void {
                tasksModel.groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;
            }
        }

        Component {
            id: busyIndicator
            PlasmaComponents3.BusyIndicator {}
        }

        // Save drag data
        Item {
            id: dragHelper

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction |
            Qt.LinkAction
            Drag.onDragFinished: dropAction => {
                tasks.dragSource = null;
            }
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

            onUrlsDropped: urls => {
                // If all dropped URLs point to application desktop files, we'll add a launcher for each of them.
                const createLaunchers = urls.every(item => backend.isApplication(item));

                if (createLaunchers) {
                    urls.forEach(item => addLauncher(item));
                    return;
                }

                if (!hoveredItem) {
                    return;
                }

                // Otherwise we'll just start a new instance of the application with the URLs as argument,
                // as you probably don't expect some of your files to open in the app and others to spawn launchers.
                tasksModel.requestOpenUrls(hoveredItem.modelIndex(), urls);
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

            LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Qt.application.layoutDirection, vertical)
            anchors {
                left: parent.left
                top: parent.top
            }

            height: taskList.childrenRect.height
            width: taskList.childrenRect.width

            TaskList {
                id: taskList

                LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Qt.application.layoutDirection, vertical)
                anchors {
                    left: parent.left
                    top: parent.top
                }

                readonly property real widthOccupation: taskRepeater.count / columns
                readonly property real heightOccupation: taskRepeater.count / rows

                Layout.maximumWidth: {
                    const totalMaxWidth = children.reduce((accumulator, child) => {
                        if (!isFinite(child.Layout.maximumWidth)) {
                            return accumulator;
                        }
                        return accumulator + child.Layout.maximumWidth;
                    }, 0);
                    return Math.round(totalMaxWidth / widthOccupation);
                }
                Layout.maximumHeight: {
                    const totalMaxHeight = children.reduce((accumulator, child) => {
                        if (!isFinite(child.Layout.maximumHeight)) {
                            return accumulator;
                        }
                        return accumulator + child.Layout.maximumHeight;
                    }, 0);
                    return Math.round(totalMaxHeight / heightOccupation);
                }
                width: {
                    if (tasks.shouldShrinkToZero) {
                        return 0;
                    }
                    if (tasks.vertical) {
                        return tasks.width * Math.min(1, widthOccupation);
                    } else {
                        return Math.min(tasks.width, Layout.maximumWidth);
                    }
                }
                height: {
                    if (tasks.shouldShrinkToZero) {
                        return 0;
                    }
                    if (tasks.vertical) {
                        return Math.min(tasks.height, Layout.maximumHeight);
                    } else {
                        return tasks.height * Math.min(1, heightOccupation);
                    }
                }

                flow: {
                    if (tasks.vertical) {
                        return Plasmoid.configuration.forceStripes ?
                        Grid.LeftToRight : Grid.TopToBottom;
                    }
                    return Plasmoid.configuration.forceStripes ?
                    Grid.TopToBottom : Grid.LeftToRight;
                }

                onAnimatingChanged: {
                    if (!animating) {
                        tasks.publishIconGeometries(children, tasks);
                    }
                }

                Repeater {
                    id: taskRepeater

                    delegate: Task {
                        tasksRoot: tasks
                    }
                    onItemRemoved: (index, item) => {
                        if (tasks.containsMouse && index !== taskRepeater.count && item.model.WinIdList.length > 0 && taskClosedWithMouseMiddleButton.includes(item.winIdList[0])) {
                            needLayoutRefresh = true;
                        }
                        taskClosedWithMouseMiddleButton = [];
                    }
                }
            }
        }
    }

    readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
    property GroupDialog groupDialog

    readonly property bool supportsLaunchers: true

    function hasLauncher(url: url): bool {
        return tasksModel.launcherPosition(url) !== -1;
    }

    function addLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestAddLauncher(url);
        }
    }

    function removeLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestRemoveLauncher(url);
        }
    }

    // This is called by plasmashell in response to a Meta+number shortcut.
    // TODO: Change type to int
    function activateTaskAtIndex(index: var): void {
        if (typeof index !== "number") {
            return;
        }

        const task = taskRepeater.itemAt(index);
        if (task) {
            TaskTools.activateTask(task.modelIndex(), task.model, null, task, Plasmoid, this, effectWatcher.registered);
        }
    }

    function createContextMenu(rootTask, modelIndex, args = {}) {
        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            mpris2Source,
            backend
        });
        return contextMenuComponent.createObject(rootTask, initialArgs);
    }

    function shouldBeMirrored(reverseMode, layoutDirection, vertical): bool {
        // LayoutMirroring is only horizontal
        if (vertical) {
            return layoutDirection === Qt.RightToLeft;
        }

        if (layoutDirection === Qt.LeftToRight) {
            return reverseMode;
        }
        return !reverseMode;
    }

    Component.onCompleted: {
        TaskTools.taskManagerInstanceCount += 1;
        requestLayout.connect(iconGeometryTimer.restart);
    }

    Component.onDestruction: {
        TaskTools.taskManagerInstanceCount -= 1;
    }

    // --- SHARED TOOLTIP IMPLEMENTATION ---

    // 1. DIALOG FOR RUNNING WINDOWS (Rich content: previews, player, etc.)
    PlasmaCore.Dialog {
        id: windowTooltipDialog
        visualParent: tasks.currentHoveredTask
        location: Plasmoid.location
        type: PlasmaCore.Dialog.Tooltip

        backgroundHints: PlasmaCore.Types.NoBackground
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WA_TranslucentBackground

        // Visible only if we have a task AND it IS a window
        visible: tasks.currentHoveredTask !== null && !tasks.currentHoveredTask.inPopup && !tasks.groupDialog && tasks.currentHoveredTask.isWindow

        mainItem: Item {
            id: winContentWrapper

            HoverHandler {
                onHoveredChanged: tasks.isTooltipHovered = hovered
            }

            readonly property int gapSize: {
                if (!tasks.currentHoveredTask) return Kirigami.Units.smallSpacing;
                const standardGap = Kirigami.Units.smallSpacing;
                const zoom = plasmoid.configuration.iconZoomFactor;
                const sizeOverride = plasmoid.configuration.iconSizeOverride;
                const fixedSize = plasmoid.configuration.iconSizePx;
                const iconScale = plasmoid.configuration.iconScale / 100;
                const taskHeight = tasks.currentHoveredTask.height;
                const baseIconHeight = sizeOverride ? fixedSize : (taskHeight * iconScale);
                const zoomedIconHeight = baseIconHeight + zoom;
                const padding = (taskHeight - baseIconHeight) / 2;
                const overflow = zoom - padding;
                if (overflow > 0 && zoomedIconHeight > (taskHeight + standardGap)) return overflow + 1;
                return standardGap;
            }

            readonly property int loc: Plasmoid.location

            implicitWidth: (loc === PlasmaCore.Types.LeftEdge || loc === PlasmaCore.Types.RightEdge) ?
                (winBgFrame.width + gapSize) : winBgFrame.width
            implicitHeight: (loc === PlasmaCore.Types.TopEdge || loc === PlasmaCore.Types.BottomEdge) ?
                (winBgFrame.height + gapSize) : winBgFrame.height

            KSvg.FrameSvgItem {
                id: winBgFrame
                imagePath: "widgets/tooltip"
                readonly property int thumbBaseWidth: Kirigami.Units.gridUnit * 14
                readonly property int thumbBaseHeight: thumbBaseWidth / (Screen.width / Screen.height)

                width: Math.max(toolTipInstance.implicitWidth, thumbBaseWidth) + margins.left + margins.right
                height: Math.max(toolTipInstance.implicitHeight, thumbBaseHeight) + margins.top + margins.bottom

                anchors {
                    bottom: (winContentWrapper.loc === PlasmaCore.Types.BottomEdge) ? parent.bottom : undefined
                    bottomMargin: (winContentWrapper.loc === PlasmaCore.Types.BottomEdge) ? gapSize : 0
                    top: (winContentWrapper.loc === PlasmaCore.Types.TopEdge) ? parent.top : undefined
                    topMargin: (winContentWrapper.loc === PlasmaCore.Types.TopEdge) ? gapSize : 0
                    left: (winContentWrapper.loc === PlasmaCore.Types.LeftEdge) ? parent.left : undefined
                    leftMargin: (winContentWrapper.loc === PlasmaCore.Types.LeftEdge) ? gapSize : 0
                    right: (winContentWrapper.loc === PlasmaCore.Types.RightEdge) ? parent.right : undefined
                    rightMargin: (winContentWrapper.loc === PlasmaCore.Types.RightEdge) ? gapSize : 0
                    horizontalCenter: (winContentWrapper.loc === PlasmaCore.Types.TopEdge || winContentWrapper.loc === PlasmaCore.Types.BottomEdge) ? parent.horizontalCenter : undefined
                    verticalCenter: (winContentWrapper.loc === PlasmaCore.Types.LeftEdge || winContentWrapper.loc === PlasmaCore.Types.RightEdge) ? parent.verticalCenter : undefined
                }

                ToolTipDelegate {
                    id: toolTipInstance
                    
                    anchors.fill: parent
                    anchors.leftMargin: winBgFrame.margins.left
                    anchors.rightMargin: winBgFrame.margins.right
                    anchors.topMargin: winBgFrame.margins.top
                    anchors.bottomMargin: winBgFrame.margins.bottom

                    parentTask: tasks.currentHoveredTask
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
                    smartLauncherCountVisible: parentTask && parentTask.smartLauncherItem ? parentTask.smartLauncherItem.countVisible : false
                    smartLauncherCount: smartLauncherCountVisible ? parentTask.smartLauncherItem.count : 0
                }
            }
        }
    }

    // 2. DIALOG FOR PINNED APPS (Simple Text)
    PlasmaCore.Dialog {
        id: pinnedTooltipDialog
        visualParent: tasks.currentHoveredTask
        location: Plasmoid.location
        type: PlasmaCore.Dialog.Tooltip

        backgroundHints: PlasmaCore.Types.NoBackground
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WA_TranslucentBackground

        // Visible only if we have a task AND it is NOT a window
        visible: tasks.currentHoveredTask !== null && !tasks.currentHoveredTask.inPopup && !tasks.groupDialog && !tasks.currentHoveredTask.isWindow

        mainItem: Item {
            id: pinnedContentWrapper

            HoverHandler {
                onHoveredChanged: tasks.isTooltipHovered = hovered
            }

            readonly property int gapSize: {
                if (!tasks.currentHoveredTask) return Kirigami.Units.smallSpacing;
                const standardGap = Kirigami.Units.smallSpacing;
                const zoom = plasmoid.configuration.iconZoomFactor;
                const sizeOverride = plasmoid.configuration.iconSizeOverride;
                const fixedSize = plasmoid.configuration.iconSizePx;
                const iconScale = plasmoid.configuration.iconScale / 100;
                const taskHeight = tasks.currentHoveredTask.height;
                const baseIconHeight = sizeOverride ? fixedSize : (taskHeight * iconScale);
                const zoomedIconHeight = baseIconHeight + zoom;
                const padding = (taskHeight - baseIconHeight) / 2;
                const overflow = zoom - padding;
                if (overflow > 0 && zoomedIconHeight > (taskHeight + standardGap)) return overflow + 1;
                return standardGap;
            }

            readonly property int loc: Plasmoid.location

            implicitWidth: (loc === PlasmaCore.Types.LeftEdge || loc === PlasmaCore.Types.RightEdge) ?
                (pinnedBgFrame.width + gapSize) : pinnedBgFrame.width
            implicitHeight: (loc === PlasmaCore.Types.TopEdge || loc === PlasmaCore.Types.BottomEdge) ?
                (pinnedBgFrame.height + gapSize) : pinnedBgFrame.height

            KSvg.FrameSvgItem {
                id: pinnedBgFrame
                imagePath: "widgets/tooltip"

                width: Math.max(pinnedLabel.implicitWidth, Kirigami.Units.gridUnit * 2) + margins.left + margins.right
                height: Math.max(pinnedLabel.implicitHeight, Kirigami.Units.gridUnit) + margins.top + margins.bottom

                anchors {
                    bottom: (pinnedContentWrapper.loc === PlasmaCore.Types.BottomEdge) ? parent.bottom : undefined
                    bottomMargin: (pinnedContentWrapper.loc === PlasmaCore.Types.BottomEdge) ? gapSize : 0
                    top: (pinnedContentWrapper.loc === PlasmaCore.Types.TopEdge) ? parent.top : undefined
                    topMargin: (pinnedContentWrapper.loc === PlasmaCore.Types.TopEdge) ? gapSize : 0
                    left: (pinnedContentWrapper.loc === PlasmaCore.Types.LeftEdge) ? parent.left : undefined
                    leftMargin: (pinnedContentWrapper.loc === PlasmaCore.Types.LeftEdge) ? gapSize : 0
                    right: (pinnedContentWrapper.loc === PlasmaCore.Types.RightEdge) ? parent.right : undefined
                    rightMargin: (pinnedContentWrapper.loc === PlasmaCore.Types.RightEdge) ? gapSize : 0
                    horizontalCenter: (pinnedContentWrapper.loc === PlasmaCore.Types.TopEdge || pinnedContentWrapper.loc === PlasmaCore.Types.BottomEdge) ? parent.horizontalCenter : undefined
                    verticalCenter: (pinnedContentWrapper.loc === PlasmaCore.Types.LeftEdge || pinnedContentWrapper.loc === PlasmaCore.Types.RightEdge) ? parent.verticalCenter : undefined
                }

                PlasmaComponents3.Label {
                    id: pinnedLabel
                    text: tasks.currentHoveredTask ? tasks.currentHoveredTask.model.display : ""
                    anchors.centerIn: parent
                }
            }
        }
    }
}
