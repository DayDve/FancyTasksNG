/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
// import org.kde.plasma.private.taskmanager as TaskManagerApplet
import org.kde.plasma.plasmoid
import QtQuick.Effects

import "code/layoutmetrics.js" as LayoutMetrics
import "code/tools.js" as TaskTools
import "code/singletones"

Item {
    id: task
    z: highlighted ? 10 : 0

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
    property alias taskIcon: icon
    readonly property bool iconOverflows: tasksRoot.vertical ? 
        (icon.width > tasksRoot.width) : (icon.height > tasksRoot.height)

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

    rotation: Plasmoid.configuration.reverseMode && tasksRoot.vertical ?
        180 : 0

    implicitHeight: task.inPopup ? LayoutMetrics.preferredHeightInPopup() : (
        tasksRoot.vertical ? LayoutMetrics.preferredMaxHeight() : Math.max(tasksRoot.height / Plasmoid.configuration.maxStripes, LayoutMetrics.preferredMinHeight())
    )
    implicitWidth: tasksRoot.vertical ? (
        Math.max(LayoutMetrics.preferredMinWidth(), Math.min(LayoutMetrics.preferredMaxWidth(), tasksRoot.width / Plasmoid.configuration.maxStripes))
    ) : LayoutMetrics.preferredMaxWidth()

    Layout.fillWidth: true
    Layout.fillHeight: !task.inPopup
    Layout.maximumWidth: tasksRoot.vertical ?
        -1 : ((task.model?.IsLauncher && !tasksRoot.iconsOnly) ? (tasksRoot.height / tasksRoot.taskList.rows) + LayoutMetrics.horizontalMargins() : LayoutMetrics.preferredMaxWidth())
    Layout.maximumHeight: tasksRoot.vertical ?
        ((task.model?.IsLauncher && !tasksRoot.iconsOnly) ? (tasksRoot.width / tasksRoot.taskList.columns) + LayoutMetrics.verticalMargins() : LayoutMetrics.preferredMaxHeight()) : -1

    required property var model
    required property int index
    required property /*main.qml*/  var tasksRoot

    readonly property int pid: (task.model && task.model.AppPid) ? task.model.AppPid : 0
    readonly property string appName: (task.model && task.model.AppName) ? task.model.AppName : ""
    readonly property string appId: (task.model && task.model.AppId) ? task.model.AppId.replace(/\.desktop/, '') : ""
    readonly property bool isIcon: task.model ? (tasksRoot.iconsOnly || !!task.model.IsLauncher) : tasksRoot.iconsOnly
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isStartup: !!(task.model && task.model.IsStartup)
    property bool isWindow: !!(task.model && task.model.IsWindow)
    readonly property bool isHovered: (tasksRoot && tasksRoot.mouseHandler) ? (tasksRoot.mouseHandler.hoveredItem === task) : false
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
    
    function getGlobalRect() {
        if (!icon) return Qt.rect(0, 0, 0, 0);
        var p = icon.mapToGlobal(0, 0);
        return Qt.rect(p.x, p.y, icon.width, icon.height);
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

    property var audioStreams: []
    property bool completed: false
    readonly property 
        bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool hasAudioStream: task.audioStreams.length > 0
    readonly property bool playingAudio: task.hasAudioStream && task.audioStreams.some(item => !item.corked)
    readonly property var winIdList: (task.model && task.model.WinIdList) ? task.model.WinIdList.slice() : []
    property bool wasMiddleClicked: false
    readonly property bool muted: task.hasAudioStream && task.audioStreams.every(item => item.muted)

    readonly property bool highlighted: (task.inPopup && activeFocus) ||
        (!task.inPopup && (containsMouse || isHovered)) || (tasksRoot.currentHoveredTask === task) || 
        (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)

    property int itemIndex: index

    property bool isAudioHovered: false
    readonly property bool containsMouse: hoverHandler.hovered || isAudioHovered

    HoverHandler {
        id: hoverHandler
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
        id: openTimer
        interval: 500
        onTriggered: {
            if (task.containsMouse) {
                task.tasksRoot.currentHoveredTask = task;
                task.toolTipOpen = true;
                task.tasksRoot.toolTipAreaItem = task;
            }
        }
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            task.forceActiveFocus(Qt.MouseFocusReason);
            closeTimer.stop();
            
            // If tooltip is already visible (switching between tasks), show immediately
            if (tasksRoot.currentHoveredTask !== null && tasksRoot.currentHoveredTask !== task) {
                tasksRoot.currentHoveredTask = task;
                task.toolTipOpen = true;
                tasksRoot.toolTipAreaItem = task;
            } else {
                openTimer.restart();
            }
        } else {
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
        // ensure it doesn't get stuck with a window highlighted
        tasksRoot.cancelHighlightWindows();
    }

    onPidChanged: task.updateAudioStreams()
    onAppNameChanged: task.updateAudioStreams()



    onIsWindowChanged: {
        if (task.model.IsWindow) {
            tasksRoot.taskInitComponent.createObject(task);
            task.updateAudioStreams();
        }
    }

    onChildCountChanged: {
        if (TaskTools.taskManagerInstanceCount < 2 && task.childCount > task.previousChildCount) {
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
    Keys.onReturnPressed: event => TaskTools.activateTask(task.modelIndex(), task.model, event.modifiers, task, Plasmoid, tasksRoot, tasksRoot.effectWatcher.registered)
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
            return tasksRoot.filteredTasksModel.mapToSource(proxyIdx);
        }
        return tasksRoot.tasksModel.makeModelIndex(task.index);
    }

    function modelRow(): int {
        if (tasksRoot && tasksRoot.filteredTasksModel) {
            const proxyIdx = tasksRoot.filteredTasksModel.index(task.index, 0);
            return tasksRoot.filteredTasksModel.mapToSource(proxyIdx).row;
        }
        return task.index;
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

    function updateAudioStreams(): void {
        var pa = task.tasksRoot.pulseAudio.item;
        if (!pa || !task.isWindow) {
            task.audioStreams = [];
            return;
        }

        // Check appid first for app using portal
        // https://docs.pipewire.org/page_portal.html
        var streams = pa.streamsForAppId(task.appId);
        if (!streams.length) {
            streams = pa.streamsForPid(task.model.AppPid);
            
            if (!streams.length) {
                 // Fallback to appName if no PID match found
                 // Note: This might cause issues with multiple instances if they don't support PID matching,
                 // but without the complex caching logic (which was unreliable), this is the best effort.
                 streams = pa.streamsForAppName(task.model.AppName);
            }
        }

        task.audioStreams = streams;
    }

    function toggleMuted(): void {
        if (task.muted) {
            task.audioStreams.forEach(item => item.unmute());
        } else {
            task.audioStreams.forEach(item => item.mute());
        }
    }

    Connections {
        target: task.tasksRoot.pulseAudio.item
        ignoreUnknownSignals: true // Plasma-PA might not be available
        function onStreamsChanged(): void {
            task.updateAudioStreams();
        }
    }





    Indicators {
        id: indicator
        taskCount: task.childCount
        task: task
        frame: frame
        visible: Plasmoid.configuration.indicatorsEnabled ?
            true : false
        flow: Flow.LeftToRight
        spacing: Kirigami.Units.smallSpacing
        clip: true
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
            TaskTools.activateTask(task.modelIndex(), task.model, point.modifiers, task, Plasmoid, task.tasksRoot, task.tasksRoot.effectWatcher.registered);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            if (Plasmoid.configuration.middleClickAction === 2 /* NewInstance */) {
                task.tasksRoot.tasksModel.requestNewInstance(task.modelIndex());
            } else if (Plasmoid.configuration.middleClickAction === 1 /* Close */) {
                task.wasMiddleClicked = true;
                task.tasksRoot.tasksModel.requestClose(task.modelIndex());
            } else if (Plasmoid.configuration.middleClickAction === 3 /* ToggleMinimized */) {
                task.tasksRoot.tasksModel.requestToggleMinimized(task.modelIndex());
            } else if (Plasmoid.configuration.middleClickAction === 4 /* ToggleGrouping */) {
                task.tasksRoot.tasksModel.requestToggleGrouping(task.modelIndex());
            } else if (Plasmoid.configuration.middleClickAction === 5 /* BringToCurrentDesktop */) {
                task.tasksRoot.tasksModel.requestVirtualDesktops(task.modelIndex(), [task.tasksRoot.virtualDesktopInfo.currentDesktop]);
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

        anchors {
            fill: parent

            topMargin: (!task.tasksRoot.vertical && task.tasksRoot.taskList.rows > 1) ?
                LayoutMetrics.iconMargin : 0
            bottomMargin: (!task.tasksRoot.vertical && task.tasksRoot.taskList.rows > 1) ?
                LayoutMetrics.iconMargin : 0
            leftMargin: ((task.inPopup || task.tasksRoot.vertical) && task.tasksRoot.taskList.columns > 1) ?
                LayoutMetrics.iconMargin : 0
            rightMargin: ((task.inPopup || task.tasksRoot.vertical) && task.tasksRoot.taskList.columns > 1) ?
                LayoutMetrics.iconMargin : 0
        }

        imagePath: Plasmoid.configuration.disableButtonSvg ?
            "" : "widgets/tasks"
        enabledBorders: Plasmoid.configuration.useBorders ? 1 | 2 | 4 |
            8 : 0
        property bool isHovered: task.highlighted && Plasmoid.configuration.taskHoverEffect
        property string basePrefix: "normal"
        prefix: isHovered ?
            TaskTools.taskPrefixHovered(basePrefix, tasks.effectiveLocation) : TaskTools.taskPrefix(basePrefix, tasks.effectiveLocation)

        layer.enabled: false
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
                        const grabWidth = Math.floor(icon.width);
                        const grabHeight = Math.floor(icon.height);
                        if (!isFinite(grabWidth) || !isFinite(grabHeight) || grabWidth <= 0 || grabHeight <= 0) {
                            return;
                        }

                        icon.grabToImage(result => {
                            if (!dragHandler || !dragHandler.active || !task || !task.tasksRoot || !task.tasksRoot.dragHelper) {
                                return;
                            }
                            setRequestedInhibitDnd(true);
                            task.tasksRoot.dragSource = task;
                            task.tasksRoot.dragHelper.Drag.imageSource = ""; // Reset to prevent engine warnings
                            task.tasksRoot.dragHelper.Drag.imageSource = result.url;
                            
                            let data = {
                                "text/x-orgkdeplasmataskmanager_taskurl": (task.model.LauncherUrlWithoutIcon || "").toString()
                            };

                            const mimeType = task.model.MimeType;
                            const mimeData = task.model.MimeData;

                            if (mimeType && mimeData !== undefined && mimeData !== null) {
                                data[mimeType] = mimeData;
                            }

                            if (mimeData !== undefined && mimeData !== null) {
                                data["application/x-orgkdeplasmataskmanager_taskbuttonitem"] = mimeData;
                            } else {
                                // Provide a dummy value for internal identification if model data is missing
                                data["application/x-orgkdeplasmataskmanager_taskbuttonitem"] = "true";
                            }

                            task.tasksRoot.dragHelper.Drag.mimeData = data;
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
            item.panelLocation = Qt.binding(() => tasks.effectiveLocation);
        }
    }

    Loader {
        id: groupExpanderLoader
        active: Plasmoid.configuration.groupIconEnabled && !task.inPopup && !!task.model && task.model.IsWindow && task.model.IsGroupParent
        sourceComponent: Component {
            GroupExpanderOverlay {
                iconBox: iconBox
                taskModel: task.model
                parent: task
            }
        }
    }



    Item {
        id: iconBox

        anchors {
            fill: tasksRoot.iconsOnly ? parent : undefined
            left: tasksRoot.iconsOnly ? undefined : parent.left
            top: tasksRoot.iconsOnly ? undefined : parent.top
            bottom: tasksRoot.iconsOnly ? undefined : parent.bottom
            leftMargin: adjustMargin(true, tasksRoot.iconsOnly ? parent.width : parent.height, LayoutMetrics.leftMargin())
            topMargin: adjustMargin(false, parent.height, LayoutMetrics.topMargin())
            rightMargin: tasksRoot.iconsOnly ? adjustMargin(true, parent.width, LayoutMetrics.rightMargin()) : 0
            bottomMargin: adjustMargin(false, parent.height, LayoutMetrics.bottomMargin())
        }
        width: tasksRoot.iconsOnly ? undefined : height

        property int growSize: ((task.containsMouse || (tasksRoot.currentHoveredTask === task && tasksRoot.isTooltipHovered) || (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)) && tasksRoot.iconsOnly && Plasmoid.configuration.taskHoverEffect) ?
            Plasmoid.configuration.iconZoomFactor : 0

        Behavior on growSize {
            NumberAnimation {
                duration: Plasmoid.configuration.iconZoomDuration
                easing.type: Easing.InOutQuad
            }
        }

        // Unified transform for jump and zoom
        transform: [
            Translate {
                id: attentionTranslate
                y: 0
            },
            Scale {
                id: zoomScale
                // To keep the margin constant, the origin must be at the icon's edge nearest to the panel
                origin.x: {
                    if (Plasmoid.configuration.iconScaleFromEdge) {
                        if (tasks.effectiveLocation === PlasmaCore.Types.LeftEdge) return icon.anchors.leftMargin;
                        if (tasks.effectiveLocation === PlasmaCore.Types.RightEdge) return iconBox.width - icon.anchors.rightMargin;
                    }
                    return iconBox.width / 2;
                }
                origin.y: {
                    if (Plasmoid.configuration.iconScaleFromEdge) {
                        if (tasks.effectiveLocation === PlasmaCore.Types.TopEdge) return icon.anchors.topMargin;
                        if (tasks.effectiveLocation === PlasmaCore.Types.BottomEdge) return iconBox.height - icon.anchors.bottomMargin;
                    }
                    return iconBox.height / 2;
                }
                xScale: 1 + (iconBox.growSize / Math.max(1, iconBox.height))
                yScale: xScale
            }
        ]

        SequentialAnimation {
            id: attentionAnimation
            running: task.model && task.model.IsDemandingAttention && tasksRoot.iconsOnly && Plasmoid.configuration.animateAttentionStatus && !task.highlighted
            loops: Animation.Infinite
            onRunningChanged: if (!running) attentionTranslate.y = 0

            NumberAnimation {
                target: attentionTranslate
                property: "y"
                to: -Kirigami.Units.gridUnit / 3.5
                duration: 300
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: attentionTranslate
                property: "y"
                to: 0
                duration: 400
                easing.type: Easing.OutBounce
            }
            PauseAnimation {
                duration: 1500
            }
        }

        function adjustMargin(isVertical: bool, size: real, margin: real): real {
            if (!size) {
                return margin;
            }

            var margins = isVertical ? LayoutMetrics.horizontalMargins() : LayoutMetrics.verticalMargins();
            if ((size - margins) < Kirigami.Units.iconSizes.small) {
                return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
            }

            return margin;
        }

        Kirigami.Icon {
            id: icon
            
            property bool sizeOverride: Plasmoid.configuration.iconSizeOverride
            property int fixedSize: Plasmoid.configuration.iconSizePx
            property real iconScale: Plasmoid.configuration.iconScale / 100
            property bool scaleFromEdge: Plasmoid.configuration.iconScaleFromEdge
            property int edgeOffset: Plasmoid.configuration.iconEdgeOffset

            readonly property int baseWidth: (sizeOverride ? fixedSize : (parent.width * iconScale))
            readonly property int baseHeight: (sizeOverride ? fixedSize : (parent.height * iconScale))
            readonly property real edgeMarginH: scaleFromEdge ? edgeOffset : (parent.width - baseWidth) / 2
            readonly property real edgeMarginV: scaleFromEdge ? edgeOffset : (parent.height - baseHeight) / 2

            // Icon size is now stable, the container scales instead
            width: baseWidth
            height: baseHeight

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: edgeMarginV

            states: [
                State {
                    name: "top"
                    when: tasks.effectiveLocation === PlasmaCore.Types.TopEdge
                    AnchorChanges { target: icon; anchors.top: parent.top; anchors.bottom: undefined; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: undefined; anchors.left: undefined; anchors.right: undefined }
                    PropertyChanges { target: icon; anchors.topMargin: icon.edgeMarginV; anchors.bottomMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                },
                State {
                    name: "left"
                    when: tasks.effectiveLocation === PlasmaCore.Types.LeftEdge
                    AnchorChanges { target: icon; anchors.left: parent.left; anchors.right: undefined; anchors.verticalCenter: parent.verticalCenter; anchors.horizontalCenter: undefined; anchors.top: undefined; anchors.bottom: undefined }
                    PropertyChanges { target: icon; anchors.leftMargin: icon.edgeMarginH; anchors.rightMargin: 0; anchors.topMargin: 0; anchors.bottomMargin: 0 }
                },
                State {
                    name: "right"
                    when: tasks.effectiveLocation === PlasmaCore.Types.RightEdge
                    AnchorChanges { target: icon; anchors.right: parent.right; anchors.left: undefined; anchors.verticalCenter: parent.verticalCenter; anchors.horizontalCenter: undefined; anchors.top: undefined; anchors.bottom: undefined }
                    PropertyChanges { target: icon; anchors.rightMargin: icon.edgeMarginH; anchors.leftMargin: 0; anchors.topMargin: 0; anchors.bottomMargin: 0 }
                },
                State {
                    name: "bottom"
                    when: tasks.effectiveLocation === PlasmaCore.Types.BottomEdge
                    AnchorChanges { target: icon; anchors.bottom: parent.bottom; anchors.top: undefined; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: undefined; anchors.left: undefined; anchors.right: undefined }
                    PropertyChanges { target: icon; anchors.bottomMargin: icon.edgeMarginV; anchors.topMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                }
            ]

            roundToIconSize: false
            active: task.highlighted
            enabled: true

            source: task.model.decoration
            layer.enabled: task.iconOverflows
        }

        MultiEffect {
            anchors.fill: icon
            source: icon
            visible: task.iconOverflows
            shadowEnabled: true
            shadowBlur: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            autoPaddingEnabled: true
        }

        Loader {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            active: !!(task.model && task.model.IsStartup)
            sourceComponent: task.tasksRoot.busyIndicator
        }

        states: [
            State {
                name: "standalone"
                when: !label.visible && task.parent
                AnchorChanges { target: iconBox; anchors.left: undefined; anchors.horizontalCenter: parent.horizontalCenter }
                PropertyChanges {
                    target: iconBox; anchors.leftMargin: 0
                    width: (task.model.IsLauncher && !tasksRoot.iconsOnly) ? (task.parent as TaskList).minimumWidth :
                        Math.min((task.parent as TaskList).minimumWidth, task.tasksRoot.height) - adjustMargin(true, task.width, task.tasksRoot.taskFrame.margins.left) - adjustMargin(true, task.width, task.tasksRoot.taskFrame.margins.right)
                }
            }
        ]
    }

    // Loader for Icons-Only mode: inside iconBox so badges scale and move with the icon
    Loader {
        id: iconsOnlyBadgeLoader
        parent: iconBox
        anchors.fill: parent
        active: task.tasksRoot.iconsOnly && (plasmoid.configuration.showBadges || audioIndicatorsEnabled)
        source: "TaskBadgeOverlay.qml"
        onLoaded: {
            item.parentTask = task;
        }
        z: 999
    }

    // Loader for Classic mode: in root Item to align with wide button edges
    Loader {
        id: classicBadgeLoader
        anchors.fill: parent
        active: !task.tasksRoot.iconsOnly && (plasmoid.configuration.showBadges || audioIndicatorsEnabled)
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
                target: label
                text: task.model.display
            }
        }
    }

    states: [
        State {
            name: "launcher"
            when: task.model && task.model.IsLauncher === true

            PropertyChanges {
                target: frame
                basePrefix: ""
                visible: true
                layer.enabled: false
            }
        },
        State {
            name: "attention"
            when: (task.model && task.model.IsDemandingAttention === true)

            PropertyChanges {
                target: frame
                basePrefix: "attention"
                visible: true
                layer.enabled: (Plasmoid.configuration.buttonColorize && frame.isHovered)
            }
        },
        State {
            name: "minimized"
            when: task.model && task.model.IsMinimized === true && !frame.isHovered && !Plasmoid.configuration.disableButtonInactiveSvg

            PropertyChanges {
                target: frame
                basePrefix: "minimized"
                visible: true
                layer.enabled: (Plasmoid.configuration.buttonColorize && Plasmoid.configuration.buttonColorizeInactive)
            }
            PropertyChanges {
                target: indicator
                visible: Plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        },
        State {
            name: "minimizedNodecoration"
            when: (task.model.IsMinimized === true && !frame.isHovered) && Plasmoid.configuration.disableButtonInactiveSvg

            PropertyChanges {
                target: frame
                basePrefix: "minimized"
                visible: false
                layer.enabled: false
            }
            PropertyChanges {
                target: indicator
                visible: Plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        },
        State {
            name: "active"
            when: task.model.IsActive === true

            PropertyChanges {
                target: frame
                basePrefix: "focus"
                visible: true
                layer.enabled: Plasmoid.configuration.buttonColorize
            }
            PropertyChanges {
                target: indicator
                visible: Plasmoid.configuration.indicatorsEnabled ?
                    true : false
            }
        },
        State {
            name: "inactive"
            when: task.model.IsActive === false && !frame.isHovered && !Plasmoid.configuration.disableButtonInactiveSvg
            PropertyChanges {
                target: frame
                visible: true
                layer.enabled: Plasmoid.configuration.buttonColorize && Plasmoid.configuration.buttonColorizeInactive
            }
            PropertyChanges {
                target: indicator
                visible: Plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        },
        State {
            name: "inactiveNoDecoration"
            when: (task.model.IsActive === false && !frame.isHovered) && Plasmoid.configuration.disableButtonInactiveSvg
            PropertyChanges {
                target: frame
                visible: false
                layer.enabled: false
            }
            PropertyChanges {
                target: indicator
                visible: Plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        },
        State {
            name: "hover"
            when: frame.isHovered
            PropertyChanges {
                target: frame
                visible: true
                layer.enabled: Plasmoid.configuration.buttonColorize
            }
            PropertyChanges {
                target: indicator
                visible: Plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        }
    ]

    Component.onCompleted: {
        task.lastSeenCount = task.badgeCount;
        if (!task.inPopup && task.model.IsWindow) {
            task.updateAudioStreams();
        }

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
