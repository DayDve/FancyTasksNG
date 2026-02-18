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
import Qt5Compat.GraphicalEffects

import "code/layoutmetrics.js" as LayoutMetrics
import "code/tools.js" as TaskTools
import "code/singletones"

Item {
    id: task

    activeFocusOnTab: true

    readonly property bool isMetro: Plasmoid.configuration.indicatorStyle === 0
    readonly property bool isCiliora: Plasmoid.configuration.indicatorStyle === 1
    readonly property bool isDashes: Plasmoid.configuration.indicatorStyle === 2
    readonly property int _cfgIconSize: Plasmoid.configuration.iconSizeOverride ? Plasmoid.configuration.iconSizePx : (Math.min(tasksRoot.width, tasksRoot.height) * Plasmoid.configuration.iconScale / 100)
    readonly property int _cfgZoom: Plasmoid.configuration.iconZoomFactor
    readonly property int _maxIconSize: _cfgIconSize + _cfgZoom
    property alias taskIcon: icon
    readonly property bool iconOverflows: tasksRoot.vertical ? 
        (icon.width > tasksRoot.width) : (icon.height > tasksRoot.height)

    Item {
        id: tooltipAnchor
        anchors.centerIn: parent
        width: task.tasksRoot.vertical ? (Math.max(task.tasksRoot.width, task._maxIconSize)) : parent.width
        height: !task.tasksRoot.vertical ? (Math.max(task.tasksRoot.height, task._maxIconSize)) : parent.height
        visible: false
    }
    property alias tooltipAnchor: tooltipAnchor
    property string tintColor: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark ?
        "#ffffff" : "#000000"

    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ?
        180 : 0

    implicitHeight: task.inPopup ?
        LayoutMetrics.preferredHeightInPopup() : Math.max(tasksRoot.height / Plasmoid.configuration.maxStripes, LayoutMetrics.preferredMinHeight())
    implicitWidth: tasksRoot.vertical ?
        Math.max(LayoutMetrics.preferredMinWidth(), Math.min(LayoutMetrics.preferredMaxWidth(), tasksRoot.width / Plasmoid.configuration.maxStripes)) : 0

    Layout.fillWidth: true
    Layout.fillHeight: !task.inPopup
    Layout.maximumWidth: tasksRoot.vertical ?
        -1 : ((task.model.IsLauncher && !tasksRoot.iconsOnly) ? tasksRoot.height / tasksRoot.taskList.rows : LayoutMetrics.preferredMaxWidth())
    Layout.maximumHeight: tasksRoot.vertical ?
        LayoutMetrics.preferredMaxHeight() : -1

    required property var model
    required property int index
    required property /*main.qml*/  var tasksRoot

    readonly property int pid: task.model.AppPid
    readonly property string appName: task.model.AppName
    readonly property string appId: task.model.AppId.replace(/\.desktop/, '')
    readonly property bool isIcon: tasksRoot.iconsOnly ||
        task.model.IsLauncher
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isWindow: task.model.IsWindow
    property int childCount: task.model.ChildCount
    property int previousChildCount: 0
    property alias labelText: label.text
    property var contextMenu: null
    readonly property bool smartLauncherEnabled: !task.inPopup && !task.model.IsStartup
    property var smartLauncherItem: null

    property Item audioStreamIcon: null
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    property bool completed: false
    readonly property 
        bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool hasAudioStream: task.audioStreams.length > 0
    readonly property bool playingAudio: task.hasAudioStream && task.audioStreams.some(item => !item.corked)
    readonly property bool muted: task.hasAudioStream && task.audioStreams.every(item => item.muted)

    readonly property bool highlighted: (task.inPopup && activeFocus) ||
        (!task.inPopup && containsMouse) || (tasksRoot.currentHoveredTask === task) || 
        (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open) ||
        (!!tasksRoot.groupDialog && tasksRoot.groupDialog.visualParent === task)

    property int itemIndex: task.index 

    readonly property bool containsMouse: hoverHandler.hovered

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
        ParallelAnimation {
            NumberAnimation {
                target: translateTransform
                properties: "x"
                from: moveAnim.x
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
            NumberAnimation {
                target: translateTransform
                properties: "y"
                from: moveAnim.y
                to: 0
                easing.type: Easing.OutQuad
                duration: Kirigami.Units.longDuration
            }
        }
    }
    transform: Translate {
        id: translateTransform
    }

    Accessible.name: task.model.display
    Accessible.description: {
        if (!task.model.display) {
            return "";
        }

        if (task.model.IsLauncher) {
            return Wrappers.i18nc("@info:usagetip %1 application name", "Launch %1", task.model.display);
        }

        let smartLauncherDescription = "";
        if (iconBox.active) {
            smartLauncherDescription += Wrappers.i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.smartLauncherItem.count);
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

    onPidChanged: task.updateAudioStreams({
        delay: false
    })
    onAppNameChanged: task.updateAudioStreams({
        delay: false
    })



    onIsWindowChanged: {
        if (task.model.IsWindow) {
            tasksRoot.taskInitComponent.createObject(task);
            task.updateAudioStreams({
                delay: false
            });
        }
    }

    onChildCountChanged: {
        if (TaskTools.taskManagerInstanceCount < 2 && task.childCount > task.previousChildCount && tasksRoot.backend) {
            tasksRoot.tasksModel.requestPublishDelegateGeometry(task.modelIndex(), tasksRoot.backend.globalRect(task), task);
        }

        task.previousChildCount = task.childCount;
    }

    onIndexChanged: {
        if (tasksRoot.currentHoveredTask === task) {
             tasksRoot.currentHoveredTask = null;
        }

        if (!task.inPopup && !tasksRoot.vertical && !Plasmoid.configuration.separateLaunchers) {
            tasksRoot.requestLayout();
        }
    }

    onSmartLauncherEnabledChanged: {
        if (task.smartLauncherEnabled && !task.smartLauncherItem) {
            let smartLauncher = null;
            try {
                smartLauncher = Qt.createQmlObject('import org.kde.taskmanager; SmartLauncherItem {}', task);
            } catch (e) {
                try {
                    smartLauncher = Qt.createQmlObject('import org.kde.plasma.private.taskmanager; SmartLauncherItem {}', task);
                } catch (e2) {
                     // SmartLauncherItem is optional or not available in this Plasma version
                     // console.warn("Could not create SmartLauncherItem from public or private module");
                     return;
                }
            }

            smartLauncher.launcherUrl = Qt.binding(() => task.model.LauncherUrlWithoutIcon);

            task.smartLauncherItem = smartLauncher;
        }
    }

    onHasAudioStreamChanged: {
        const audioStreamIconActive = task.hasAudioStream && audioIndicatorsEnabled;
        if (!audioStreamIconActive) {
            if (audioStreamIcon !== null) {
                audioStreamIcon.destroy();
                audioStreamIcon = null;
            }
            return;
        }
        // Create item on demand instead of using Loader to reduce memory consumption,
        // because only a few applications have audio streams.
        const component = Qt.createComponent("AudioStream.qml");
        audioStreamIcon = component.createObject(task, {
            "iconBox": iconBox,
            "task": task,
            "frame": frame
        });
        component.destroy();
    }
    onAudioIndicatorsEnabledChanged: task.hasAudioStreamChanged()

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
        return task.inPopup ?
            tasksRoot.tasksModel.makeModelIndex(tasksRoot.groupDialog.visualParent.index, task.index) : tasksRoot.tasksModel.makeModelIndex(task.index);
    }

    function closeTooltip(): void {
        tasksRoot.currentHoveredTask = null;
        task.toolTipOpen = false;
        tasksRoot.toolTipOpenedByClick = null;
        // qmllint disable missing-property
        if (typeof task.hideImmediately === "function") {
            task.hideImmediately();
        }
        // qmllint enable missing-property
    }

    function showContextMenu(args: var): void {
        task.closeTooltip();
        contextMenu = tasksRoot.createContextMenu(task, task.modelIndex(), args);
        contextMenu.show();
    }

    function updateAudioStreams(args: var): void {
        if (args) {
            // When the task just appeared (e.g. virtual desktop switch), show the audio indicator
            // right away.
            // Only when audio streams change during the lifetime of this task, delay
            // showing that to avoid distraction.
            task.delayAudioStreamIndicator = !!args.delay;
        }

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
            task.updateAudioStreams({
                delay: true
            });
        }
    }

    function hexToHSL(hex) {
        var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
        let r = parseInt(result[1], 16);
        let g = parseInt(result[2], 16);
        let b = parseInt(result[3], 16);
        r /= 255;
        g /= 255;
        b /= 255;
        var max = Math.max(r, g, b), min = Math.min(r, g, b);
        var h, s, l = (max + min) / 2;
        if (max == min) {
            h = s = 0;
            // achromatic
        } else {
            var d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            switch (max) {
            case r:
                h = (g - b) / d + (g < b ? 6 : 0);
                break;
            case g:
                h = (b - r) / d + 2;
                break;
            case b:
                h = (r - g) / d + 4;
                break;
            }
            h /= 6;
        }
        var HSL = new Object();
        HSL['h'] = h;
        HSL['s'] = s;
        HSL['l'] = l;
        return HSL;
    }

    ColorOverlay {
        id: colorOverride
        anchors.fill: frame
        source: frame
        color: Plasmoid.configuration.buttonColorizeDominant ?
            frame.indicatorColor : Plasmoid.configuration.buttonColorizeCustom
        visible: Plasmoid.configuration.buttonColorize ?
            true : false
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
        onTapped: (eventPoint, button) => leftClick()

        function leftClick(): void {
            task.tasksRoot.currentHoveredTask = null;
            TaskTools.activateTask(task.modelIndex(), task.model, point.modifiers, task, Plasmoid, task.tasksRoot, task.tasksRoot.effectWatcher.registered);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton |
            Qt.BackButton | Qt.ForwardButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.MiddleButton) {
                if (Plasmoid.configuration.middleClickAction === 2 /* NewInstance */) {
                    task.tasksRoot.tasksModel.requestNewInstance(task.modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === 1 /* Close */) {
                    task.tasksRoot.taskClosedWithMouseMiddleButton = task.model.WinIdList.slice();
                    task.tasksRoot.tasksModel.requestClose(task.modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === 3 /* ToggleMinimized */) {
                    task.tasksRoot.tasksModel.requestToggleMinimized(task.modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === 4 /* ToggleGrouping */) {
                    task.tasksRoot.tasksModel.requestToggleGrouping(task.modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === 5 /* BringToCurrentDesktop */) {
                    task.tasksRoot.tasksModel.requestVirtualDesktops(task.modelIndex(), [task.tasksRoot.virtualDesktopInfo.currentDesktop]);
                }
            } else if (button === Qt.BackButton || button === Qt.ForwardButton) {
                const playerData = task.tasksRoot.mpris2Source.playerForLauncherUrl(task.model.LauncherUrlWithoutIcon, task.model.AppPid);
                if (playerData) {
                    if (button === Qt.BackButton) {
                        playerData.Previous();
                    } else {
                        playerData.Next();
                    }
                } else {
                    eventPoint.accepted = false;
                }
            }

            task.tasksRoot.cancelHighlightWindows();
        }
    }

    KSvg.FrameSvgItem {
        id: frame

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
            TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location) : TaskTools.taskPrefix(basePrefix, Plasmoid.location)

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
                    icon.grabToImage(result => {
                        if (!dragHandler.active) {
                            // BUG 466675 grabToImage is async, so avoid updating dragSource when active is false
                            return;
                        }
                        setRequestedInhibitDnd(true);
                        task.tasksRoot.dragSource = task;
                        task.tasksRoot.dragHelper.Drag.imageSource = result.url;
                        
                        task.tasksRoot.dragHelper.Drag.mimeData = {
                            "text/x-orgkdeplasmataskmanager_taskurl": task.tasksRoot.backend.tryDecodeApplicationsUrl(task.model.LauncherUrlWithoutIcon).toString(),
                            [task.model.MimeType]: task.model.MimeData,
                            "application/x-orgkdeplasmataskmanager_taskbuttonitem": task.model.MimeData
                        };
                        task.tasksRoot.dragHelper.Drag.active = dragHandler.active;
                    });
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
        active: task.model.IsWindow && task.smartLauncherItem && task.smartLauncherItem.progressVisible

        source: "TaskProgressOverlay.qml"
        onLoaded: item.task = task
    }

    Loader {
        id: iconBox

        anchors {
            left: parent.left
            leftMargin: adjustMargin(true, parent.width, task.tasksRoot.taskFrame.margins.left)
            top: parent.top
            topMargin: adjustMargin(false, parent.height, task.tasksRoot.taskFrame.margins.top)
        }

        width: task.inPopup ?
            Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium) : Math.min((task.parent as TaskList)?.minimumWidth ?? 0, task.height)
        height: task.inPopup ?
            width : (parent.height - adjustMargin(false, parent.height, task.tasksRoot.taskFrame.margins.top) - adjustMargin(false, parent.height, task.tasksRoot.taskFrame.margins.bottom))

        asynchronous: true
        active: height >= Kirigami.Units.iconSizes.small && task.smartLauncherItem && task.smartLauncherItem["countVisible"]
        source: "TaskBadgeOverlay.qml"

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
            property int growSize: active ?
                Plasmoid.configuration.iconZoomFactor : 0

            property bool sizeOverride: Plasmoid.configuration.iconSizeOverride
            property int fixedSize: Plasmoid.configuration.iconSizePx
            property real iconScale: Plasmoid.configuration.iconScale / 100
            property bool scaleFromEdge: Plasmoid.configuration.iconScaleFromEdge
            property int edgeOffset: Plasmoid.configuration.iconEdgeOffset

            readonly property int baseWidth: (sizeOverride ? fixedSize : (parent.width * iconScale))
            readonly property int baseHeight: (sizeOverride ? fixedSize : (parent.height * iconScale))
            readonly property real edgeMarginH: scaleFromEdge ? edgeOffset : (parent.width - baseWidth) / 2
            readonly property real edgeMarginV: scaleFromEdge ? edgeOffset : (parent.height - baseHeight) / 2

            width: baseWidth + growSize
            height: baseHeight + growSize

            // Default anchors (fallback/bottom)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: edgeMarginV

            states: [
                State {
                    name: "top"
                    when: Plasmoid.location === PlasmaCore.Types.TopEdge
                    AnchorChanges { target: icon; anchors.top: parent.top; anchors.bottom: undefined; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: undefined; anchors.left: undefined; anchors.right: undefined }
                    PropertyChanges { target: icon; anchors.topMargin: icon.edgeMarginV; anchors.bottomMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                },
                State {
                    name: "left"
                    when: Plasmoid.location === PlasmaCore.Types.LeftEdge
                    AnchorChanges { target: icon; anchors.left: parent.left; anchors.right: undefined; anchors.verticalCenter: parent.verticalCenter; anchors.horizontalCenter: undefined; anchors.top: undefined; anchors.bottom: undefined }
                    PropertyChanges { target: icon; anchors.leftMargin: icon.edgeMarginH; anchors.rightMargin: 0; anchors.topMargin: 0; anchors.bottomMargin: 0 }
                },
                State {
                    name: "right"
                    when: Plasmoid.location === PlasmaCore.Types.RightEdge
                    AnchorChanges { target: icon; anchors.right: parent.right; anchors.left: undefined; anchors.verticalCenter: parent.verticalCenter; anchors.horizontalCenter: undefined; anchors.top: undefined; anchors.bottom: undefined }
                    PropertyChanges { target: icon; anchors.rightMargin: icon.edgeMarginH; anchors.leftMargin: 0; anchors.topMargin: 0; anchors.bottomMargin: 0 }
                },
                State {
                    name: "bottom"
                    when: Plasmoid.location === PlasmaCore.Types.BottomEdge
                    AnchorChanges { target: icon; anchors.bottom: parent.bottom; anchors.top: undefined; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: undefined; anchors.left: undefined; anchors.right: undefined }
                    PropertyChanges { target: icon; anchors.bottomMargin: icon.edgeMarginV; anchors.topMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                }
            ]

            Behavior on growSize {
                NumberAnimation {
                    duration: Plasmoid.configuration.iconZoomDuration
                    easing.type: Easing.InOutQuad
                }
            }
            roundToIconSize: false
            active: task.highlighted
            enabled: true

            source: task.model.decoration

            layer.enabled: task.iconOverflows
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 0
                radius: 12
                samples: 25
                color: Qt.rgba(0, 0, 0, 0.5)
            }
        }

        states: [
            // Using a state transition avoids a binding loop between label.visible and
            // the text label margin, which derives from the icon width.
            State {
                name: "standalone"
                when: !label.visible && task.parent

                AnchorChanges {
                    target: iconBox
                    anchors.left: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                PropertyChanges {
                    target: iconBox
                    anchors.leftMargin: 0
                    width: Math.min((task.parent as TaskList).minimumWidth, task.tasksRoot.height) - adjustMargin(true, task.width, task.tasksRoot.taskFrame.margins.left) - adjustMargin(true, task.width, task.tasksRoot.taskFrame.margins.right)
                }
            }
        ]

        Loader {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            active: task.model.IsStartup
            sourceComponent: task.tasksRoot.busyIndicator
        }
    }

    PlasmaComponents3.Label {
        id: label

        visible: (task.inPopup || !task.tasksRoot.iconsOnly && !task.model.IsLauncher && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= LayoutMetrics.spaceRequiredToShowText())

        anchors {
            fill: parent
            leftMargin: task.tasksRoot.taskFrame.margins.left + iconBox.width + LayoutMetrics.labelMargin
            topMargin: task.tasksRoot.taskFrame.margins.top
            rightMargin: task.tasksRoot.taskFrame.margins.right + (task.audioStreamIcon !== null && task.audioStreamIcon.visible ?
                (task.audioStreamIcon.width + LayoutMetrics.labelMargin) : 0)
            bottomMargin: task.tasksRoot.taskFrame.margins.bottom
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
            when: task.model.IsLauncher === true

            PropertyChanges {
                target: frame
                basePrefix: ""
            }
            PropertyChanges {
                target: colorOverride
                visible: false
            }
        },
        State {
            name: "attention"
            when: task.model.IsDemandingAttention === true ||
                (task.smartLauncherItem && task.smartLauncherItem["urgent"])

            PropertyChanges {
                target: frame
                basePrefix: "attention"
                visible: (Plasmoid.configuration.buttonColorize && !frame.isHovered) ||
                    !Plasmoid.configuration.buttonColorize
            }
            PropertyChanges {
                target: colorOverride
                visible: (Plasmoid.configuration.buttonColorize && frame.isHovered)
            }
        },
        State {
            name: "minimized"
            when: task.model.IsMinimized === true && !frame.isHovered && !Plasmoid.configuration.disableButtonInactiveSvg

            PropertyChanges {
                target: frame
                basePrefix: "minimized"
                visible: (Plasmoid.configuration.buttonColorize && Plasmoid.configuration.buttonColorizeInactive) ?
                    false : true
            }
            PropertyChanges {
                target: colorOverride
                visible: (Plasmoid.configuration.buttonColorize && Plasmoid.configuration.buttonColorizeInactive) ?
                    true : false
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
                visible: Plasmoid.configuration.disableButtonInactiveSvg ?
                    false : true
            }
            PropertyChanges {
                target: colorOverride
                visible: Plasmoid.configuration.disableButtonInactiveSvg ?
                    false : true
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
            }
            PropertyChanges {
                target: colorOverride
                visible: Plasmoid.configuration.buttonColorize ?
                    true : false
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
                target: colorOverride
                visible: Plasmoid.configuration.buttonColorize && Plasmoid.configuration.buttonColorizeInactive ?
                    true : false
            }
            PropertyChanges {
                target: frame
                visible: Plasmoid.configuration.buttonColorize && Plasmoid.configuration.buttonColorizeInactive ?
                    false : true
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
                target: colorOverride
                visible: Plasmoid.configuration.disableButtonInactiveSvg ?
                    false : true
            }
            PropertyChanges {
                target: frame
                visible: Plasmoid.configuration.disableButtonInactiveSvg ?
                    false : true
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
                target: colorOverride
                visible: Plasmoid.configuration.buttonColorize ?
                    true : false
            }
            PropertyChanges {
                target: frame
                visible: Plasmoid.configuration.buttonColorize ?
                    false : true
            }
            PropertyChanges {
                target: indicator
                visible: Plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        }
    ]

    Component.onCompleted: {
        if (!task.inPopup && task.model.IsWindow) {
            if (Plasmoid.configuration.groupIconEnabled) {
                const component = Qt.createComponent("GroupExpanderOverlay.qml");
                component.createObject(task, {
                    "iconBox": iconBox,
                    "taskModel": task.model
                });
                component.destroy();
            }
            task.updateAudioStreams({
                delay: false
            });
        }

        if (!task.inPopup && !task.model.IsWindow) {
            tasksRoot.taskInitComponent.createObject(task);
        }
        task.completed = true;
    }
    Component.onDestruction: {
        if (moveAnim.running) {
            (task.parent as TaskList).animationsRunning -= 1;
        }
    }
}
