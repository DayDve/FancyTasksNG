/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

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
import org.kde.plasma.private.taskmanager as TaskManagerApplet
import org.kde.plasma.plasmoid
import Qt5Compat.GraphicalEffects

import "code/layoutmetrics.js" as LayoutMetrics
import "code/tools.js" as TaskTools

Item {
    id: task

    activeFocusOnTab: true

    readonly property bool isMetro: plasmoid.configuration.indicatorStyle === 0
    readonly property bool isCiliora: plasmoid.configuration.indicatorStyle === 1
    readonly property bool isDashes: plasmoid.configuration.indicatorStyle === 2
    readonly property int _cfgIconSize: plasmoid.configuration.iconSizeOverride ? plasmoid.configuration.iconSizePx : (Math.min(tasksRoot.width, tasksRoot.height) * plasmoid.configuration.iconScale / 100)
    readonly property int _cfgZoom: plasmoid.configuration.iconZoomFactor
    readonly property int _maxIconSize: _cfgIconSize + _cfgZoom
    property alias taskIcon: icon
    readonly property bool iconOverflows: tasksRoot.vertical ? 
        (icon.width > tasksRoot.width) : (icon.height > tasksRoot.height)

    Item {
        id: tooltipAnchor
        anchors.centerIn: parent
        width: tasksRoot.vertical ? (Math.max(tasksRoot.width, _maxIconSize) + 16) : parent.width
        height: !tasksRoot.vertical ? (Math.max(tasksRoot.height, _maxIconSize) + 16) : parent.height
        visible: false
    }
    property alias tooltipAnchor: tooltipAnchor
    property string tintColor: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark ?
        "#ffffff" : "#000000"

    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ?
        180 : 0

    implicitHeight: inPopup ?
        LayoutMetrics.preferredHeightInPopup() : Math.max(tasksRoot.height / tasksRoot.plasmoid.configuration.maxStripes, LayoutMetrics.preferredMinHeight())
    implicitWidth: tasksRoot.vertical ?
        Math.max(LayoutMetrics.preferredMinWidth(), Math.min(LayoutMetrics.preferredMaxWidth(), tasksRoot.width / tasksRoot.plasmoid.configuration.maxStripes)) : 0

    Layout.fillWidth: true
    Layout.fillHeight: !inPopup
    Layout.maximumWidth: tasksRoot.vertical ?
        -1 : ((model.IsLauncher && !tasks.iconsOnly) ? tasksRoot.height / taskList.rows : LayoutMetrics.preferredMaxWidth())
    Layout.maximumHeight: tasksRoot.vertical ?
        LayoutMetrics.preferredMaxHeight() : -1

    required property var model
    required property int index
    required property /*main.qml*/  Item tasksRoot

    readonly property int pid: model.AppPid
    readonly property string appName: model.AppName
    readonly property string appId: model.AppId.replace(/\.desktop/, '')
    readonly property bool isIcon: tasksRoot.iconsOnly ||
        model.IsLauncher
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isWindow: model.IsWindow
    property int childCount: model.ChildCount
    property int previousChildCount: 0
    property alias labelText: label.text
    property QtObject contextMenu: null
    readonly property bool smartLauncherEnabled: !inPopup && !model.IsStartup
    property QtObject smartLauncherItem: null

    property Item audioStreamIcon: null
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    property bool completed: false
    readonly property 
        bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    readonly property bool highlighted: (inPopup && activeFocus) ||
        (!inPopup && containsMouse) || (tasksRoot.currentHoveredTask === task) || 
        (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open) ||
        (!!tasksRoot.groupDialog && tasksRoot.groupDialog.visualParent === task)

    property int itemIndex: index 

    readonly property bool containsMouse: hoverHandler.hovered

    HoverHandler {
        id: hoverHandler
    }

    Timer {
        id: closeTimer
        interval: 250 // Time to cross the gap
        onTriggered: {
            if (tasksRoot.isTooltipHovered) {
                return;
            }

            if (tasksRoot.currentHoveredTask === task) {
                 tasksRoot.currentHoveredTask = null;
                 tasksRoot.toolTipOpenedByClick = null;
            }
            task.toolTipOpen = false;
        }
    }

    Timer {
        id: openTimer
        interval: 500
        onTriggered: {
            if (task.containsMouse) {
                tasksRoot.currentHoveredTask = task;
                task.toolTipOpen = true;
                tasksRoot.toolTipAreaItem = task;
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
        if (!completed) {
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
        if (!completed) {
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
                ++task.parent.animationsRunning;
            } else {
                --task.parent.animationsRunning;
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

    Accessible.name: model.display
    Accessible.description: {
        if (!model.display) {
            return "";
        }

        if (model.IsLauncher) {
            return i18nc("@info:usagetip %1 application name", "Launch %1", model.display);
        }

        let smartLauncherDescription = "";
        if (iconBox.active) {
            smartLauncherDescription += i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.smartLauncherItem.count);
        }

        if (model.IsGroupParent) {
            switch (Plasmoid.configuration.groupedTaskVisualization) {
            case 0:
                break;
            // Use the default description
            case 1:
                {
                    if (Plasmoid.configuration.showToolTips) {
                        return `${i18nc("@info:usagetip %1 task name", "Show Task tooltip for %1", model.display)};
                                ${smartLauncherDescription}`;
                    }
                    // fallthrough
                }
            case 2:
                {
                    if (effectWatcher.registered) {
                        return `${i18nc("@info:usagetip %1 task name", "Show windows side by side for %1", model.display)};
                                ${smartLauncherDescription}`;
                    }
                    // fallthrough
                }
            default:
                return `${i18nc("@info:usagetip %1 task name", "Open textual list of windows for %1", model.display)};
                        ${smartLauncherDescription}`;
            }
        }

        return `${i18n("Activate %1", model.display)};
                ${smartLauncherDescription}`;
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onHighlightedChanged: {
        // ensure it doesn't get stuck with a window highlighted
        tasksRoot.cancelHighlightWindows();
    }

    onPidChanged: updateAudioStreams({
        delay: false
    })
    onAppNameChanged: updateAudioStreams({
        delay: false
    })

    onIsWindowChanged: {
        if (model.IsWindow) {
            taskInitComponent.createObject(task);
            updateAudioStreams({
                delay: false
            });
        }
    }

    onChildCountChanged: {
        if (TaskTools.taskManagerInstanceCount < 2 && childCount > previousChildCount) {
            tasksModel.requestPublishDelegateGeometry(modelIndex(), backend.globalRect(task), task);
        }

        previousChildCount = childCount;
    }

    onIndexChanged: {
        if (tasksRoot.currentHoveredTask === task) {
             tasksRoot.currentHoveredTask = null;
        }

        if (!inPopup && !tasksRoot.vertical && !Plasmoid.configuration.separateLaunchers) {
            tasksRoot.requestLayout();
        }
    }

    onSmartLauncherEnabledChanged: {
        if (smartLauncherEnabled && !smartLauncherItem) {
            const component = Qt.createComponent("org.kde.plasma.private.taskmanager", "SmartLauncherItem");
            const smartLauncher = component.createObject(task);
            component.destroy();

            smartLauncher.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);

            smartLauncherItem = smartLauncher;
        }
    }

    onHasAudioStreamChanged: {
        const audioStreamIconActive = hasAudioStream && audioIndicatorsEnabled;
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
        audioStreamIcon = component.createObject(task);
        component.destroy();
    }
    onAudioIndicatorsEnabledChanged: task.hasAudioStreamChanged()

    Keys.onMenuPressed: event => contextMenuTimer.start()
    Keys.onReturnPressed: event => TaskTools.activateTask(modelIndex(), model, event.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered)
    Keys.onEnterPressed: event => Keys.returnPressed(event)
    Keys.onSpacePressed: event => Keys.returnPressed(event)
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)
    Keys.onLeftPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index 
                - 1);
        } else {
            event.accepted = false;
        }
    }
    Keys.onRightPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index + 1);
        } else {
            event.accepted = false;
        }
    }

    function modelIndex(): /*QModelIndex*/ var {
        return inPopup ?
            tasksModel.makeModelIndex(groupDialog.visualParent.index, index) : tasksModel.makeModelIndex(index);
    }

    function closeTooltip(): void {
        tasksRoot.currentHoveredTask = null;
        task.toolTipOpen = false;
        tasksRoot.toolTipOpenedByClick = null;
        if (typeof task.hideImmediately === "function") {
            task.hideImmediately();
        }
    }

    function showContextMenu(args: var): void {
        task.closeTooltip();
        contextMenu = tasksRoot.createContextMenu(task, modelIndex(), args);
        contextMenu.show();
    }

    function updateAudioStreams(args: var): void {
        if (args) {
            // When the task just appeared (e.g. virtual desktop switch), show the audio indicator
            // right away.
            // Only when audio streams change during the lifetime of this task, delay
            // showing that to avoid distraction.
            delayAudioStreamIndicator = !!args.delay;
        }

        var pa = pulseAudio.item;
        if (!pa || !task.isWindow) {
            task.audioStreams = [];
            return;
        }

        // Check appid first for app using portal
        // https://docs.pipewire.org/page_portal.html
        var streams = pa.streamsForAppId(task.appId);
        if (!streams.length) {
            streams = pa.streamsForPid(model.AppPid);
            if (streams.length) {
                pa.registerPidMatch(model.AppName);
            } else {
                // We only want to fall back to appName matching if we never managed to map
                // a PID to an audio stream window.
                // Otherwise if you have two instances of
                // an application, one playing and the other not, it will look up appName
                // for the non-playing instance and erroneously show an indicator on both.
                if (!pa.hasPidMatch(model.AppName)) {
                    streams = pa.streamsForAppName(model.AppName);
                }
            }
        }

        task.audioStreams = streams;
    }

    function toggleMuted(): void {
        if (muted) {
            task.audioStreams.forEach(item => item.unmute());
        } else {
            task.audioStreams.forEach(item => item.mute());
        }
    }

    Connections {
        target: pulseAudio.item
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
        r /= 255, g /= 255, b /= 255;
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
        color: plasmoid.configuration.buttonColorizeDominant ?
            frame.indicatorColor : plasmoid.configuration.buttonColorizeCustom
        visible: plasmoid.configuration.buttonColorize ?
            true : false
    }

    Indicators {
        id: indicator
        taskCount: task.childCount
        visible: plasmoid.configuration.indicatorsEnabled ?
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
            if (model.IsLauncher) {
                showContextMenu({
                    showAllPlaces: true
                });
            } else {
                showContextMenu();
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
            tasksRoot.currentHoveredTask = null;
            TaskTools.activateTask(modelIndex(), model, point.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton |
            Qt.BackButton | Qt.ForwardButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.MiddleButton) {
                if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.NewInstance) {
                    tasksModel.requestNewInstance(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.Close) {
                    tasksRoot.taskClosedWithMouseMiddleButton = model.WinIdList.slice();
                    tasksModel.requestClose(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleMinimized) {
                    tasksModel.requestToggleMinimized(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleGrouping) {
                    tasksModel.requestToggleGrouping(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.BringToCurrentDesktop) {
                    tasksModel.requestVirtualDesktops(modelIndex(), [virtualDesktopInfo.currentDesktop]);
                }
            } else if (button === Qt.BackButton || button === Qt.ForwardButton) {
                const playerData = mpris2Source.playerForLauncherUrl(model.LauncherUrlWithoutIcon, model.AppPid);
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

            backend.cancelHighlightWindows();
        }
    }

    KSvg.FrameSvgItem {
        id: frame

        Kirigami.ImageColors {
            id: imageColors
            source: model.decoration
        }
        property color dominantColor: imageColors.dominant
        property color indicatorColor: Kirigami.ColorUtils.tintWithAlpha(frame.dominantColor, tintColor, .38)

        anchors {
            fill: parent

            topMargin: (!tasksRoot.vertical && taskList.rows > 1) ?
                LayoutMetrics.iconMargin : 0
            bottomMargin: (!tasksRoot.vertical && taskList.rows > 1) ?
                LayoutMetrics.iconMargin : 0
            leftMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ?
                LayoutMetrics.iconMargin : 0
            rightMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ?
                LayoutMetrics.iconMargin : 0
        }

        imagePath: plasmoid.configuration.disableButtonSvg ?
            "" : "widgets/tasks"
        enabledBorders: plasmoid.configuration.useBorders ? 1 | 2 | 4 |
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
                        tasksRoot.dragSource = task;
                        dragHelper.Drag.imageSource = result.url;
                        
                        dragHelper.Drag.mimeData = {
                            "text/x-orgkdeplasmataskmanager_taskurl": backend.tryDecodeApplicationsUrl(model.LauncherUrlWithoutIcon).toString(),
                            [model.MimeType]: model.MimeData,
                            "application/x-orgkdeplasmataskmanager_taskbuttonitem": model.MimeData
                        };
                        dragHelper.Drag.active = dragHandler.active;
                    });
                } else {
                    setRequestedInhibitDnd(false);
                    dragHelper.Drag.active = false;
                    dragHelper.Drag.imageSource = "";
                }
            }
        }
    }

    Loader {
        id: taskProgressOverlayLoader

        anchors.fill: frame
        asynchronous: true
        active: model.IsWindow && task.smartLauncherItem && task.smartLauncherItem.progressVisible

        source: "TaskProgressOverlay.qml"
    }

    Loader {
        id: iconBox

        anchors {
            left: parent.left
            leftMargin: adjustMargin(true, parent.width, taskFrame.margins.left)
            top: parent.top
            topMargin: adjustMargin(false, parent.height, taskFrame.margins.top)
        }

        width: task.inPopup ?
            Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium) : Math.min(task.parent?.minimumWidth ?? 0, task.height)
        height: task.inPopup ?
            width : (parent.height - adjustMargin(false, parent.height, taskFrame.margins.top) - adjustMargin(false, parent.height, taskFrame.margins.bottom))

        asynchronous: true
        active: height >= Kirigami.Units.iconSizes.small && task.smartLauncherItem && task.smartLauncherItem.countVisible
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
                plasmoid.configuration.iconZoomFactor : 0

            property bool sizeOverride: plasmoid.configuration.iconSizeOverride
            property int fixedSize: plasmoid.configuration.iconSizePx
            property real iconScale: plasmoid.configuration.iconScale / 100

            width: (sizeOverride ? fixedSize : (parent.width * iconScale)) + growSize
            height: (sizeOverride ? fixedSize : (parent.height * iconScale)) + growSize

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: (parent.height - (sizeOverride ? fixedSize : (parent.height * iconScale))) / 2

            Behavior on growSize {
                NumberAnimation {
                    duration: plasmoid.configuration.iconZoomDuration
                    easing.type: Easing.InOutQuad
                }
            }
            roundToIconSize: growSize === 0
            active: task.highlighted
            enabled: true

            source: model.decoration
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
                    width: Math.min(task.parent.minimumWidth, tasks.height) - adjustMargin(true, task.width, taskFrame.margins.left) - adjustMargin(true, task.width, taskFrame.margins.right)
                }
            }
        ]

        Loader {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            active: model.IsStartup
            sourceComponent: busyIndicator
        }
    }

    PlasmaComponents3.Label {
        id: label

        visible: (inPopup || !iconsOnly && !model.IsLauncher && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= LayoutMetrics.spaceRequiredToShowText())

        anchors {
            fill: parent
            leftMargin: taskFrame.margins.left + iconBox.width + LayoutMetrics.labelMargin
            topMargin: taskFrame.margins.top
            rightMargin: taskFrame.margins.right + (audioStreamIcon !== null && audioStreamIcon.visible ?
                (audioStreamIcon.width + LayoutMetrics.labelMargin) : 0)
            bottomMargin: taskFrame.margins.bottom
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
                text: model.display
            }
        }
    }

    states: [
        State {
            name: "launcher"
            when: model.IsLauncher === true

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
            when: model.IsDemandingAttention === true ||
                (task.smartLauncherItem && task.smartLauncherItem.urgent)

            PropertyChanges {
                target: frame
                basePrefix: "attention"
                visible: (plasmoid.configuration.buttonColorize && !frame.isHovered) ||
                    !plasmoid.configuration.buttonColorize
            }
            PropertyChanges {
                target: colorOverride
                visible: (plasmoid.configuration.buttonColorize && frame.isHovered)
            }
        },
        State {
            name: "minimized"
            when: model.IsMinimized === true && !frame.isHovered && !plasmoid.configuration.disableButtonInactiveSvg

            PropertyChanges {
                target: frame
                basePrefix: "minimized"
                visible: (plasmoid.configuration.buttonColorize && plasmoid.configuration.buttonColorizeInactive) ?
                    false : true
            }
            PropertyChanges {
                target: colorOverride
                visible: (plasmoid.configuration.buttonColorize && plasmoid.configuration.buttonColorizeInactive) ?
                    true : false
            }
            PropertyChanges {
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        },
        State {
            name: "minimizedNodecoration"
            when: (model.IsMinimized === true && !frame.isHovered) && plasmoid.configuration.disableButtonInactiveSvg

            PropertyChanges {
                target: frame
                basePrefix: "minimized"
                visible: plasmoid.configuration.disableButtonInactiveSvg ?
                    false : true
            }
            PropertyChanges {
                target: colorOverride
                visible: plasmoid.configuration.disableButtonInactiveSvg ?
                    false : true
            }
            PropertyChanges {
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        },
        State {
            name: "active"
            when: model.IsActive === true

            PropertyChanges {
                target: frame
                basePrefix: "focus"
            }
            PropertyChanges {
                target: colorOverride
                visible: plasmoid.configuration.buttonColorize ?
                    true : false
            }
            PropertyChanges {
                target: indicator
                visible: plasmoid.configuration.indicatorsEnabled ?
                    true : false
            }
        },
        State {
            name: "inactive"
            when: model.IsActive === false && !frame.isHovered && !plasmoid.configuration.disableButtonInactiveSvg
            PropertyChanges {
                target: colorOverride
                visible: plasmoid.configuration.buttonColorize && plasmoid.configuration.buttonColorizeInactive ?
                    true : false
            }
            PropertyChanges {
                target: frame
                visible: plasmoid.configuration.buttonColorize && plasmoid.configuration.buttonColorizeInactive ?
                    false : true
            }
            PropertyChanges {
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        },
        State {
            name: "inactiveNoDecoration"
            when: (model.IsActive === false && !frame.isHovered) && plasmoid.configuration.disableButtonInactiveSvg
            PropertyChanges {
                target: colorOverride
                visible: plasmoid.configuration.disableButtonInactiveSvg ?
                    false : true
            }
            PropertyChanges {
                target: frame
                visible: plasmoid.configuration.disableButtonInactiveSvg ?
                    false : true
            }
            PropertyChanges {
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        },
        State {
            name: "hover"
            when: frame.isHovered
            PropertyChanges {
                target: colorOverride
                visible: plasmoid.configuration.buttonColorize ?
                    true : false
            }
            PropertyChanges {
                target: frame
                visible: plasmoid.configuration.buttonColorize ?
                    false : true
            }
            PropertyChanges {
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ?
                    false : true
            }
        }
    ]

    Component.onCompleted: {
        if (!inPopup && model.IsWindow) {
            if (plasmoid.configuration.groupIconEnabled) {
                const component = Qt.createComponent("GroupExpanderOverlay.qml");
                component.createObject(task);
                component.destroy();
            }
            updateAudioStreams({
                delay: false
            });
        }

        if (!inPopup && !model.IsWindow) {
            taskInitComponent.createObject(task);
        }
        completed = true;
    }
    Component.onDestruction: {
        if (moveAnim.running) {
            (task.parent as TaskList).animationsRunning -= 1;
        }
    }
}
