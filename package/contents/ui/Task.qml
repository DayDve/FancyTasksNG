/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2022-2025 Luis Bocanegra <luisbocanegra17b@gmail.com>
    SPDX-FileCopyrightText: 2025 SushiTrash <namanrajhans@gmail.com>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Nate Graham <nate@nate.org>
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

import "code/layoutmetrics.js" as LayoutMetrics
import "code/tools.js" as TaskTools
import "code/singletones"

Item {
    id: task
    readonly property alias frame: backgroundFrame
    z: highlighted ? 10 : (badgeVisible || playingAudio || muted) ? 1 : 0

    // Cached properties for optimization
    readonly property var config: task.tasksRoot.config
    // The edge buttons face, which a floating widget can override.
    readonly property int location: task.tasksRoot ? task.tasksRoot.effectiveLocation : Plasmoid.location

    // False for a task that is only shown, as in the settings preview: it
    // then takes no input and no keyboard focus.
    property bool interactive: true
    activeFocusOnTab: interactive
    opacity: tasksRoot.dragSource === task ? 0.5 : 1.0
    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.shortDuration }
    }

    readonly property int _cfgIconSize: task.config.iconSizeOverride ? task.config.iconSizePx : (Math.min(tasksRoot.width, tasksRoot.height) * task.config.iconScale / 100)
    readonly property int _cfgZoom: (tasksRoot.iconsOnly && task.config.taskHoverEffect) ? task.config.iconZoomFactor : 0
    readonly property int _maxIconSize: _cfgIconSize + _cfgZoom
    property alias taskIcon: taskIconBox.icon
    readonly property bool iconOverflows: tasksRoot.vertical ? 
        (taskIcon.width > tasksRoot.width) : (taskIcon.height > tasksRoot.height)

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

    rotation: (tasksRoot && task.config.reverseMode && tasksRoot.vertical) ?
        180 : 0

    implicitHeight: {
        if (!tasksRoot) return 0;
        if (tasksRoot.vertical) {
            if (task.isIcon) {
                let cols = (tasksRoot.taskList && tasksRoot.taskList.columns > 0) ? tasksRoot.taskList.columns : (task.config.maxStripes || 1);
                return (tasksRoot.width / cols) + LayoutMetrics.verticalMargins(task.tasksRoot);
            }
            return LayoutMetrics.preferredMaxHeight(task.tasksRoot);
        } else {
            let stripes = task.config.maxStripes || 1;
            if (task.isIcon) {
                let rws = (tasksRoot.taskList && tasksRoot.taskList.rows > 0) ? tasksRoot.taskList.rows : stripes;
                return (tasksRoot.height / rws) + LayoutMetrics.verticalMargins(task.tasksRoot);
            }
            return Math.max(tasksRoot.height / stripes, LayoutMetrics.preferredMinHeight(task.tasksRoot));
        }
    }
    implicitWidth: {
        if (!tasksRoot) return 0;
        if (tasksRoot.vertical) {
            let stripes = task.config.maxStripes || 1;
            if (task.isIcon) {
                let cols = (tasksRoot.taskList && tasksRoot.taskList.columns > 0) ? tasksRoot.taskList.columns : stripes;
                return (tasksRoot.width / cols) + LayoutMetrics.horizontalMargins(task.tasksRoot);
            }
            return Math.max(LayoutMetrics.preferredMinWidth(task.tasksRoot), Math.min(LayoutMetrics.preferredMaxWidth(task.tasksRoot), tasksRoot.width / stripes));
        } else {
            if (task.isIcon) {
                let rws = (tasksRoot.taskList && tasksRoot.taskList.rows > 0) ? tasksRoot.taskList.rows : (task.config.maxStripes || 1);
                return (tasksRoot.height / rws) + LayoutMetrics.horizontalMargins(task.tasksRoot);
            }
            return task.classicButtonWidth;
        }
    }

    // Every button gets the full max width, like the classic taskbar, unless
    // "fit to title" is on: then icon + title, kept within [min, max].
    readonly property real classicButtonWidth: {
        const maxWidth = LayoutMetrics.preferredMaxWidth(task.tasksRoot);
        // An elided title's widest line is shorter than the room it had, so
        // fitting to it would cut the title off before the max width.
        if (!task.config.fitButtonToText || titleMeasure.truncated)
            return maxWidth;
        const contentWidth = task.labelChromeWidth + Math.ceil(titleMeasure.contentWidth);
        return Math.min(maxWidth, Math.max(task.config.minFitButtonLength, contentWidth));
    }
    // Mirrors the icon-to-title gap after a fitted title: the frame's right
    // margin scales with iconSpacing and is 0 when that's 0, which would leave
    // the title touching the button's edge. Reserved in the label itself, not
    // just added to the width, so it survives the clamp to the max width.
    readonly property real trailingLabelGap: task.config.fitButtonToText ? LayoutMetrics.labelMargin : 0
    readonly property real labelChromeWidth: LayoutMetrics.leftMargin(task.tasksRoot) + taskIconBox.height + LayoutMetrics.labelMargin + LayoutMetrics.rightMargin(task.tasksRoot) + task.trailingLabelGap

    // Lays the title out exactly like the label would at the max width
    // (same wrapping, line limit and height), so contentWidth is the widest
    // line after wrapping - a two-line title fits to its longer line, not to
    // its single-line length. Kept separate from the label, which only gets
    // its text once it's wide enough to be shown. Narrowing the label down
    // to that width doesn't change where the lines break.
    Text {
        id: titleMeasure
        visible: false
        width: Math.max(0, LayoutMetrics.preferredMaxWidth(task.tasksRoot) - task.labelChromeWidth)
        height: label.height
        font: label.font
        text: task.config.fitButtonToText && task.model ? (task.model.display || "") : ""
        textFormat: Text.PlainText
        wrapMode: label.wrapMode
        maximumLineCount: label.maximumLineCount
        elide: Text.ElideRight
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.maximumWidth: (!tasksRoot || tasksRoot.vertical) ?
        -1 : ((task.model?.IsLauncher && !tasksRoot.iconsOnly) ? (tasksRoot.height / tasksRoot.taskList.rows) + LayoutMetrics.horizontalMargins(task.tasksRoot) : (tasksRoot.iconsOnly ? LayoutMetrics.preferredMaxWidth(task.tasksRoot) : task.classicButtonWidth))
    Layout.maximumHeight: (!tasksRoot || !tasksRoot.vertical) ?
        -1 : ((task.model?.IsLauncher && !tasksRoot.iconsOnly) ? (tasksRoot.width / tasksRoot.taskList.columns) + LayoutMetrics.verticalMargins(task.tasksRoot) : LayoutMetrics.preferredMaxHeight(task.tasksRoot))

    required property var model
    required property int index
    property /*main.qml*/  var tasksRoot

    readonly property int pid: (task.model && task.model.AppPid) ? task.model.AppPid : 0
    readonly property string appName: (task.model && task.model.AppName) ? task.model.AppName : ""
    readonly property string appId: (task.model && task.model.AppId) ? task.model.AppId.replace(/\.desktop/, '') : ""
    readonly property bool isIcon: task.model ? (tasksRoot.iconsOnly || !!task.model.IsLauncher) : tasksRoot.iconsOnly
    readonly property bool toolTipOpen: tasksRoot.currentHoveredTask === task

    property bool isWindow: !!(task.model && task.model.IsWindow)
    readonly property bool isHovered: tasksRoot.mouseHandler.hoveredItem === task
    
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
    property var contextMenu: null
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
    
    // Settable, like the media state below, so the settings preview can show
    // a task without a real app behind it.
    property int badgeCount: {
        if (!task.model) return 0;
        return (BadgeManager.countVersion >= 0) ? BadgeManager.getUnreadCount(task.model.AppId, task.model.AppPid) : 0;
    }
    
    property real taskProgress: {
        if (!task.model) return -1.0;
        return (BadgeManager.countVersion >= 0) ? BadgeManager.getProgress(task.model.AppId, task.model.AppPid) : -1.0;
    }
    readonly property bool badgeVisible: {
        if (badgeCount <= 0) return false;
        if (!task.config.showBadgesOnLaunchers && task.winIdList.length === 0) {
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
        if (!task) return Qt.rect(0, 0, 0, 0);
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


    property bool completed: false
    // The audio mark, the count and progress all hide with "Show app signals".
    readonly property bool audioIndicatorsEnabled: task.config.showAppSignals && task.config.indicateAudioStreams
    readonly property bool countEnabled: task.config.showAppSignals && task.config.showBadges
    property var winIdList: {
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
    property bool playingAudio: mediaController ? mediaController.playingAudio : false
    property bool muted: mediaController ? mediaController.muted : false
    property bool hasAudioStream: mediaController ? mediaController.hasAudioStream : false
    readonly property var audioStreams: mediaController ? mediaController.audioStreams : []
    readonly property var volumeOverlay: taskVolumeOverlayLoader.item

    readonly property bool highlighted: containsMouse || isHovered || (tasksRoot.currentHoveredTask === task) || 
        (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)


    readonly property bool isBadgeHovered: badgeLoader.item ? (badgeLoader.item as TaskBadgeOverlay).hovered : false
    readonly property bool containsMouse: task.interactive && (hoverHandler.hovered || isBadgeHovered)

    HoverHandler {
        enabled: task.interactive
        id: hoverHandler
        onPointChanged: {
            if (hovered && task.tasksRoot.instantHoveredTask === task) {
                let fraction;
                if (task.tasksRoot.vertical) {
                    const rawFraction = point.position.y / task.height;
                    fraction = task.config.reverseMode ? (1.0 - rawFraction) : rawFraction;
                } else {
                    const rawFraction = point.position.x / task.width;
                    const mirrored = task.tasksRoot.shouldBeMirrored(task.config.reverseMode, Qt.locale().textDirection, task.tasksRoot.vertical);
                    fraction = mirrored ? (1.0 - rawFraction) : rawFraction;
                }
                task.tasksRoot.instantHoveredFraction = Math.max(0.0, Math.min(1.0, fraction));
            }
        }
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

    Timer {
        id: switchTimer
        interval: 150 // Small delay to allow diagonal movement without aggressive tooltip switching
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
            
            // If tooltip is already visible (switching between tasks), delay slightly to allow diagonal movement
            if (tasksRoot.currentHoveredTask && tasksRoot.currentHoveredTask !== task) {
                switchTimer.restart();
            } else {
                openTimer.restart();
            }
        } else {
            if (tasksRoot.instantHoveredTask === task) {
                tasksRoot.instantHoveredTask = null;
            }
            openTimer.stop();
            switchTimer.stop();
        }
    }

    onXChanged: {
        if (!task.completed) {
            return;
        }
        if (oldX < 0) {
            oldX = x;
            oldXIndex = index;
            return;
        }
        // With fitted widths a button also moves whenever a title before it
        // changes length; sliding then would make it overlap that neighbor
        // mid-animation on every title update, so only slide on a reorder.
        const reordered = index !== oldXIndex;
        oldXIndex = index;
        if (!reordered && task.config.fitButtonToText && !task.tasksRoot.iconsOnly) {
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
    property int oldXIndex: -1
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
            duration: (task.tasksRoot.iconsOnly && task.config.smokeExplosionOnClose) ? 250 : 0
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

        // Matches what a click does (tools.js activateTask): the group
        // tooltip opens on click even with hover tooltips off, and without
        // the window view effect the text list is shown instead.
        const badgeDescription = task.badgeVisible
            ? Wrappers.i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.badgeCount) : "";
        let action = Wrappers.i18n("Activate %1", task.model.display);

        if (task.model.IsGroupParent) {
            switch (task.config.groupedTaskVisualization) {
            case 0:
                break;
            case 1:
                action = Wrappers.i18nc("@info:usagetip %1 task name", "Show Task tooltip for %1", task.model.display);
                break;
            case 2:
                if (tasksRoot.effectWatcher.registered) {
                    action = Wrappers.i18nc("@info:usagetip %1 task name", "Show windows side by side for %1", task.model.display);
                    break;
                }
                // fallthrough
            default:
                action = Wrappers.i18nc("@info:usagetip %1 task name", "Open textual list of windows for %1", task.model.display);
            }
        }

        return badgeDescription ? `${action}; ${badgeDescription}` : action;
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onHighlightedChanged: {
        tasksRoot.cancelHighlightWindows();
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

        if (!tasksRoot.vertical) {
            tasksRoot.requestLayout();
        }
    }


    Keys.onMenuPressed: event => contextMenuTimer.start()
    Keys.onReturnPressed: event => {
        TaskTools.activateTask(task.modelIndex(), task.model, event.modifiers, task, Plasmoid, tasksRoot, tasksRoot.effectWatcher.registered);
    }
    Keys.onEnterPressed: event => Keys.returnPressed(event)
    Keys.onSpacePressed: event => Keys.returnPressed(event)
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)
    Keys.onLeftPressed: event => {
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            task.moveBy(-1);
        } else {
            event.accepted = false;
        }
    }
    Keys.onRightPressed: event => {
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            task.moveBy(1);
        } else {
            event.accepted = false;
        }
    }

    // Delegate rows are rows of the shown, possibly filtered, model, while
    // TasksModel.move() takes rows of the unfiltered one.
    function moveBy(delta: int): void {
        const proxy = tasksRoot.filteredTasksModel;
        const from = proxy.mapToSource(proxy.index(task.index, 0));
        const target = task.index + delta;
        const to = proxy.mapToSource(proxy.index(target, 0));
        if (from.valid && to.valid) {
            tasksRoot.tasksModel.move(from.row, to.row);
            tasksRoot.focusTaskAt(target);
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


    function openTooltip(byClick = false): void {
        if (!task.config.enableToolTips)
            return;
        if (task.config.hideLauncherToolTips && task.model?.IsLauncher)
            return;
        task.tasksRoot.showTooltip(task, byClick);
    }

    // For when something in the tooltip was acted on: see main.dismissTooltip().
    function closeTooltip(): void {
        task.tasksRoot.dismissTooltip();
    }

    function showContextMenu(args: var): void {
        task.closeTooltip();
        contextMenu = tasksRoot.createContextMenu(task, task.modelIndex(), args);
        contextMenu.show();
    }

    function toggleMuted(): void {
        if (task.mediaController) {
            task.mediaController.toggleMuted();
        }
    }


    Indicators {
        id: indicator
        taskCount: task.childCount
        taskItem: task
        frameSvgItem: backgroundFrame
        tasksRoot: task.tasksRoot
        visible: {
            if (!task.config.indicatorsEnabled || !task.model) return false;
            // Indicators should only be visible for running tasks, not pure launchers
            if (task.taskState === "launcher") return false;
            return true;
        }
        flow: Flow.LeftToRight
        spacing: Kirigami.Units.smallSpacing
        clip: false
    }

    TapHandler {
        enabled: task.interactive
        id: menuTapHandler
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.TouchScreen |
            PointerDevice.Stylus
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onLongPressed: task.showContextMenu()
    }

    TapHandler {
        enabled: task.interactive
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
        enabled: task.interactive
        id: leftTapHandler
        acceptedButtons: Qt.LeftButton
        onTapped: leftClick()

        function leftClick(): void {
            task.tasksRoot.currentHoveredTask = null;
            TaskTools.activateTask(task.modelIndex(), task.model, point.modifiers, task, Plasmoid, task.tasksRoot, task.tasksRoot.effectWatcher.registered);
        }
    }

    TapHandler {
        enabled: task.interactive
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            const tModel = task.tasksRoot.tasksModel;
            const mIndex = task.modelIndex();

            switch (task.config.middleClickAction) {
                case 1: // Close
                    task.wasMiddleClicked = true;
                    tModel.requestClose(mIndex);
                    break;
                case 2: // NewInstance
                    TaskTools.claimLaunch(tModel, mIndex, Plasmoid.id);
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
        enabled: task.interactive
        acceptedButtons: Qt.BackButton
        onTapped: {
            const playerData = task.tasksRoot.mediaRegistry.playerFor(task.model.LauncherUrlWithoutIcon, task.model.AppPid);
            if (playerData) {
                playerData.Previous();
            }
            task.tasksRoot.cancelHighlightWindows();
        }
    }

    TapHandler {
        enabled: task.interactive
        acceptedButtons: Qt.ForwardButton
        onTapped: {
            const playerData = task.tasksRoot.mediaRegistry.playerFor(task.model.LauncherUrlWithoutIcon, task.model.AppPid);
            if (playerData) {
                playerData.Next();
            }
            task.tasksRoot.cancelHighlightWindows();
        }
    }

    KSvg.FrameSvgItem {
        id: backgroundFrame

        Kirigami.ImageColors {
            id: imageColors
            source: task.model.decoration
        }
        property color dominantColor: imageColors.dominant
        property color indicatorColor: Kirigami.ColorUtils.tintWithAlpha(dominantColor, task.tintColor, .38)

        readonly property int _vMargin: (!task.tasksRoot.vertical && task.tasksRoot.taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
        readonly property int _hMargin: (task.tasksRoot.vertical && task.tasksRoot.taskList.columns > 1) ? LayoutMetrics.iconMargin : 0

        anchors {
            fill: parent
            topMargin: _vMargin
            bottomMargin: _vMargin
            leftMargin: _hMargin
            rightMargin: _hMargin
        }

        imagePath: task.config.disableButtonSvg ? "" : "widgets/tasks"
        enabledBorders: task.config.useBorders ? 1 | 2 | 4 | 8 : 0
        // Hover effects are an icons-only feature; a classic panel always
        // shows the theme's hover state, as Plasma's own task manager does.
        property bool isHovered: task.highlighted && (!task.tasksRoot.iconsOnly || task.config.taskHoverEffect)
        
        property string basePrefix: !task.model ? "normal" :
                                    task.model.IsLauncher ? "" :
                                    task.model.IsDemandingAttention ? "attention" :
                                    task.model.IsMinimized ? "minimized" :
                                    task.model.IsActive ? "focus" : "normal"
        
        prefix: isHovered ?
            TaskTools.taskPrefixHovered(basePrefix, task.location) : TaskTools.taskPrefix(basePrefix, task.location)

        visible: (!task.model || task.model.IsLauncher || task.model.IsDemandingAttention || task.model.IsActive || backgroundFrame.isHovered) ?
            true : !task.config.disableButtonInactiveSvg

        layer.enabled: (!task.model || task.model.IsLauncher) ? false :
                       (task.model.IsDemandingAttention && task.config.attentionCustomColorEnabled) ? true :
                       (!task.config.buttonColorize) ? false :
                       (task.model.IsDemandingAttention && !backgroundFrame.isHovered) ? false :
                       (task.model.IsActive || backgroundFrame.isHovered) ? true :
                       (!task.config.disableButtonInactiveSvg && task.config.buttonColorizeInactive)

        layer.effect: MultiEffect {
            brightness: 1.0
            colorization: 1.0
            colorizationColor: (task.model.IsDemandingAttention && task.config.attentionCustomColorEnabled) ?
                task.config.attentionCustomColor :
                (task.config.buttonColorizeDominant ? backgroundFrame.indicatorColor : task.config.buttonColorizeCustom)
        }

        // Avoid repositioning delegate item after dragFinished
        DragHandler {
            enabled: task.interactive
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
                        const grabWidth = Math.floor(task.taskIcon.width);
                        const grabHeight = Math.floor(task.taskIcon.height);
                        if (!isFinite(grabWidth) || !isFinite(grabHeight) || grabWidth <= 0 || grabHeight <= 0) {
                            return;
                        }

                        task.taskIcon.grabToImage(result => {
                            if (!dragHandler || !dragHandler.active || !task || !task.tasksRoot || !task.tasksRoot.dragHelper) {
                                return;
                            }
                            setRequestedInhibitDnd(true);
                            task.tasksRoot.dragSource = task;
                            task.tasksRoot.dragHelper.Drag.imageSource = ""; // Reset to prevent engine warnings
                            task.tasksRoot.dragHelper.Drag.imageSource = result.url;
                            
                            let mime = {
                                "text/x-orgkdeplasmataskmanager_taskurl": (task.model.LauncherUrlWithoutIcon || "").toString(),
                                "application/x-orgkdeplasmataskmanager_taskbuttonitem": task.model.MimeData || "true",
                            };
                            // Without the file URL a launcher being dragged off to be
                            // unpinned can't be dropped as a .desktop file elsewhere.
                            const unpinnable = task.config.unpinByDrag && task.model.IsLauncher && task.winIdList.length === 0;
                            if (!unpinnable && task.model.MimeType && task.model.MimeData) {
                                mime[task.model.MimeType] = task.model.MimeData;
                            }
                            task.tasksRoot.dragHelper.Drag.mimeData = mime;

                            task.tasksRoot.dragHelper.Drag.active = dragHandler.active;
                        }, Qt.size(grabWidth, grabHeight));
                } else {
                    setRequestedInhibitDnd(false);
                    task.tasksRoot.dragHelper.Drag.active = false;
                    task.tasksRoot.dragHelper.Drag.imageSource = "";
                }
            }
        }
    }

    Loader {
        id: taskProgressOverlayLoader

        anchors.fill: backgroundFrame
        asynchronous: true
        active: !!(task.model && task.model.IsWindow) && task.taskProgress >= 0 && task.config.showAppSignals && task.config.indicatorProgressStyle > 0

        source: "TaskProgressOverlay.qml"
        onLoaded: {
            item.pStyle = Qt.binding(() => task.config.indicatorProgressStyle);
            item.pColor = Qt.binding(() => task.config.indicatorProgressColor);
            item.pOpacity = Qt.binding(() => task.config.indicatorProgressOpacity / 100.0);
            item.pThick = Qt.binding(() => task.config.indicatorProgressThickness);
            item.pPosition = Qt.binding(() => task.taskProgress);
            item.panelLocation = Qt.binding(() => task.location);
        }
    }

    Loader {
        id: taskVolumeOverlayLoader
        anchors.fill: backgroundFrame
        asynchronous: true
        active: task.hasAudioStream
        source: "TaskVolumeOverlay.qml"
    }

    Loader {
        id: groupExpanderLoader
        asynchronous: true
        active: task.config.groupIconEnabled && !!task.model && task.model.IsWindow && task.model.IsGroupParent
        sourceComponent: Component {
            GroupExpanderOverlay {
                iconBox: taskIconBox
                taskModel: task.model
                tasksRoot: task.tasksRoot
                parent: task
            }
        }
    }

    TaskIconBox {
        id: taskIconBox
        taskItem: task
        tasksRootContext: task.tasksRoot
        labelVisible: label.visible
    }

    Loader {
        id: mediaControllerLoader
        asynchronous: true
        active: !!task.model && task.model.IsWindow && !!task.tasksRoot.mediaRegistry
        source: "TaskMediaController.qml"
        onLoaded: {
            item.taskItem = task;
        }
    }

    Loader {
        id: badgeLoader
        anchors.fill: parent
        asynchronous: true
        active: (task.countEnabled && task.badgeVisible) || (task.audioIndicatorsEnabled && (task.playingAudio || task.muted))
        z: 999
        sourceComponent: TaskBadgeOverlay {
            button: taskIconBox.boxRect
            zoom: taskIconBox.zoom
            maxZoom: taskIconBox.maxZoom
            vertical: task.tasksRoot.vertical
            location: task.tasksRoot.effectiveLocation
            highlighted: task.highlighted
            dotMode: task.config.badgeDotMode
            dotThreshold: task.config.badgeDotThreshold
            colorMode: task.config.badgeColorMode
            customColor: task.config.badgeCustomColor
            audioVisible: task.audioIndicatorsEnabled && (task.playingAudio || task.muted)
            muted: task.muted
            countVisible: task.countEnabled && task.badgeVisible
            count: task.badgeCount
            urgent: (task.config.badgeHighlightNew && task.hasUnseenNotifications) || !!task.model?.IsDemandingAttention
            onMuteToggled: task.toggleMuted()
        }
    }

    PlasmaComponents3.Label {
        id: label

        visible: !task.tasksRoot.iconsOnly && !task.model.IsLauncher && (parent.width - taskIconBox.height - Kirigami.Units.smallSpacing) >= LayoutMetrics.spaceRequiredToShowText(task.tasksRoot)

        anchors {
            fill: parent
            leftMargin: LayoutMetrics.leftMargin(task.tasksRoot) + taskIconBox.width + LayoutMetrics.labelMargin
            topMargin: LayoutMetrics.topMargin(task.tasksRoot)
            rightMargin: LayoutMetrics.rightMargin(task.tasksRoot) + task.trailingLabelGap
            bottomMargin: LayoutMetrics.bottomMargin(task.tasksRoot)
        }

        wrapMode: (maximumLineCount === 1) ?
            Text.NoWrap : Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: task.config.maxTextLines ||
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

        task.completed = true;

        if (task.model && task.model.LauncherUrlWithoutIcon) {
            // Same parameters ContextMenu.query() will use, so the prefetched cache entry actually hits
            DesktopActionsManager.prefetch(task.model.LauncherUrlWithoutIcon,
                task.model.AppPid,
                DesktopActionsManager.shouldShowHistory(task.model.AppPid, task.config.showBrowserHistory),
                task.config.browserHistoryLimit);
        }
    }
    Component.onDestruction: {
        // Same counter moveAnim incremented; task.parent may already be
        // gone while the delegate is being destroyed.
        if (moveAnim.running && task.tasksRoot && task.tasksRoot.taskList) {
            task.tasksRoot.taskList.animationsRunning -= 1;
        }
    }
}
