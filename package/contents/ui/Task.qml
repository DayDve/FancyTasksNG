/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2022-2025 Luis Bocanegra <luisbocanegra17b@gmail.com>
    SPDX-FileCopyrightText: 2025 SushiTrash <namanrajhans@gmail.com>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2024 Bharadwaj Raju <bharadwaj.raju777@protonmail.com>
    SPDX-FileCopyrightText: 2024 Niccolò Venerandi <niccolo@venerandi.com>
    SPDX-FileCopyrightText: 2024 Yifan Zhu <fanzhuyifan@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Andrei Shevchuk <andrei@shevchuk.co>
    SPDX-FileCopyrightText: 2023 Nicolas Fella <nicolas.fella@gmx.de>
    SPDX-FileCopyrightText: 2023 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.ksvg as KSvg
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import QtQuick.Effects
import org.kde.taskmanager as TaskManager

import "code/layoutmetrics.js" as LayoutMetrics
import "code/tools.js" as TaskTools
import "code/singletones"

Item {
    id: task
    readonly property alias frame: frame
    z: highlighted ? 10 : (badgeVisible || playingAudio || muted) ? 1 : 0

    activeFocusOnTab: true
    opacity: tasksRoot.dragSource === task ? (task.inPopup ? 1.0 : 0.5) : 1.0
    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.shortDuration }
    }

    Behavior on x {
        enabled: !task.tasksRoot.dragSource
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
        }
    }
    Behavior on y {
        enabled: !task.tasksRoot.dragSource
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
        }
    }



    readonly property int _cfgIconSize: Plasmoid.configuration.iconSizeOverride ? Plasmoid.configuration.iconSizePx : (Math.min(tasksRoot.width, tasksRoot.height) * Plasmoid.configuration.iconScale / 100)
    readonly property int _cfgZoom: (tasksRoot.iconsOnly && Plasmoid.configuration.taskHoverEffect) ? Plasmoid.configuration.iconZoomFactor : 0
    readonly property int _maxIconSize: _cfgIconSize + _cfgZoom
    property alias taskIcon: iconBox.icon
    readonly property bool iconOverflows: tasksRoot.vertical ? 
        (iconBox.icon.width > tasksRoot.width) : (iconBox.icon.height > tasksRoot.height)

    Item {
        id: tooltipAnchor
        anchors.centerIn: parent
        width: task.tasksRoot.vertical ? (Math.max(task.tasksRoot.width, task._maxIconSize) + Kirigami.Units.smallSpacing * 2) : parent.width
        height: !task.tasksRoot.vertical ? (Math.max(task.tasksRoot.height, task._maxIconSize) + Kirigami.Units.smallSpacing * 2) : parent.height
        visible: false
    }
    property alias tooltipAnchor: tooltipAnchor
    property string tintColor: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark ?
        "#ffffff" : "#000000"

    rotation: (tasksRoot && Plasmoid.configuration.reverseMode && tasksRoot.vertical) ?
        180 : 0

    implicitHeight: {
        if (!tasksRoot) return LayoutMetrics.preferredMinHeight();
        if (task.inPopup) return LayoutMetrics.preferredHeightInPopup();
        if (tasksRoot.vertical) {
            if (task.isIcon) {
                let cols = (tasksRoot.taskList && tasksRoot.taskList.columns > 0) ? tasksRoot.taskList.columns : (Plasmoid.configuration.maxStripes || 1);
                return (tasksRoot.width / cols) + LayoutMetrics.verticalMargins();
            }
            return LayoutMetrics.preferredMaxHeight();
        } else {
            let stripes = Plasmoid.configuration.maxStripes || 1;
            if (task.isIcon) {
                let rws = (tasksRoot.taskList && tasksRoot.taskList.rows > 0) ? tasksRoot.taskList.rows : stripes;
                return (tasksRoot.height / rws) + LayoutMetrics.verticalMargins();
            }
            return Math.max(tasksRoot.height / stripes, LayoutMetrics.preferredMinHeight());
        }
    }
    implicitWidth: {
        if (!tasksRoot) return LayoutMetrics.preferredMinWidth();
        if (tasksRoot.vertical) {
            let stripes = Plasmoid.configuration.maxStripes || 1;
            if (task.isIcon) {
                let cols = (tasksRoot.taskList && tasksRoot.taskList.columns > 0) ? tasksRoot.taskList.columns : stripes;
                return (tasksRoot.width / cols) + LayoutMetrics.horizontalMargins();
            }
            return Math.max(LayoutMetrics.preferredMinWidth(), Math.min(LayoutMetrics.preferredMaxWidth(), tasksRoot.width / stripes));
        } else {
            if (task.isIcon) {
                let rws = (tasksRoot.taskList && tasksRoot.taskList.rows > 0) ? tasksRoot.taskList.rows : (Plasmoid.configuration.maxStripes || 1);
                return (tasksRoot.height / rws) + LayoutMetrics.horizontalMargins();
            }
            return LayoutMetrics.preferredMaxWidth();
        }
    }

    Layout.fillWidth: true
    Layout.fillHeight: !task.inPopup
    Layout.maximumWidth: (!tasksRoot || tasksRoot.vertical) ?
        -1 : ((task.model?.IsLauncher && !tasksRoot.iconsOnly) ? (tasksRoot.height / tasksRoot.taskList.rows) + LayoutMetrics.horizontalMargins() : LayoutMetrics.preferredMaxWidth())
    Layout.maximumHeight: (!tasksRoot || !tasksRoot.vertical) ?
        -1 : ((task.model?.IsLauncher && !tasksRoot.iconsOnly) ? (tasksRoot.width / tasksRoot.taskList.columns) + LayoutMetrics.verticalMargins() : LayoutMetrics.preferredMaxHeight())

    required property var model
    required property int index
    property /*main.qml*/  var tasksRoot

    readonly property int pid: (task.model && task.model.AppPid) ? task.model.AppPid : 0
    readonly property string appName: (task.model && task.model.AppName) ? task.model.AppName : ""
    readonly property string appId: (task.model && task.model.AppId) ? task.model.AppId.replace(/\.desktop/, '') : ""
    readonly property bool isIcon: task.model ? (tasksRoot.iconsOnly || !!task.model.IsLauncher) : tasksRoot.iconsOnly
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isLaunching: false
    readonly property alias launchingTimeoutTimer: launchingTimeoutTimer
    
    function triggerLaunch(): void {
        if (task.model && task.model.IsLauncher && task.winIdList.length === 0) {
            task.isLaunching = true;
            task.launchingTimeoutTimer.restart();
        }
    }
    property bool isStartup: !!(task.model && task.model.IsStartup)
    property bool isWindow: !!(task.model && task.model.IsWindow)
    readonly property bool isHovered: (tasksRoot && tasksRoot.mouseHandler) ? (tasksRoot.mouseHandler.hoveredItem === task) : false
    
    // Modern taskState property for internal and Indicators.qml usage
    readonly property string taskState: {
        if (!task.model) return "normal";

        switch (true) {
            case (task.model.IsLauncher && task.winIdList.length === 0):
                return "launcher";
            case task.model.IsDemandingAttention:
                return "attention";
            case task.model.IsActive:
                return "active";
            case task.model.IsMinimized:
                return "minimized";
            default:
                return "inactive";
        }
    }

    property int childCount: (task.model && task.model.ChildCount) ? task.model.ChildCount : 0
    property int previousChildCount: 0
    property alias labelText: label.text
    property var contextMenu: null
    readonly property bool smartLauncherEnabled: !task.inPopup && task.model && !task.model.IsStartup
    // standalone notification counting (BadgeManager singleton)
    property int lastSeenCount: 0
    property bool hasUnseenNotifications: false
    onToolTipOpenChanged: {
        if (toolTipOpen) {
            task.hasUnseenNotifications = false;
        }
    }
    onModelChanged: {
        if (task.model && task.model.IsActive) {
            task.hasUnseenNotifications = false;
        }
    }
    
    Connections {
        target: task.model
        enabled: !!task.model
        ignoreUnknownSignals: true
        function onIsActiveChanged() {
            if (task.model.IsActive) {
                task.hasUnseenNotifications = false;
            }
        }
    }
    
    readonly property int badgeCount: {
        if (!task.model) return 0;
        return (BadgeManager.countVersion >= 0) ? BadgeManager.getUnreadCount(task.model.AppId) : 0;
    }
    readonly property bool badgeVisible: {
        if (badgeCount <= 0) return false;
        if (!Plasmoid.configuration.showBadgesOnLaunchers && task.winIdList.length === 0) {
            return false;
        }
        return true;
    }
    
    function adjustVolume(increment, isGlobal) {
        if (mediaController) {
            mediaController.adjustVolume(increment, isGlobal);
        }
    }

    function getGlobalRect(): /*QRect*/ var {
        if (!task || !task.window) return Qt.rect(0, 0, 0, 0);
        const pos = task.mapToGlobal(0, 0);
        return Qt.rect(pos.x, pos.y, task.width, task.height);
    }


    Connections {
        target: task
        function onBadgeCountChanged() {
            if (task.badgeCount > task.lastSeenCount) {
                task.hasUnseenNotifications = true;
            } else if (task.badgeCount === 0) {
                task.hasUnseenNotifications = false;
            }
            task.lastSeenCount = task.badgeCount;
        }
    }

    Connections {
        target: task.tasksRoot ? task.tasksRoot.tasksModel : null
        ignoreUnknownSignals: true

        function checkStartupRows(first, last) {
            if (!task.model || !task.model.IsLauncher || task.winIdList.length > 0) {
                return;
            }

            const appId = task.model.AppId;
            const launcherUrl = task.model.LauncherUrlWithoutIcon ? task.model.LauncherUrlWithoutIcon.toString() : "";
            
            function normalizeAppId(id) {
                return String(id || "").replace(/\.desktop$/, "").toLowerCase();
            }

            function normalizeUrl(url) {
                return String(url || "").replace(/\.desktop$/, "").toLowerCase();
            }

            const normAppId = normalizeAppId(appId);
            const normUrl = normalizeUrl(launcherUrl);

            const tModel = task.tasksRoot.tasksModel;
            for (let i = first; i <= last; ++i) {
                const idx = tModel.makeModelIndex(i);
                if (idx.valid) {
                    const isStartup = tModel.data(idx, TaskManager.AbstractTasksModel.IsStartup) === true;
                    if (isStartup) {
                        const startupAppId = tModel.data(idx, TaskManager.AbstractTasksModel.AppId);
                        const startupUrl = tModel.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
                        const startupUrlStr = startupUrl ? startupUrl.toString() : "";

                        const matchesAppId = (normAppId !== "" && normalizeAppId(startupAppId) === normAppId);
                        const matchesUrl = (normUrl !== "" && normalizeUrl(startupUrlStr) === normUrl);

                        if (matchesAppId || matchesUrl) {
                            task.isLaunching = true;
                            launchingTimeoutTimer.restart();
                            break;
                        }
                    }
                }
            }
        }

        function onRowsInserted(parent, first, last) {
            checkStartupRows(first, last);
        }

        function onDataChanged(topLeft, bottomRight, roles) {
            checkStartupRows(topLeft.row, bottomRight.row);
        }
    }

    property bool completed: false
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property var winIdList: {
        if (!task.model || !task.model.WinIdList) return [];
        // Deep copy without slice() just in case
        let list = [];
        let src = task.model.WinIdList;
        for (let i = 0; i < src.length; i++) {
            list.push(src[i]);
        }
        return list;
    }
    property bool wasMiddleClicked: false

    // Media Controller Proxy Properties
    readonly property var mediaController: mediaControllerLoader.item
    readonly property bool playingAudio: mediaController ? mediaController.playingAudio : false
    readonly property bool muted: mediaController ? mediaController.muted : false
    readonly property bool hasAudioStream: mediaController ? mediaController.hasAudioStream : false
    readonly property var audioStreams: mediaController ? mediaController.audioStreams : []
    readonly property var volumeOverlay: taskVolumeOverlayLoader.item

    readonly property bool highlighted: (task.inPopup && activeFocus) ||
        (!task.inPopup && (containsMouse || isHovered)) || (tasksRoot.currentHoveredTask === task) || 
        (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)

    property int itemIndex: index

    property bool isAudioHovered: false
    readonly property bool containsMouse: hoverHandler.hovered || isAudioHovered

    HoverHandler {
        id: hoverHandler
        onPointChanged: {
            if (hovered && tasksRoot.instantHoveredTask === task) {
                const fraction = tasksRoot.vertical ? (point.position.y / height) : (point.position.x / width);
                tasksRoot.instantHoveredFraction = Math.max(0.0, Math.min(1.0, fraction));
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 250 // Time to cross the gap
        onTriggered: {
            if (task.tasksRoot.isTooltipHovered) {
                return;
            }

            if (task.tasksRoot.currentHoveredTask === task) {
                 task.tasksRoot.currentHoveredTask = null;
                 task.tasksRoot.toolTipOpenedByClick = null;
            }
            task.toolTipOpen = false;
        }
    }

    Timer {
        id: launchingTimeoutTimer
        interval: 15000 // 15 seconds
        repeat: false
        onTriggered: task.isLaunching = false
    }

    Timer {
        id: openTimer
        interval: 500
        onTriggered: {
            if (task.containsMouse) {
                task.openTooltip();
            }
        }
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            tasksRoot.instantHoveredTask = task;
            task.forceActiveFocus(Qt.MouseFocusReason);
            closeTimer.stop();
            
            // If tooltip is already visible (switching between tasks), show immediately
            if (tasksRoot.currentHoveredTask && tasksRoot.currentHoveredTask !== task) {
                task.openTooltip();
            } else {
                openTimer.restart();
            }
        } else {
            if (tasksRoot.instantHoveredTask === task) {
                tasksRoot.instantHoveredTask = null;
            }
            openTimer.stop();
            closeTimer.start();
        }
    }

    onXChanged: {
        if (!task.completed) {
            return;
        }
        if (oldX < 0) {
            oldX = x;
            return;
        }
        moveAnim.x = oldX - x + translateTransform.x;
        moveAnim.y = translateTransform.y;
        oldX = x;
        moveAnim.restart();
    }
    onYChanged: {
        if (!task.completed) {
            return;
        }
        if (oldY < 0) {
            oldY = y;
            return;
        }
        moveAnim.y = oldY - y + translateTransform.y;
        moveAnim.x = translateTransform.x;
        oldY = y;
        moveAnim.restart();
    }

    property real oldX: -1
    property real oldY: -1
    SequentialAnimation {
        id: moveAnim
        property real x
        property real y
        onRunningChanged: {
            if (running) {
                ++task.tasksRoot.taskList.animationsRunning;
            } else {
                --task.tasksRoot.taskList.animationsRunning;
            }
        }
        ScriptAction {
            script: {
                translateTransform.x = moveAnim.x;
                translateTransform.y = moveAnim.y;
            }
        }
        PauseAnimation {
            duration: Plasmoid.configuration.smokeExplosionOnClose ? 250 : 0
        }
        ParallelAnimation {
            NumberAnimation {
                target: translateTransform
                properties: "x"
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
            NumberAnimation {
                target: translateTransform
                properties: "y"
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
        }
    }
    transform: Translate {
        id: translateTransform
    }

    Accessible.name: task.model ? task.model.display : ""
    Accessible.description: {
        if (!task.model || !task.model.display) {
            return "";
        }

        if (task.model.IsLauncher) {
            return Wrappers.i18nc("@info:usagetip %1 application name", "Launch %1", task.model.display);
        }

        let smartLauncherDescription = "";
        if (task.model && iconBox.active) {
            smartLauncherDescription += Wrappers.i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.badgeCount);
        }

        if (task.model.IsGroupParent) {
            switch (Plasmoid.configuration.groupedTaskVisualization) {
            case 0:
                break;
            case 1:
                {
                    if (Plasmoid.configuration.showToolTips) {
                        return `${Wrappers.i18nc("@info:usagetip %1 task name", "Show Task tooltip for %1", task.model.display)};
                                ${smartLauncherDescription}`;
                    }
                }
                break;
            case 2:
                {
                    if (tasksRoot.effectWatcher.registered) {
                        return `${Wrappers.i18nc("@info:usagetip %1 task name", "Show windows side by side for %1", task.model.display)};
                                ${smartLauncherDescription}`;
                    }
                }
                break;
            default:
                return `${Wrappers.i18nc("@info:usagetip %1 task name", "Open textual list of windows for %1", task.model.display)};
                        ${smartLauncherDescription}`;
            }
        }

        return `${Wrappers.i18n("Activate %1", task.model.display)};
                ${smartLauncherDescription}`;
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onHighlightedChanged: {
        tasksRoot.cancelHighlightWindows();
    }

    onWinIdListChanged: {
        if (task.winIdList.length > 0) {
            task.isLaunching = false;
            launchingTimeoutTimer.stop();
        }
    }

    onIsWindowChanged: {
        if (task.model && task.model.IsWindow) {
            tasksRoot.taskInitComponent.createObject(task);
        }
    }

    onChildCountChanged: {
        if (task.model && TaskTools.taskManagerInstanceCount < 2 && task.childCount > task.previousChildCount) {
            tasksRoot.tasksModel.requestPublishDelegateGeometry(task.modelIndex(), task.getGlobalRect(), task);
        }

        task.previousChildCount = task.childCount;
    }

    onIndexChanged: {
        if (tasksRoot.currentHoveredTask === task) {
             tasksRoot.currentHoveredTask = null;
        }

        if (!task.inPopup && !tasksRoot.vertical) {
            tasksRoot.requestLayout();
        }
    }





    Keys.onMenuPressed: event => contextMenuTimer.start()
    Keys.onReturnPressed: event => {
        task.triggerLaunch();
        TaskTools.activateTask(task.modelIndex(), task.model, event.modifiers, task, Plasmoid, tasksRoot, tasksRoot.effectWatcher.registered);
    }
    Keys.onEnterPressed: event => Keys.returnPressed(event)
    Keys.onSpacePressed: event => Keys.returnPressed(event)
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)
    Keys.onLeftPressed: event => {
        if (!task.inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksRoot.tasksModel.move(task.index, task.index 
                - 1);
        } else {
            event.accepted = false;
        }
    }
    Keys.onRightPressed: event => {
        if (!task.inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksRoot.tasksModel.move(task.index, task.index + 1);
        } else {
            event.accepted = false;
        }
    }

    function modelIndex(): /*QModelIndex*/ var {
        if (tasksRoot && tasksRoot.filteredTasksModel) {
            const proxyIdx = tasksRoot.filteredTasksModel.index(task.index, 0);
            if (proxyIdx.valid) {
                return tasksRoot.filteredTasksModel.mapToSource(proxyIdx);
            }
        }
        if (tasksRoot && tasksRoot.tasksModel && task.index >= 0) {
            return tasksRoot.tasksModel.makeModelIndex(task.index);
        }
        return undefined;
    }

    function modelRow(): int {
        if (tasksRoot && tasksRoot.filteredTasksModel) {
            const proxyIdx = tasksRoot.filteredTasksModel.index(task.index, 0);
            return tasksRoot.filteredTasksModel.mapToSource(proxyIdx).row;
        }
        return task.index;
    }

    function openTooltip(): void {
        task.tasksRoot.currentHoveredTask = task;
        task.toolTipOpen = true;
        task.tasksRoot.toolTipAreaItem = task;
    }

    function closeTooltip(): void {
        task.toolTipOpen = false;
        
        // Use immediate hide if available to prevent animation from stealing focus
        // qmllint disable missing-property
        if (typeof tasksRoot.hideTooltipImmediately === "function") {
            tasksRoot.hideTooltipImmediately();
        } else {
            tasksRoot.currentHoveredTask = null;
            tasksRoot.toolTipOpenedByClick = null;
        }
        // qmllint enable missing-property
    }

    function showContextMenu(args: var): void {
        task.closeTooltip();
        contextMenu = tasksRoot.createContextMenu(task, task.modelIndex(), args);
        contextMenu.show();
    }

    function toggleMuted(): void {
        if (mediaController) {
            mediaController.toggleMuted();
        }
    }





    Indicators {
        id: indicator
        taskCount: task.childCount
        task: task
        frame: frame
        tasksRoot: task.tasksRoot
        visible: {
            if (!Plasmoid.configuration.indicatorsEnabled || !task.model) return false;
            // Indicators should only be visible for running tasks, not pure launchers
            if (task.taskState === "launcher") return false;
            if (task.model.IsDemandingAttention || task.model.IsActive) return true;
            return !Plasmoid.configuration.disableInactiveIndicators;
        }
        flow: Flow.LeftToRight
        spacing: Kirigami.Units.smallSpacing
        clip: false
    }

    TapHandler {
        id: menuTapHandler
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.TouchScreen |
            PointerDevice.Stylus
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onLongPressed: {
            // When we're a launcher, there's no window controls, so we can show all
            // places without the menu getting super huge.
            if (task.model.IsLauncher) {
                task.showContextMenu({
                    showAllPlaces: true
                });
            } else {
                task.showContextMenu();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse |
            PointerDevice.TouchPad | PointerDevice.Stylus
        gesturePolicy: TapHandler.WithinBounds // Release grab when menu appears
        onPressedChanged: if (pressed)
            contextMenuTimer.start()
    }

    Timer {
        id: contextMenuTimer
        interval: 0
        onTriggered: menuTapHandler.longPressed()
    }

    TapHandler {
        id: leftTapHandler
        acceptedButtons: Qt.LeftButton
        onTapped: leftClick()

        function leftClick(): void {
            task.tasksRoot.currentHoveredTask = null;
            task.triggerLaunch();
            TaskTools.activateTask(task.modelIndex(), task.model, point.modifiers, task, Plasmoid, task.tasksRoot, task.tasksRoot.effectWatcher.registered);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            const tModel = task.tasksRoot.tasksModel;
            const mIndex = task.modelIndex();

            switch (Plasmoid.configuration.middleClickAction) {
                case 1: // Close
                    task.wasMiddleClicked = true;
                    tModel.requestClose(mIndex);
                    break;
                case 2: // NewInstance
                    task.triggerLaunch();
                    tModel.requestNewInstance(mIndex);
                    break;
                case 3: // ToggleMinimized
                    tModel.requestToggleMinimized(mIndex);
                    break;
                case 4: // ToggleGrouping
                    tModel.requestToggleGrouping(mIndex);
                    break;
                case 5: // BringToCurrentDesktop
                    tModel.requestVirtualDesktops(mIndex, [task.tasksRoot.virtualDesktopInfo.currentDesktop]);
                    break;
            }
            task.tasksRoot.cancelHighlightWindows();
        }
    }

    TapHandler {
        acceptedButtons: Qt.BackButton
        onTapped: {
            const playerData = task.tasksRoot.mpris2Source.playerForLauncherUrl(task.model.LauncherUrlWithoutIcon, task.model.AppPid);
            if (playerData) {
                playerData.Previous();
            }
            task.tasksRoot.cancelHighlightWindows();
        }
    }

    TapHandler {
        acceptedButtons: Qt.ForwardButton
        onTapped: {
            const playerData = task.tasksRoot.mpris2Source.playerForLauncherUrl(task.model.LauncherUrlWithoutIcon, task.model.AppPid);
            if (playerData) {
                playerData.Next();
            }
            task.tasksRoot.cancelHighlightWindows();
        }
    }

    KSvg.FrameSvgItem {
        id: frame
        onIsHoveredChanged: {
        }

        Kirigami.ImageColors {
            id: imageColors
            source: task.model.decoration
        }
        property color dominantColor: imageColors.dominant
        property color indicatorColor: Kirigami.ColorUtils.tintWithAlpha(dominantColor, task.tintColor, .38)

        readonly property int _vMargin: (!task.tasksRoot.vertical && task.tasksRoot.taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
        readonly property int _hMargin: ((task.inPopup || task.tasksRoot.vertical) && task.tasksRoot.taskList.columns > 1) ? LayoutMetrics.iconMargin : 0

        anchors {
            fill: parent
            topMargin: _vMargin
            bottomMargin: _vMargin
            leftMargin: _hMargin
            rightMargin: _hMargin
        }

        imagePath: Plasmoid.configuration.disableButtonSvg ? "" : "widgets/tasks"
        enabledBorders: Plasmoid.configuration.useBorders ? 1 | 2 | 4 |
            8 : 0
        property bool isHovered: task.highlighted && Plasmoid.configuration.taskHoverEffect
        
        property string basePrefix: !task.model ? "normal" :
                                    task.model.IsLauncher ? "" :
                                    task.model.IsDemandingAttention ? "attention" :
                                    task.model.IsMinimized ? "minimized" :
                                    task.model.IsActive ? "focus" : "normal"
        
        prefix: isHovered ?
            TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location) : TaskTools.taskPrefix(basePrefix, Plasmoid.location)

        visible: (!task.model || task.model.IsLauncher || task.model.IsDemandingAttention || task.model.IsActive || frame.isHovered) ?
            true : !Plasmoid.configuration.disableButtonInactiveSvg

        layer.enabled: (!task.model || task.model.IsLauncher || !Plasmoid.configuration.buttonColorize) ? false :
                       (task.model.IsDemandingAttention && !frame.isHovered) ? false :
                       (task.model.IsActive || frame.isHovered) ? true :
                       (!Plasmoid.configuration.disableButtonInactiveSvg && Plasmoid.configuration.buttonColorizeInactive)

        layer.effect: MultiEffect {
            brightness: 1.0
            colorization: 1.0
            colorizationColor: Plasmoid.configuration.buttonColorizeDominant ?
                frame.indicatorColor : Plasmoid.configuration.buttonColorizeCustom
        }

        // Avoid repositioning delegate item after dragFinished
        DragHandler {
            id: dragHandler
            grabPermissions: PointerHandler.CanTakeOverFromHandlersOfDifferentType

            function setRequestedInhibitDnd(value: bool): void {
                // This is modifying the value in the panel containment that
                // inhibits accepting drag and drop, so that we don't accidentally
                // drop the task on this panel.
                let item = this;
                while (item.parent) {
                    item = item.parent;
                    if (item.appletRequestsInhibitDnD !== undefined) {
                        item.appletRequestsInhibitDnD = value;
                    }
                }
            }

            onActiveChanged: {
                if (active) {
                        const grabWidth = Math.floor(iconBox.icon.width);
                        const grabHeight = Math.floor(iconBox.icon.height);
                        if (!isFinite(grabWidth) || !isFinite(grabHeight) || grabWidth <= 0 || grabHeight <= 0) {
                            return;
                        }

                        iconBox.icon.grabToImage(result => {
                            if (!dragHandler || !dragHandler.active || !task || !task.tasksRoot || !task.tasksRoot.dragHelper) {
                                return;
                            }
                            setRequestedInhibitDnd(true);
                            task.tasksRoot.dragSource = task;
                            task.tasksRoot.dragHelper.Drag.imageSource = ""; // Reset to prevent engine warnings
                            task.tasksRoot.dragHelper.Drag.imageSource = result.url;
                            
                            task.tasksRoot.dragHelper.Drag.mimeData = {
                                "text/x-orgkdeplasmataskmanager_taskurl": (task.model.LauncherUrlWithoutIcon || "").toString(),
                                [task.model.MimeType]: task.model.MimeData,
                                "application/x-orgkdeplasmataskmanager_taskbuttonitem": task.model.MimeData || "true",
                            };

                            task.tasksRoot.dragHelper.Drag.active = dragHandler.active;
                        }, Qt.size(grabWidth, grabHeight));
                } else {
                    // Before clearing drag state, check if the cursor ended outside the panel.
                    // This is used in main.qml's Drag.onDragFinished as a reliable unpin signal,
                    // because some Plasma components may accept the drag (returning non-IgnoreAction)
                    // even when the user clearly dropped outside the panel area.
                    const isPureLauncher = task.model.IsLauncher && task.winIdList.length === 0;
                    if (Plasmoid.configuration.unpinByDrag && isPureLauncher) {
                        const localPos = task.tasksRoot.mapFromScene(dragHandler.centroid.sceneCentroid);
                        task.tasksRoot.dragEndedOutsidePanel = !task.tasksRoot.contains(localPos);
                    }

                    setRequestedInhibitDnd(false);
                    task.tasksRoot.dragHelper.Drag.active = false;
                    task.tasksRoot.dragHelper.Drag.imageSource = "";
                }
            }
        }
    }

    Loader {
        id: taskProgressOverlayLoader

        anchors.fill: frame
        asynchronous: true
        active: !!(task.model && task.model.IsWindow) && !!(task.model && task.model.Progress > 0) && Plasmoid.configuration.indicatorProgressStyle > 0

        source: "TaskProgressOverlay.qml"
        onLoaded: {
            item.pStyle = Qt.binding(() => Plasmoid.configuration.indicatorProgressStyle);
            item.pColor = Qt.binding(() => Plasmoid.configuration.indicatorProgressColor);
            item.pOpacity = Qt.binding(() => Plasmoid.configuration.indicatorProgressOpacity / 100.0);
            item.pThick = Qt.binding(() => Plasmoid.configuration.indicatorProgressThickness);
            item.pPosition = Qt.binding(() => (task.model?.Progress ?? 0) / 100.0);
            item.panelLocation = Qt.binding(() => Plasmoid.location);
        }
    }

    Loader {
        id: taskVolumeOverlayLoader
        anchors.fill: frame
        active: !Plasmoid.configuration.showMediaControls || !Plasmoid.configuration.showToolTips
        source: "TaskVolumeOverlay.qml"
    }

    Loader {
        id: groupExpanderLoader
        active: Plasmoid.configuration.groupIconEnabled && !task.inPopup && !!task.model && task.model.IsWindow && task.model.IsGroupParent
        sourceComponent: Component {
            GroupExpanderOverlay {
                iconBox: iconBox
                taskModel: task.model
                tasksRoot: task.tasksRoot
                parent: task
            }
        }
    }



    TaskIconBox {
        id: iconBox
        taskItem: task
        tasksRootContext: task.tasksRoot
        labelVisible: label.visible
    }

    Loader {
        id: mediaControllerLoader
        active: !!task.model && task.model.IsWindow
        source: "TaskMediaController.qml"
        onLoaded: {
            item.taskItem = task;
        }
    }

    Loader {
        id: badgeLoader
        parent: task.tasksRoot.iconsOnly ? iconBox : task
        anchors.fill: parent
        active: Plasmoid.configuration.showBadges || task.audioIndicatorsEnabled
        source: "TaskBadgeOverlay.qml"
        onLoaded: {
            item.parentTask = task;
        }
        z: 999
    }

    PlasmaComponents3.Label {
        id: label

        visible: (task.inPopup || !task.tasksRoot.iconsOnly && !task.model.IsLauncher && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= LayoutMetrics.spaceRequiredToShowText())

        anchors {
            fill: parent
            leftMargin: LayoutMetrics.leftMargin() + iconBox.width + LayoutMetrics.labelMargin
            topMargin: LayoutMetrics.topMargin()
            rightMargin: LayoutMetrics.rightMargin()
            bottomMargin: LayoutMetrics.bottomMargin()
        }

        wrapMode: (maximumLineCount === 1) ?
            Text.NoWrap : Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: Plasmoid.configuration.maxTextLines ||
            undefined

        Accessible.ignored: true

        // use State to avoid unnecessary re-evaluation when the label is invisible
        states: State {
            name: "labelVisible"
            when: label.visible

            PropertyChanges {
                label.text: task.model.display
            }
        }
    }


    Component.onCompleted: {
        task.lastSeenCount = task.badgeCount;

        if (!task.inPopup && !task.model.IsWindow) {
            tasksRoot.taskInitComponent.createObject(task);
        }
        task.completed = true;

        if (task.model && task.model.LauncherUrlWithoutIcon) {
            DesktopActionsManager.prefetch(task.model.LauncherUrlWithoutIcon);
        }
    }
    Component.onDestruction: {
        if (moveAnim.running) {
            (task.parent as TaskList).animationsRunning -= 1;
        }
    }
}
