/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2024 Vlad Zahorodnii <vlad.zahorodnii@kde.org>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2020-2023 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Akseli Lahtinen <akselmo@akselmo.dev>
    SPDX-FileCopyrightText: 2023 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2023 Niccolò Venerandi <niccolo@venerandi.com>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick.Effects 
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

import "code/singletones"

Item {
    id: root
    


    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight

    readonly property alias isHovered: rootHover.hovered

    required property var toolTipDelegate
    required property var tasksModel
    property var mpris2Model

    property var explicitWinId: undefined
    readonly property var currentWinId: explicitWinId !== undefined ? explicitWinId : (toolTipDelegate.windows && root.index < toolTipDelegate.windows.length ? toolTipDelegate.windows[root.index] : undefined)
    
    property var audioStreamManager
    

    readonly property bool useOverlayStyle: toolTipDelegate && toolTipDelegate.showThumbnails

    HoverHandler {
        id: rootHover
    }

    PlasmaExtras.Highlight {
        anchors.fill: parent
        anchors.margins: -Kirigami.Units.smallSpacing / 2
        visible: (root.isHovered || (toolTipDelegate.isGroup && isWindowActive)) && !toolTipDelegate.showThumbnails
        opacity: root.isHovered ? 1.0 : (isWindowActive ? 0.6 : 0.0)

        pressed: (rootHover.item as MouseArea)?.containsPress ?? false
        hovered: true
        z: -1
    }

    // Mouse Interaction for Text Mode (when thumbnails hidden)
    Loader {
        anchors.fill: parent
        active: !toolTipDelegate.showThumbnails && toolTipDelegate.isWin
        sourceComponent: ToolTipWindowMouseArea {
            rootTask: toolTipDelegate ? toolTipDelegate.parentTask : null
            modelIndex: root.submodelIndex
            winId: root.currentWinId
            globalHovered: rootHover.hovered
            tasksModel: root.tasksModel
            toolTipDelegate: root.toolTipDelegate
        }
    }

    required property int index
    required property var submodelIndex
    required property int appPid
    property string appId: ""
    required property string display
    required property bool isMinimized
    required property bool isWindowActive
    required property bool isOnAllVirtualDesktops
    required property var virtualDesktops
    required property list<string> activities

    readonly property string calculatedAppName: {
        let name = "";
        if (toolTipDelegate.appName && toolTipDelegate.appName.length > 0) {
            name = toolTipDelegate.appName;
        } else {
            const text = display;
            const versionRegex = /\s+(?:—|-|–)\s+([^\s(—|-|–)]+)\s+(?:—|-|–)\s+v?\d+(?:\.\d+)+.*$/i;
            const matchVersion = text.match(versionRegex);
            if (matchVersion && matchVersion[1]) {
                name = matchVersion[1];
            } else {
                const lastSepRegex = /.*(?:—|-|–)\s+(.*)$/;
                const matchLast = text.match(lastSepRegex);
                if (matchLast && matchLast[1]) {
                    name = matchLast[1];
                }
            }
        }

        if (name && toolTipDelegate.smartLauncherCountVisible && toolTipDelegate.smartLauncherCount > 0) {
             return name + " (" + toolTipDelegate.smartLauncherCount + ")";
        }
        return name;
    }

    readonly property string title: {
        if (!toolTipDelegate.isWin) {
            return toolTipDelegate.genericName;
        }

        let text = display;
        if (toolTipDelegate.isGroup && text === "") {
            return "";
        }

        let counter = "";
        const counterMatch = text.match(/\s*<\d+>$/);
        if (counterMatch) {
            counter = counterMatch[0];
            text = text.replace(/\s*<\d+>$/, "");
        }

        const appName = root.calculatedAppName;
        if (appName && appName.length > 0) {
            const escapedAppName = appName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const cleanupRegex = new RegExp(`\\s+(?:—|-|–)\\s+${escapedAppName}.*$`, "i");

            if (text.match(cleanupRegex)) {
                text = text.replace(cleanupRegex, "");
            } else {
                 const greedyMatch = text.match(/.*(?=\s+(—|-|–))/);
                 if (greedyMatch) {
                     text = greedyMatch[0];
                 }
            }
        } else {
            const greedyMatch = text.match(/.*(?=\s+(—|-|–))/);
            if (greedyMatch) {
                text = greedyMatch[0];
            }
        }

        if (text === "") {
            text = "—";
        }

        return text + counter;
    }
    required property bool isPlayingAudio
    required property bool isMuted

    // Media Controller Loader
    Loader {
        id: mediaControllerLoader
        // Lazy load the backend media controller only when media controls are enabled in settings
        active: Plasmoid.configuration && Plasmoid.configuration.showMediaControls
        sourceComponent: ToolTipMediaController {
            toolTipDelegate: root.toolTipDelegate
            appPid: root.appPid
            appId: root.appId
            title: root.title
            audioStreamManager: root.audioStreamManager
            mpris2Model: root.mpris2Model
            index: root.index
            thumbnailWinId: thumbnailSourceItem.winId
            isPlayingAudio: root.isPlayingAudio
        }
    }

    readonly property var mediaController: mediaControllerLoader.item

    // Bridge Properties to maintain full compatibility with visual overlays and controllers
    readonly property var playerData: mediaController ? mediaController.playerData : null
    readonly property bool titleIncludesTrack: mediaController ? mediaController.titleIncludesTrack : false
    
    // Audio Streams (Bridged to controller with fallbacks to task model)
    readonly property var audioStreams: mediaController ? mediaController.audioStreams : []
    readonly property bool hasAudioStream: mediaController ? mediaController.hasAudioStream : false
    readonly property bool muted: mediaController ? mediaController.muted : root.isMuted
    readonly property bool playingAudio: mediaController ? mediaController.playingAudio : root.isPlayingAudio

    function toggleMuted() {
        if (mediaController) {
            mediaController.toggleMuted();
        }
    }
    
    function adjustAppVolume(increment) {
        if (mediaController) {
            mediaController.adjustAppVolume(increment);
        }
    }

    readonly property bool showPlayerControls: mediaController ? mediaController.showPlayerControls : false
    readonly property bool showVolumeControls: mediaController ? mediaController.showVolumeControls : false
    readonly property bool controlsAreEffective: mediaController ? mediaController.controlsAreEffective : false
    property bool delayedControlsActive: false
    
    onControlsAreEffectiveChanged: {
        if (controlsAreEffective) {
            controlsHideTimer.stop();
            delayedControlsActive = true;
        } else {
            controlsHideTimer.restart();
        }
    }
    
    Timer {
        id: controlsHideTimer
        interval: 1000
        repeat: false
        onTriggered: delayedControlsActive = false
    }


    PlasmaExtras.Highlight {
        anchors.fill: parent
        anchors.margins: -Kirigami.Units.smallSpacing / 2
        visible: toolTipDelegate.isGroup && root.isHovered && !toolTipDelegate.showThumbnails
        pressed: (rootHover.item as MouseArea)?.containsPress ?? false
        hovered: true
        z: -1
    }

    ColumnLayout {
        id: mainLayout
        width: parent.width
        spacing: Kirigami.Units.smallSpacing


        Layout.margins: 0
    
    RowLayout {
        id: header
        visible: !root.useOverlayStyle
        Layout.preferredHeight: implicitHeight // Ensure height propagates to root
        spacing: Kirigami.Units.smallSpacing

        Layout.maximumWidth: toolTipDelegate.tooltipInstanceMaximumWidth
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        Layout.margins: toolTipDelegate.showThumbnails ? Kirigami.Units.mediumSpacing : Kirigami.Units.smallSpacing
        Layout.fillWidth: true

        Kirigami.Icon {
            source: toolTipDelegate.icon
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            Layout.alignment: Qt.AlignVCenter
            visible: !toolTipDelegate.showThumbnails && toolTipDelegate.isWin
        }

        ColumnLayout {
            spacing: 0
            
            Layout.fillWidth: true
            Layout.preferredWidth: 0 
            Layout.minimumWidth: 0 

            Kirigami.Heading {
                id: appNameHeading
                level: 3
                maximumLineCount: 1
                lineHeight: 1
                
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                
                text: root.calculatedAppName

                opacity: 1
                visible: text.length !== 0 && toolTipDelegate.showThumbnails
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
            }
            PlasmaComponents3.Label {
                id: winTitle
                maximumLineCount: 1
                
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                
                text: toolTipDelegate.showThumbnails ? (root.titleIncludesTrack ? "" : root.title) : root.display
                opacity: toolTipDelegate.showThumbnails ? 0.75 : 1.0
                horizontalAlignment: toolTipDelegate.showThumbnails ? Text.AlignHCenter : Text.AlignLeft
                visible: text.length !== 0
                textFormat: Text.PlainText
            }
            PlasmaComponents3.Label {
                id: subtext
                maximumLineCount: 2
                
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                
                text: toolTipDelegate.isWin ? root.generateSubText() : ""
                opacity: 0.6
                horizontalAlignment: Text.AlignHCenter
                visible: toolTipDelegate.showThumbnails && text.length !== 0 && text !== appNameHeading.text
                textFormat: Text.PlainText
            }
        }



        PlasmaComponents3.ToolButton {
            id: closeButton
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            visible: toolTipDelegate.isWin && (toolTipDelegate.showThumbnails || root.isHovered)
            icon.name: "window-close"
            icon.width: !toolTipDelegate.showThumbnails ? Kirigami.Units.iconSizes.small : undefined
            icon.height: !toolTipDelegate.showThumbnails ? Kirigami.Units.iconSizes.small : undefined
            onClicked: {
                if (toolTipDelegate.parentTask && toolTipDelegate.parentTask.tasksRoot) {
                    toolTipDelegate.parentTask.tasksRoot.cancelHighlightWindows();
                }
                const targetIndex = root.findMatchingTaskIndex();
                tasksModel.requestClose(targetIndex);
            }
        }
    }

    // LIST MEDIA CONTROLS (Only visible in Text Mode)
    Loader {
        id: textModeControlsLoader
        Layout.fillWidth: true
        Layout.maximumWidth: toolTipDelegate ? toolTipDelegate.tooltipInstanceMaximumWidth : Kirigami.Units.gridUnit * 14
        Layout.topMargin: -Kirigami.Units.smallSpacing // Tighter spacing to header
        
        active: !toolTipDelegate.showThumbnails && (root.controlsAreEffective || root.delayedControlsActive)
        visible: active
        
        sourceComponent: ToolTipMediaControls {
            mediaController: root.mediaController
        }
    }

    Item {
        id: thumbnailSourceItem

        readonly property int targetWidth: Kirigami.Units.gridUnit * 14
        readonly property int targetHeight: Math.round(targetWidth / (Screen.width / Screen.height))

        Layout.preferredWidth: toolTipDelegate.showThumbnails ? targetWidth : 0
        Layout.preferredHeight: toolTipDelegate.showThumbnails ? targetHeight : 0

        Layout.alignment: Qt.AlignCenter
        clip: false
        
        visible: toolTipDelegate.isWin && Plasmoid.configuration.showToolTips && toolTipDelegate.showThumbnails

        readonly property var winId: explicitWinId !== undefined ?
            explicitWinId : (toolTipDelegate.isWin ? toolTipDelegate.windows[root.index] : undefined)

        readonly property bool thumbnailAreaHovered: thumbnailHoverHandler.hovered

        HoverHandler {
            id: thumbnailHoverHandler
        }

        PlasmaExtras.Highlight {
            anchors.fill: hoverHandler
            
            // Use opacity for smooth transition matching the player controls
            opacity: thumbnailSourceItem.thumbnailAreaHovered ? 1.0 : ((toolTipDelegate.isGroup && isWindowActive) ? 0.6 : 0.0)
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
            
            visible: opacity > 0 // Optimization
            
            pressed: (hoverHandler.item as MouseArea)?.containsPress ?? false
            hovered: true
        }

        Loader {
            id: thumbnailLoader
            active: !toolTipDelegate.isLauncher && !albumArtImage.visible && (Number.isInteger(thumbnailSourceItem.winId) || pipeWireLoader.item && !pipeWireLoader.item.hasThumbnail) && root.index !== -1
            asynchronous: true
            
            visible: active
            
            anchors.fill: hoverHandler
            anchors.margins: Kirigami.Units.smallSpacing

            sourceComponent: (Qt.platform.pluginName === "wayland" || root.isMinimized || pipeWireLoader.item) ? iconItem : x11Thumbnail

            Component {
                id: x11Thumbnail
                PlasmaCore.WindowThumbnail {
                    winId: Number.isInteger(thumbnailSourceItem.winId) ? thumbnailSourceItem.winId : 0
                }
            }

            Component {
                id: iconItem
                Kirigami.Icon {
                    id: realIconItem
                    source: toolTipDelegate.icon
                    animated: false
                    visible: valid
                    
                    // FIX: Hide ONLY when PipeWire thumbnail is ACTUALLY READY.
                    // If loader is active but item is null or not ready, keep icon visible.
                    property bool thumbnailReady: pipeWireLoader.active && pipeWireLoader.item && pipeWireLoader.item.hasThumbnail
                    opacity: thumbnailReady ? 0 : 1
                    
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.gridUnit 

                    // Smooth fade out when thumbnail appears
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    SequentialAnimation {
                        running: true
                        PauseAnimation { duration: Kirigami.Units.humanMoment }
                        NumberAnimation {
                            id: showAnimation
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.OutCubic
                            property: "opacity"
                            target: realIconItem
                            to: 1
                        }
                    }
                }
            }
        }

        Loader {
            id: pipeWireLoader
            anchors.fill: hoverHandler
            anchors.margins: thumbnailLoader.anchors.margins

            active: !toolTipDelegate.isLauncher && !albumArtImage.visible && Qt.platform.pluginName === "wayland" && root.index !== -1
            asynchronous: true
            source: "PipeWireThumbnail.qml"

            Binding {
                target: pipeWireLoader.item
                property: "winId"
                value: thumbnailSourceItem.winId
            }

            Timer {
                id: captureTimer
                interval: 400 
                repeat: false
                running: pipeWireLoader.status === Loader.Ready 
                         && pipeWireLoader.item 
                         && pipeWireLoader.item.hasThumbnail
                         && thumbnailSourceItem.winId !== undefined
                
                onTriggered: {
                    if (pipeWireLoader.item) {
                        if (pipeWireLoader.item.width <= 0 || pipeWireLoader.item.height <= 0) return;
                        pipeWireLoader.item.grabToImage(function(result) {
                            if (result && thumbnailSourceItem.winId) {
                                // Store full result object to prevent garbage collection of the URL
                                toolTipDelegate.thumbnailCache[thumbnailSourceItem.winId] = result;
                            }
                        }, Qt.size(pipeWireLoader.item.width, pipeWireLoader.item.height));
                    }
                }
            }
        }
        
        // Placeholder image showing the cached thumbnail while the live stream initializes
        Image {
             id: cachedThumbnail
             anchors.fill: hoverHandler
             anchors.margins: thumbnailLoader.anchors.margins
             
             // Access .url from the stored ItemGrabResult object
             source: (thumbnailSourceItem.winId && toolTipDelegate.thumbnailCache[thumbnailSourceItem.winId]) 
                     ? toolTipDelegate.thumbnailCache[thumbnailSourceItem.winId].url 
                     : ""
             
             readonly property bool liveThumbnailReady: pipeWireLoader.active && pipeWireLoader.item && pipeWireLoader.item.hasThumbnail
             
             visible: !liveThumbnailReady && status === Image.Ready
             
             asynchronous: false
             fillMode: Image.PreserveAspectFit
             cache: false
        }

        Loader {
            active: albumArtImage.visible && albumArtImage.status === Image.Ready && root.index !== -1 
            asynchronous: true
            visible: active
            anchors.centerIn: hoverHandler

            sourceComponent: Item { 
                 id: albumArtBackground
                 readonly property Image source: albumArtImage
            }
        }

        Image {
            id: albumArtImage
            readonly property bool available: (status === Image.Ready || status === Image.Loading) && (!(toolTipDelegate.isGroup || /firefox|chrome|chromium|opera|vivaldi|brave|edge|konqueror/i.test(toolTipDelegate.launcherUrl.toString())) || root.titleIncludesTrack)

            anchors.fill: hoverHandler
            anchors.margins: Kirigami.Units.smallSpacing
            sourceSize: Qt.size(parent.width, parent.height)

            asynchronous: true
            source: root.playerData?.artUrl ?? ""
            fillMode: Image.PreserveAspectFit
            visible: available
        }

        Loader {
            id: hoverHandler
            active: root.index !== -1
            anchors.fill: parent
            sourceComponent: ToolTipWindowMouseArea {
                rootTask: toolTipDelegate.parentTask
                modelIndex: root.submodelIndex
                winId: thumbnailSourceItem.winId
                globalHovered: rootHover.hovered
                tasksModel: root.tasksModel
                toolTipDelegate: root.toolTipDelegate
            }
        }

        // Overlay Media Controls (Ghost Controls)
        Loader {
            id: overlayControlsLoader
            active: toolTipDelegate.showThumbnails && Plasmoid.configuration.mediaControlsLocation === 0 && (root.controlsAreEffective || root.delayedControlsActive)
            visible: active
            
            z: 2002 
            
            anchors.bottom: hoverHandler.bottom
            anchors.horizontalCenter: hoverHandler.horizontalCenter
            anchors.margins: Kirigami.Units.smallSpacing
            width: hoverHandler.width - (anchors.margins * 2)
            
            sourceComponent: ToolTipMediaOverlay {
                mediaController: root.mediaController
                hoveredState: thumbnailSourceItem.thumbnailAreaHovered
            }
        }

        // Title Overlay (Top-Left)
        Item {
            id: titleOverlayContainer
            z: 9999
            visible: root.useOverlayStyle && toolTipDelegate.isWin && titleOverlayLabel.text.length > 0
            
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing
            
            // Dynamic Sizing Logic
            readonly property int maxOverlayWidth: parent.width - (closeButtonOverlay.visible ? closeButtonOverlay.width : 0) - Kirigami.Units.largeSpacing
            
            // Padding Constants
            readonly property int hPadding: Kirigami.Units.largeSpacing
            readonly property int vPadding: Kirigami.Units.smallSpacing
            
            // Calculate width based on text content + padding, capped at max
            width: Math.min(titleOverlayLabel.implicitWidth + hPadding * 2, maxOverlayWidth)
            height: titleOverlayLabel.implicitHeight + vPadding * 2
            
            // Background Layer (Blurred Edges)
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.45) 
                radius: Kirigami.Units.smallSpacing
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 8
                    blur: 0.5 
                }
            }
            
            // Text Layer
            PlasmaComponents3.Label {
                id: titleOverlayLabel
                anchors.centerIn: parent
                // Ensure text wraps/elides within the container minus padding
                width: parent.width - parent.hPadding * 2
                
                text: {
                    if (root.titleIncludesTrack) return ""; 

                    let titleText = root.title;
                    
                    // Strip shortcuts like "{Meta+1}"
                    // Regex: Space (optional) + { + anything + } + End
                    titleText = titleText.replace(/\s*\{[^\}]*\}\s*$/, "");
                    
                    // Check redundancy
                    let appName = root.calculatedAppName;
                    if (appName && titleText.toLowerCase() === appName.toLowerCase()) {
                        return ""; // Hide if redundant
                    }
                    
                    if (!titleText && root.display !== appName) {
                         // Fallback to display only if it's not also redundant
                         titleText = root.display;
                         if (titleText && titleText.toLowerCase() === appName.toLowerCase()) return "";
                    }

                    return titleText || ""; 
                }
                
                elide: Text.ElideRight
                color: "white" 
                font.bold: false
                opacity: 0.85 
            }
        }

        // Close Button Overlay (Top-Right)
        PlasmaComponents3.ToolButton {
            id: closeButtonOverlay
            z: 2003
            visible: root.useOverlayStyle && toolTipDelegate.isWin
            
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.smallSpacing
            
            icon.name: "window-close"
            display: PlasmaComponents3.AbstractButton.IconOnly
            
            width: height
            height: titleOverlayContainer.height

            background: Item {
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.45)
                    radius: Kirigami.Units.smallSpacing
                }
                
                PlasmaExtras.Highlight {
                    anchors.fill: parent
                    visible: closeButtonOverlay.hovered
                    opacity: 0.8
                    hovered: true
                    pressed: closeButtonOverlay.pressed
                }
            }

            onClicked: {
                if (toolTipDelegate.parentTask && toolTipDelegate.parentTask.tasksRoot) {
                    toolTipDelegate.parentTask.tasksRoot.cancelHighlightWindows();
                }
                const targetIndex = root.findMatchingTaskIndex();
                tasksModel.requestClose(targetIndex);
            }
        }
    }

    // UNDER-THUMBNAIL MEDIA BAR
    Loader {
        id: mediaBarLoader
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: -Kirigami.Units.smallSpacing // Tighter padding

        active: toolTipDelegate.showThumbnails && Plasmoid.configuration.mediaControlsLocation === 1 && (root.controlsAreEffective || root.delayedControlsActive)
        visible: active

        sourceComponent: ToolTipMediaBar {
            mediaController: root.mediaController
        }
    }
}






    function generateSubText(): string {
        const subTextEntries = [];
        if (!Plasmoid.configuration.showOnlyCurrentDesktop && virtualDesktopInfo.numberOfDesktops > 1) {
            if (!isOnAllVirtualDesktops && virtualDesktops.length > 0) {
                const virtualDesktopNameList = virtualDesktops.map(virtualDesktop => {
                    const index = virtualDesktopInfo.desktopIds.indexOf(virtualDesktop);
                    return virtualDesktopInfo.desktopNames[index];
                });

                subTextEntries.push(Wrappers.i18nc("Comma-separated list of desktops", "On %1", virtualDesktopNameList.join(", ")));
            } else if (isOnAllVirtualDesktops) {
                subTextEntries.push(Wrappers.i18nc("Comma-separated list of desktops", "Pinned to all desktops"));
            }
        }

        if (activities.length === 0 && activityInfo.numberOfRunningActivities > 1) {
            subTextEntries.push(Wrappers.i18nc("Which virtual desktop a window is currently on", "Available on all activities"));
        } else if (activities.length > 0) {
            const activityNames = activities.filter(activity => activity !== activityInfo.currentActivity).map(activity => activityInfo.activityName(activity)).filter(activityName => activityName !== "");
            if (Plasmoid.configuration.showOnlyCurrentActivity) {
                if (activityNames.length > 0) {
                    subTextEntries.push(Wrappers.i18nc("Activities a window is currently on (apart from the current one)", "Also available on %1", activityNames.join(", ")));
                }
            } else if (activityNames.length > 0) {
                subTextEntries.push(Wrappers.i18nc("Which activities a window is currently on", "Available on %1", activityNames.join(", ")));
            }
        }

        return subTextEntries.join("\n");
    }

    function findMatchingTaskIndex() {
        // Function to find the child task index that owns this winId
        // Used to fix the close button closing the wrong window in a group
        if (!tasksModel || !toolTipDelegate.parentTask || toolTipDelegate.parentTask.childCount === 0) return submodelIndex;
        
        const winId = thumbnailSourceItem.winId;
        if (winId === undefined) return submodelIndex;

        // Iterate through children of the parent task
        const parentRow = toolTipDelegate.parentTask.index;
        const childCount = toolTipDelegate.parentTask.childCount;
        
        for (let i = 0; i < childCount; ++i) {
            // Create index for child i
            const idx = tasksModel.makeModelIndex(parentRow, i);
            
            // Get WinIdList for this child
            const winIds = tasksModel.data(idx, TaskManager.AbstractTasksModel.WinIdList);
            
            if (winIds && winIds.includes(winId)) {
                return idx;
            }
        }
        
        return submodelIndex;
    }
}
