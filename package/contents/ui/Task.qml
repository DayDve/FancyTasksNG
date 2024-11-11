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

PlasmaCore.ToolTipArea {
    id: task

    activeFocusOnTab: true

    readonly property bool isMetro: plasmoid.configuration.indicatorStyle === 0
    readonly property bool isCiliora: plasmoid.configuration.indicatorStyle === 1
    readonly property bool isDashes: plasmoid.configuration.indicatorStyle === 2

    property string tintColor: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor)
        === Kirigami.ColorUtils.Dark
        ? "#ffffff"
        : "#000000"

    // To achieve a bottom to top layout, the task manager is rotated by 180 degrees(see main.qml).
    // This makes the tasks mirrored, so we mirror them again to fix that.
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    implicitHeight: inPopup
                    ? LayoutMetrics.preferredHeightInPopup()
                    : Math.max(tasksRoot.height / tasksRoot.plasmoid.configuration.maxStripes,
                             LayoutMetrics.preferredMinHeight())
    implicitWidth: tasksRoot.vertical
        ? Math.max(LayoutMetrics.preferredMinWidth(), Math.min(LayoutMetrics.preferredMaxWidth(), tasksRoot.width / tasksRoot.plasmoid.configuration.maxStripes))
        : 0

    Layout.fillWidth: true
    Layout.fillHeight: !inPopup
    Layout.maximumWidth: tasksRoot.vertical
        ? -1
        : ((model.IsLauncher && !tasks.iconsOnly) ? tasksRoot.height / taskList.rows : LayoutMetrics.preferredMaxWidth())
    Layout.maximumHeight: tasksRoot.vertical ? LayoutMetrics.preferredMaxHeight() : -1

    required property var model
    required property int index
    required property /*main.qml*/ Item tasksRoot

    readonly property int pid: model.AppPid
    readonly property string appName: model.AppName
    readonly property string appId: model.AppId.replace(/\.desktop/, '')
    readonly property bool isIcon: tasksRoot.iconsOnly || model.IsLauncher
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
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    readonly property bool highlighted: (inPopup && activeFocus) || (!inPopup && containsMouse)
        || (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)
        || (!!tasksRoot.groupDialog && tasksRoot.groupDialog.visualParent === task)

    property int itemIndex: index // fancytasks

    active: (Plasmoid.configuration.showToolTips || tasksRoot.toolTipOpenedByClick === task) && !inPopup && !tasksRoot.groupDialog
    interactive: model.IsWindow || mainItem.playerData
    location: Plasmoid.location
    mainItem: model.IsWindow ? openWindowToolTipDelegate : pinnedAppToolTipDelegate

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
            return i18nc("@info:usagetip %1 application name", "Launch %1", model.display)
        }

        let smartLauncherDescription = "";
        if (iconBox.active) {
            smartLauncherDescription += i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.smartLauncherItem.count);
        }

        if (model.IsGroupParent) {
            switch (Plasmoid.configuration.groupedTaskVisualization) {
            case 0:
                break; // Use the default description
            case 1: {
                if (Plasmoid.configuration.showToolTips) {
                    return `${i18nc("@info:usagetip %1 task name", "Show Task tooltip for %1", model.display)}; ${smartLauncherDescription}`;
                }
                // fallthrough
            }
            case 2: {
                if (effectWatcher.registered) {
                    return `${i18nc("@info:usagetip %1 task name", "Show windows side by side for %1", model.display)}; ${smartLauncherDescription}`;
                }
                // fallthrough
            }
            default:
                return `${i18nc("@info:usagetip %1 task name", "Open textual list of windows for %1", model.display)}; ${smartLauncherDescription}`;
            }
        }

        return `${i18n("Activate %1", model.display)}; ${smartLauncherDescription}`;
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onToolTipVisibleChanged: toolTipVisible => {
        task.toolTipOpen = toolTipVisible;
        if (!toolTipVisible) {
            tasksRoot.toolTipOpenedByClick = null;
        } else {
            tasksRoot.toolTipAreaItem = task;
        }
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            task.forceActiveFocus(Qt.MouseFocusReason);
            task.updateMainItemBindings();
        } else {
            tasksRoot.toolTipOpenedByClick = null;
        }
    }

    onHighlightedChanged: {
        // ensure it doesn't get stuck with a window highlighted
        backend.cancelHighlightWindows();
    }

    onPidChanged: updateAudioStreams({delay: false})
    onAppNameChanged: updateAudioStreams({delay: false})

    onIsWindowChanged: {
        if (model.IsWindow) {
            taskInitComponent.createObject(task);
            updateAudioStreams({delay: false});
        }
    }

    onChildCountChanged: {
        if (TaskTools.taskManagerInstanceCount < 2 && childCount > previousChildCount) {
            tasksModel.requestPublishDelegateGeometry(modelIndex(), backend.globalRect(task), task);
        }

        previousChildCount = childCount;
    }

    onIndexChanged: {
        hideToolTip();

        if (!inPopup && !tasksRoot.vertical
                && !Plasmoid.configuration.separateLaunchers) {
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
    Keys.onEnterPressed: event => Keys.returnPressed(event);
    Keys.onSpacePressed: event => Keys.returnPressed(event);
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)
    Keys.onLeftPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksModel.move(task.index, task.index - 1);
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
        return inPopup
            ? tasksModel.makeModelIndex(groupDialog.visualParent.index, index)
            : tasksModel.makeModelIndex(index);
    }

    function showContextMenu(args: var): void {
        task.hideImmediately();
        contextMenu = tasksRoot.createContextMenu(task, modelIndex(), args);
        contextMenu.show();
    }

    function updateAudioStreams(args: var): void {
        if (args) {
            // When the task just appeared (e.g. virtual desktop switch), show the audio indicator
            // right away. Only when audio streams change during the lifetime of this task, delay
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
                // a PID to an audio stream window. Otherwise if you have two instances of
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

    // Will also be called in activateTaskAtIndex(index)
    function updateMainItemBindings(): void {
        if ((mainItem.parentTask === this && mainItem.rootIndex.row === index)
            || (tasksRoot.toolTipOpenedByClick === null && !active)
            || (tasksRoot.toolTipOpenedByClick !== null && tasksRoot.toolTipOpenedByClick !== this)) {
            return;
        }

        mainItem.blockingUpdates = (mainItem.isGroup !== model.IsGroupParent); // BUG 464597 Force unload the previous component

        mainItem.parentTask = this;
        mainItem.rootIndex = tasksModel.makeModelIndex(index, -1);

        mainItem.appName = Qt.binding(() => model.AppName);
        mainItem.pidParent = Qt.binding(() => model.AppPid);
        mainItem.windows = Qt.binding(() => model.WinIdList);
        mainItem.isGroup = Qt.binding(() => model.IsGroupParent);
        mainItem.icon = Qt.binding(() => model.decoration);
        mainItem.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
        mainItem.isLauncher = Qt.binding(() => model.IsLauncher);
        mainItem.isMinimized = Qt.binding(() => model.IsMinimized);
        mainItem.display = Qt.binding(() => model.display);
        mainItem.genericName = Qt.binding(() => model.GenericName);
        mainItem.virtualDesktops = Qt.binding(() => model.VirtualDesktops);
        mainItem.isOnAllVirtualDesktops = Qt.binding(() => model.IsOnAllVirtualDesktops);
        mainItem.activities = Qt.binding(() => model.Activities);

        mainItem.smartLauncherCountVisible = Qt.binding(() => smartLauncherItem?.countVisible ?? false);
        mainItem.smartLauncherCount = Qt.binding(() => mainItem.smartLauncherCountVisible ? smartLauncherItem.count : 0);

        mainItem.blockingUpdates = false;
        tasksRoot.toolTipAreaItem = this;
    }

    Connections {
        target: pulseAudio.item
        ignoreUnknownSignals: true // Plasma-PA might not be available
        function onStreamsChanged(): void {
            task.updateAudioStreams({delay: true})
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
            h = s = 0; // achromatic
        }else {
            var d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            switch(max){
                case r: h = (g - b) / d + (g < b ? 6 : 0); break;
                case g: h = (b - r) / d + 2; break;
                case b: h = (r - g) / d + 4; break;
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
                frame.indicatorColor :
                plasmoid.configuration.buttonColorizeCustom
        visible: plasmoid.configuration.buttonColorize ? true : false
    }

    Indicators {
        id: indicator
        taskCount: task.childCount
        visible: plasmoid.configuration.indicatorsEnabled ? true : false
        flow: Flow.LeftToRight
        spacing: Kirigami.Units.smallSpacing
        clip: true
    }

    // Flow {
    //     id: indicator
    //     visible: plasmoid.configuration.indicatorsEnabled ? true : false
    //     flow: Flow.LeftToRight
    //     spacing: Kirigami.Units.smallSpacing
    //     clip: true
    //     Repeater {

    //         model: {
                
    //             if(!plasmoid.configuration.indicatorsEnabled)
    //             return 0;
    //             if(task.childCount < plasmoid.configuration.indicatorMinLimit)
    //             return 0;
    //             if(task.isSubTask)//Target only the main task items.
    //             return 0;
    //             if(task.state === 'launcher') {
    //                 return 0;
    //             }
    //             return Math.min((task.childCount === 0) ? 1 : task.childCount, maxStates);
    //         }
    //         readonly property int maxStates: plasmoid.configuration.indicatorMaxLimit
            
    //         Rectangle{
    //             id: stateRect
    //             Behavior on height { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
    //             Behavior on width { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
    //             Behavior on color { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
    //             Behavior on radius { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
    //             readonly property color decoColor: index === 0 ? "red" : frame.indicatorColor
    //             readonly property int maxStates: plasmoid.configuration.indicatorMaxLimit
    //             readonly property bool isFirst: index === 0
    //             readonly property int adjust: plasmoid.configuration.indicatorShrink
    //             readonly property int indicatorLength: plasmoid.configuration.indicatorLength
    //             readonly property int spacing: Kirigami.Units.smallSpacing
    //             readonly property bool isVertical: {
    //                 if(plasmoid.formFactor === PlasmaCore.Types.Vertical && !plasmoid.configuration.indicatorOverride)
    //                 return true;
    //                 if(plasmoid.formFactor == PlasmaCore.Types.Floating && plasmoid.configuration.indicatorOverride && (plasmoid.configuration.indicatorLocation === 1 || plasmoid.configuration.indicatorLocation === 2))
    //                 return  true;
    //                 if(plasmoid.configuration.indicatorOverride && (plasmoid.configuration.indicatorLocation === 1 || plasmoid.configuration.indicatorLocation === 2))
    //                 return  true;
    //                 else{
    //                     return false;
    //                 }
    //             }
    //             readonly property var computedVar: {
    //                 var height;
    //                 var width;
    //                 var colorCalc;
    //                 var colorEval = '#FFFFFF';
    //                 var parentSize = !isVertical ? frame.width : frame.height;
    //                 var indicatorComputedSize;
    //                 var adjustment = isFirst ? adjust : 0
    //                 var parentSpacingAdjust = task.childCount >= 1 && maxStates >= 2 ? (spacing * 2.5) : 0 //Spacing fix for multiple items
    //                 if(plasmoid.configuration.indicatorDominantColor){
    //                     colorEval = decoColor
    //                 }
    //                 if(plasmoid.configuration.indicatorAccentColor){
    //                     colorEval = PlasmaCore.Theme.highlightColor
    //                 }
    //                 else if(!plasmoid.configuration.indicatorDominantColor && !plasmoid.configuration.indicatorAccentColor){
    //                     colorEval = plasmoid.configuration.indicatorCustomColor
    //                 }
    //                 if(isFirst){//compute the size
    //                     var growFactor = plasmoid.configuration.indicatorGrowFactor / 100
    //                     if(plasmoid.configuration.indicatorGrow && task.state === "minimized") {
    //                         var mainSize = indicatorLength * growFactor;
    //                     }
    //                     else{
    //                         var mainSize = (parentSize + parentSpacingAdjust);
    //                     }
    //                     switch(plasmoid.configuration.indicatorStyle){
    //                         case 0:
    //                         indicatorComputedSize = mainSize - (Math.min(task.childCount, maxStates === 1 ? 0 : maxStates)  * (spacing + indicatorLength)) - adjust
    //                         break
    //                         case 1:
    //                         indicatorComputedSize = mainSize - (Math.min(task.childCount, maxStates === 1 ? 0 : maxStates)  * (spacing + indicatorLength)) - adjust
    //                         break
    //                         case 2:
    //                         indicatorComputedSize = plasmoid.configuration.indicatorGrow && task.state !== "minimized" ? indicatorLength * growFactor : indicatorLength
    //                         break
    //                         default:
    //                         break
    //                     }
    //                 }
    //                 else {
    //                     indicatorComputedSize = indicatorLength
    //                 }
    //                 if(!isVertical){
    //                     width = indicatorComputedSize;
    //                     height = plasmoid.configuration.indicatorSize
    //                 }
    //                 else{
    //                     width = plasmoid.configuration.indicatorSize
    //                     height = indicatorComputedSize
    //                 }
    //                 if(plasmoid.configuration.indicatorDesaturate && task.state === "minimized") {
    //                     var colorHSL = hexToHSL(colorEval)
    //                     colorCalc = Qt.hsla(colorHSL.h, colorHSL.s*0.5, colorHSL.l*.8, 1)
    //                 }
    //                 else if(!isFirst && plasmoid.configuration.indicatorStyle ===  0 && task.state !== "minimized") {//Metro specific handling
    //                     colorCalc = Qt.darker(colorEval, 1.2) 
    //                 }
    //                 else {
    //                     colorCalc = colorEval
    //                 }
    //                 return {height: height, width: width, colorCalc: colorCalc}
    //             }
    //             width: computedVar.width
    //             height: computedVar.height
    //             color: computedVar.colorCalc
    //             radius: (Math.max(width, height) / Math.min(width,  height)) * (plasmoid.configuration.indicatorRadius / 100)
    //             Rectangle{
    //                 Behavior on height { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
    //                 Behavior on width { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
    //                 Behavior on color { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
    //                 Behavior on radius { PropertyAnimation {duration: plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
    //                 visible:  task.isWindow && task.smartLauncherItem && task.smartLauncherItem.progressVisible && isFirst && plasmoid.configuration.indicatorProgress
    //                 anchors{
    //                     top: isVertical ? undefined : parent.top
    //                     bottom: isVertical ? undefined : parent.bottom
    //                     left: isVertical ? parent.left : undefined
    //                     right: isVertical ? parent.right : undefined
    //                 }
    //                 readonly property var progress: {
    //                     if(task.smartLauncherItem && task.smartLauncherItem.progressVisible && task.smartLauncherItem.progress){
    //                         return task.smartLauncherItem.progress / 100
    //                     }
    //                     return 0
    //                 }
    //                 width: isVertical ? parent.width : parent.width * progress
    //                 height: isVertical ? parent.height * progress : parent.height
    //                 radius: parent.radius
    //                 color: plasmoid.configuration.indicatorProgressColor
    //             }
    //         }
    //     }
        
    //     states:[
    //         State {
    //             name: "bottom"
    //             when: (plasmoid.configuration.indicatorOverride && plasmoid.configuration.indicatorLocation === 0)
    //                 || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.BottomEdge && !plasmoid.configuration.indicatorReverse)
    //                 || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.TopEdge && plasmoid.configuration.indicatorReverse)
    //                 || (plasmoid.location === PlasmaCore.Types.Floating && plasmoid.configuration.indicatorLocation === 0)
    //                 || (plasmoid.location === PlasmaCore.Types.Floating && !plasmoid.configuration.indicatorOverride && !plasmoid.configuration.indicatorReverse)

    //             AnchorChanges {
    //                 target: indicator
    //                 anchors{ top:undefined; bottom:parent.bottom; left:undefined; right:undefined;
    //                     horizontalCenter:parent.horizontalCenter; verticalCenter:undefined}
    //                 }
    //             PropertyChanges {
    //                 target: indicator
    //                 width: undefined
    //                 height: plasmoid.configuration.indicatorSize
    //                 anchors.topMargin: 0;
    //                 anchors.bottomMargin: plasmoid.configuration.indicatorEdgeOffset;
    //                 anchors.leftMargin: 0;
    //                 anchors.rightMargin: 0;
    //             }
    //         },
    //         State {
    //             name: "left"
    //             when: (plasmoid.configuration.indicatorOverride && plasmoid.configuration.indicatorLocation === 1)
    //                 || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.LeftEdge && !plasmoid.configuration.indicatorReverse)
    //                 || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.RightEdge && plasmoid.configuration.indicatorReverse)
    //                 || (plasmoid.location === PlasmaCore.Types.Floating && plasmoid.configuration.indicatorLocation === 1 && plasmoid.configuration.indicatorOverride)

    //             AnchorChanges {
    //                 target: indicator
    //                 anchors{ top:undefined; bottom:undefined; left:parent.left; right:undefined;
    //                     horizontalCenter:undefined; verticalCenter:parent.verticalCenter}
    //             }
    //             PropertyChanges {
    //                 target: indicator
    //                 height: undefined
    //                 width: plasmoid.configuration.indicatorSize
    //                 anchors.topMargin: 0;
    //                 anchors.bottomMargin: 0;
    //                 anchors.leftMargin: plasmoid.configuration.indicatorEdgeOffset;
    //                 anchors.rightMargin: 0;
    //             }
    //         },
    //         State {
    //             name: "right"
    //             when: (plasmoid.configuration.indicatorOverride && plasmoid.configuration.indicatorLocation === 2)
    //                 || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.RightEdge && !plasmoid.configuration.indicatorReverse)
    //                 || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.LeftEdge && plasmoid.configuration.indicatorReverse)
    //                 || (plasmoid.location === PlasmaCore.Types.Floating && plasmoid.configuration.indicatorLocation === 2 && plasmoid.configuration.indicatorOverride)

    //             AnchorChanges {
    //                 target: indicator
    //                 anchors{ top:undefined; bottom:undefined; left:undefined; right:parent.right;
    //                     horizontalCenter:undefined; verticalCenter:parent.verticalCenter}
    //             }
    //             PropertyChanges {
    //                 target: indicator
    //                 height: undefined
    //                 width: plasmoid.configuration.indicatorSize
    //                 anchors.topMargin: 0;
    //                 anchors.bottomMargin: 0;
    //                 anchors.leftMargin: 0;
    //                 anchors.rightMargin: plasmoid.configuration.indicatorEdgeOffset;
    //             }
    //         },
    //         State {
    //             name: "top"
    //             when: (plasmoid.configuration.indicatorOverride && plasmoid.configuration.indicatorLocation === 3)
    //                 || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.TopEdge && !plasmoid.configuration.indicatorReverse)
    //                 || (!plasmoid.configuration.indicatorOverride && plasmoid.location === PlasmaCore.Types.BottomEdge && plasmoid.configuration.indicatorReverse)
    //                 || (plasmoid.location === PlasmaCore.Types.Floating && plasmoid.configuration.indicatorLocation === 3 && plasmoid.configuration.indicatorOverride)
    //                 || (plasmoid.location === PlasmaCore.Types.Floating && plasmoid.configuration.indicatorReverse && !plasmoid.configuration.indicatorOverride)

    //             AnchorChanges {
    //                 target: indicator
    //                 anchors{ top:parent.top; bottom:undefined; left:undefined; right:undefined;
    //                     horizontalCenter:parent.horizontalCenter; verticalCenter:undefined}
    //             }
    //             PropertyChanges {
    //                 target: indicator
    //                 width: undefined
    //                 height: plasmoid.configuration.indicatorSize
    //                 anchors.topMargin: plasmoid.configuration.indicatorEdgeOffset;
    //                 anchors.bottomMargin: 0;
    //                 anchors.leftMargin: 0;
    //                 anchors.rightMargin: 0;
    //             }
    //         }
    //     ]
    // }

    TapHandler {
        id: menuTapHandler
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onLongPressed: {
            // When we're a launcher, there's no window controls, so we can show all
            // places without the menu getting super huge.
            if (model.IsLauncher) {
                showContextMenu({showAllPlaces: true})
            } else {
                showContextMenu();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        gesturePolicy: TapHandler.WithinBounds // Release grab when menu appears
        onPressedChanged: if (pressed) contextMenuTimer.start()
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
            if (Plasmoid.configuration.showToolTips && task.active) {
                hideToolTip();
            }
            TaskTools.activateTask(modelIndex(), model, point.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.MiddleButton) {
                if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.NewInstance) {
                    tasksModel.requestNewInstance(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.Close) {
                    tasksRoot.taskClosedWithMouseMiddleButton = model.WinIdList.slice()
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

            topMargin: (!tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
            bottomMargin: (!tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
            leftMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
            rightMargin: ((inPopup || tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
        }

        imagePath: plasmoid.configuration.disableButtonSvg ? "" : "widgets/tasks"
        enabledBorders: plasmoid.configuration.useBorders ? 1 | 2 | 4 | 8 : 0
        property bool isHovered: task.highlighted && Plasmoid.configuration.taskHoverEffect
        property string basePrefix: "normal"
        prefix: isHovered ? TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location) : TaskTools.taskPrefix(basePrefix, Plasmoid.location)

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
                        item.appletRequestsInhibitDnD = value
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
                            "application/x-orgkdeplasmataskmanager_taskbuttonitem": model.MimeData,
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

        width: task.inPopup ? Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium) : Math.min(task.parent?.minimumWidth ?? 0, task.height)
        height: task.inPopup ? width : (parent.height - adjustMargin(false, parent.height, taskFrame.margins.top)
                 - adjustMargin(false, parent.height, taskFrame.margins.bottom))

        asynchronous: true
        active: height >= Kirigami.Units.iconSizes.small
                && task.smartLauncherItem && task.smartLauncherItem.countVisible
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

            anchors.fill: parent

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
                    width: Math.min(task.parent.minimumWidth, tasks.height)
                        - adjustMargin(true, task.width, taskFrame.margins.left)
                        - adjustMargin(true, task.width, taskFrame.margins.right)
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

        visible: (inPopup || !iconsOnly && !model.IsLauncher
            && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= LayoutMetrics.spaceRequiredToShowText())

        anchors {
            fill: parent
            leftMargin: taskFrame.margins.left + iconBox.width + LayoutMetrics.labelMargin
            topMargin: taskFrame.margins.top
            rightMargin: taskFrame.margins.right + (audioStreamIcon !== null && audioStreamIcon.visible ? (audioStreamIcon.width + LayoutMetrics.labelMargin) : 0)
            bottomMargin: taskFrame.margins.bottom
        }

        wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: Plasmoid.configuration.maxTextLines || undefined

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
            when: model.IsDemandingAttention === true || (task.smartLauncherItem && task.smartLauncherItem.urgent)

            PropertyChanges {
                target: frame
                basePrefix: "attention"
                visible: (plasmoid.configuration.buttonColorize && !frame.isHovered) || !plasmoid.configuration.buttonColorize
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
                visible: (plasmoid.configuration.buttonColorize && plasmoid.configuration.buttonColorizeInactive) ? false : true
            }
            PropertyChanges { 
                target: colorOverride
                visible: (plasmoid.configuration.buttonColorize && plasmoid.configuration.buttonColorizeInactive) ? true : false
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ? false : true
            }
        },
        State {
            name: "minimizedNodecoration"
            when: (model.IsMinimized === true && !frame.isHovered) && plasmoid.configuration.disableButtonInactiveSvg

            PropertyChanges {
                target: frame
                basePrefix: "minimized"
                visible: plasmoid.configuration.disableButtonInactiveSvg ? false : true
            }
            PropertyChanges { 
                target: colorOverride
                visible: plasmoid.configuration.disableButtonInactiveSvg ? false : true
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ? false : true
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
                visible: plasmoid.configuration.buttonColorize ? true : false
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.indicatorsEnabled ? true : false
            }
        },
        State {
            name: "inactive"
            when: model.IsActive === false && !frame.isHovered && !plasmoid.configuration.disableButtonInactiveSvg
            PropertyChanges { 
                target: colorOverride
                visible: plasmoid.configuration.buttonColorize && plasmoid.configuration.buttonColorizeInactive ? true : false
            }
            PropertyChanges { 
                target: frame
                visible: plasmoid.configuration.buttonColorize && plasmoid.configuration.buttonColorizeInactive ? false : true
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ? false : true
            }
        },
        State {
            name: "inactiveNoDecoration"
            when: (model.IsActive === false && !frame.isHovered) && plasmoid.configuration.disableButtonInactiveSvg
            PropertyChanges { 
                target: colorOverride
                visible: plasmoid.configuration.disableButtonInactiveSvg ? false : true
            }
            PropertyChanges { 
                target: frame
                visible: plasmoid.configuration.disableButtonInactiveSvg ? false : true
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ? false : true
            }
        },
        State {
            name: "hover"
            when: frame.isHovered
            PropertyChanges { 
                target: colorOverride
                visible: plasmoid.configuration.buttonColorize ? true : false
            }
            PropertyChanges { 
                target: frame
                visible: plasmoid.configuration.buttonColorize ? false : true
            }
            PropertyChanges{
                target: indicator
                visible: plasmoid.configuration.disableInactiveIndicators ? false : true
            }
        }
    ]

    Component.onCompleted: {
        if (!inPopup && model.IsWindow) {
            if (plasmoid.configuration.groupIconEnabled){
                const component = Qt.createComponent("GroupExpanderOverlay.qml");
                component.createObject(task);
                component.destroy();
            }
            updateAudioStreams({delay: false});
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
