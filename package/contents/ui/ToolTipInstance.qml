/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

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
import org.kde.kwindowsystem
import org.kde.plasma.private.mpris as Mpris
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
    property var pulseAudio
    

    readonly property bool useOverlayStyle: toolTipDelegate && toolTipDelegate.showThumbnails

    HoverHandler {
        id: rootHover
    }

    PlasmaExtras.Highlight {
        anchors.fill: parent
        anchors.margins: -Kirigami.Units.smallSpacing / 2
        visible: toolTipDelegate.isGroup && (root.isHovered || isWindowActive) && !toolTipDelegate.showThumbnails
        opacity: root.isHovered ? 1.0 : (isWindowActive ? 0.3 : 0.0)
        pressed: (rootHover.item as MouseArea)?.containsPress ?? false
        hovered: true
        z: -1
    }

    Kirigami.Separator {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Kirigami.Units.gridUnit
        anchors.rightMargin: Kirigami.Units.gridUnit
        
        // Show only in Text Mode (no thumbnails) and if NOT the last item
        visible: !toolTipDelegate.showThumbnails && toolTipDelegate.isGroup && (toolTipDelegate.windows && index < toolTipDelegate.windows.length - 1)
        opacity: 0.6 // More visible border
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
        if (toolTipDelegate.appName && toolTipDelegate.appName.length > 0) {
            return toolTipDelegate.appName;
        }

        const text = display;
        
        const versionRegex = /\s+(?:—|-|–)\s+([^\s(—|-|–)]+)\s+(?:—|-|–)\s+v?\d+(?:\.\d+)+.*$/i;
        const matchVersion = text.match(versionRegex);
        if (matchVersion && matchVersion[1]) {
            return matchVersion[1];
        }

        const lastSepRegex = /.*(?:—|-|–)\s+(.*)$/;
        const matchLast = text.match(lastSepRegex);
        if (matchLast && matchLast[1]) {
            return matchLast[1];
        }

        return "";
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

    // Media Player Data
    readonly property var playerData: {
        if (!mpris2Model) return null;
        if (!mpris2Model.playerForLauncherUrl) return null;
        const player = mpris2Model.playerForLauncherUrl(toolTipDelegate.launcherUrl, appPid);
        return player;
    }
    readonly property bool titleIncludesTrack: playerData && playerData.track && title.includes(playerData.track)

    required property bool isPlayingAudio
    required property bool isMuted

    // Audio Streams
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool hasAudioStream: audioStreams.length > 0
    // Use the model's IsMuted role as the primary source of truth for the initial state,
    // but check the stream's state for live updates.
    readonly property bool muted: isMuted || (hasAudioStream && audioStreams.every(item => item.muted))
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    
    function hasWindowSpecificStream(winId) {
        if (!winId || !hasAudioStream) return false;
        
        // Exact Match
        const exactMatch = audioStreams.some(stream => stream.windowId === winId);
        if (exactMatch) return true;
        
        return false;
    }

    Timer {
        id: streamClearTimer
        interval: 1000
        repeat: false
        onTriggered: root.audioStreams = []
    }

    function updateAudioStreams(args) {
        if (args && args.delay) {
             delayAudioStreamIndicator = true;
        }
        var currentForce = (args && args.force);

        var pa = root.pulseAudio.item;
        if (!pa) {
            streamClearTimer.stop();
            audioStreams = [];
            return;
        }

        // Check appid first for app using portal
        var streams = pa.streamsForAppId(appId.replace(/\.desktop/, '')); 
        if (!streams.length) {
            streams = pa.streamsForPid(appPid);
        }
        
        if (streams.length > 0) {
            var activeKey = appPid;
            var savedVol = pa.getCachedVolume(activeKey);
            
            var currentMax = streams.reduce((max, s) => Math.max(max, s.volume), 0);
            var seemsReset = (currentMax > 60000 && savedVol > 0 && Math.abs(currentMax - savedVol) > 2000);

            if ((streamClearTimer.running || seemsReset) && savedVol > 0) {
                 streams.forEach(s => s.setVolume(savedVol));
            }

            streamClearTimer.stop();
            audioStreams = streams;
        } else {
            if (audioStreams.length > 0 && !currentForce) {
                streamClearTimer.restart();
            } else {
                streamClearTimer.stop();
                audioStreams = []; 
            }
        }
    }

    function toggleMuted() {
        if (muted) {
            audioStreams.forEach(item => item.unmute());
        } else {
            audioStreams.forEach(item => item.mute());
        }
    }

    Connections {
        target: root.pulseAudio.item
        ignoreUnknownSignals: true
        function onStreamsChanged() {
             root.updateAudioStreams({delay: true});
        }
    }

    onAppPidChanged: updateAudioStreams({delay: false, force: true})
    onAppIdChanged: updateAudioStreams({delay: false, force: true})
    Component.onCompleted: updateAudioStreams({delay: false, force: true})



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
        spacing: Kirigami.Units.smallSpacing

    Layout.margins: 0 // Reset any default
    
    RowLayout {
        id: header
        visible: !root.useOverlayStyle
        Layout.preferredHeight: implicitHeight // Ensure height propagates to root
        spacing: Kirigami.Units.smallSpacing

        Layout.maximumWidth: toolTipDelegate.tooltipInstanceMaximumWidth
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        Layout.margins: 0
        Layout.fillWidth: true

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
                // text: root.calculatedAppName (already bound above)
                opacity: 1
                visible: text.length !== 0 && !toolTipDelegate.isGroup
                textFormat: Text.PlainText
            }
            PlasmaComponents3.Label {
                id: winTitle
                maximumLineCount: 1
                
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                
                text: root.titleIncludesTrack ? "" : root.title
                opacity: 0.75
                visible: root.title.length !== 0 && (toolTipDelegate.isGroup || root.title !== appNameHeading.text)
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
                visible: text.length !== 0 && text !== appNameHeading.text
                textFormat: Text.PlainText
            }
        }

        Item {
            Layout.alignment: Qt.AlignRight | Qt.AlignTop
            Layout.preferredHeight: closeButton.height
            Layout.preferredWidth: closeButton.width
            visible: root.index === 0 && toolTipDelegate.smartLauncherCountVisible

            Badge {
                anchors.centerIn: parent
                height: Kirigami.Units.iconSizes.smallMedium
                number: toolTipDelegate.smartLauncherCount
            }
        }

        PlasmaComponents3.ToolButton {
            id: closeButton
            Layout.alignment: Qt.AlignRight | Qt.AlignTop
            visible: toolTipDelegate.isWin
            icon.name: "window-close"
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
        Layout.fillWidth: true
        Layout.topMargin: -Kirigami.Units.smallSpacing // Tighter spacing to header
        
        active: !toolTipDelegate.showThumbnails && root.controlsAreEffective
        visible: active
        
        sourceComponent: mediaControlsComponent
    }

    Item {
        id: thumbnailSourceItem

        readonly property int targetWidth: Kirigami.Units.gridUnit * 14
        readonly property int targetHeight: Math.round(targetWidth / (Screen.width / Screen.height))

        Layout.preferredWidth: targetWidth
        Layout.preferredHeight: targetHeight

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
            opacity: thumbnailSourceItem.thumbnailAreaHovered ? 1.0 : (isWindowActive ? 0.3 : 0.0)
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
            anchors.margins: 1

            sourceComponent: root.isMinimized || pipeWireLoader.active ? iconItem : x11Thumbnail

            Component {
                id: x11Thumbnail
                PlasmaCore.WindowThumbnail {
                    winId: thumbnailSourceItem.winId
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

            active: !toolTipDelegate.isLauncher && !albumArtImage.visible && KWindowSystem.isPlatformWayland && root.index !== -1
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
                        pipeWireLoader.item.grabToImage(function(result) {
                            if (result && thumbnailSourceItem.winId) {
                                // Store full result object to prevent garbage collection of the URL
                                toolTipDelegate.thumbnailCache[thumbnailSourceItem.winId] = result;
                            }
                        });
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
            readonly property bool available: (status === Image.Ready || status === Image.Loading) && (!(toolTipDelegate.isGroup || backend.applicationCategories(launcherUrl).includes("WebBrowser")) || root.titleIncludesTrack)

            anchors.fill: hoverHandler
            anchors.margins: 1
            sourceSize: Qt.size(parent.width, parent.height)

            asynchronous: true
            source: toolTipDelegate.playerData?.artUrl ?? ""
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
            active: toolTipDelegate.showThumbnails && root.controlsAreEffective
            visible: active
            
            z: 2002 
            
            anchors.bottom: hoverHandler.bottom
            anchors.horizontalCenter: hoverHandler.horizontalCenter
            anchors.margins: Kirigami.Units.smallSpacing
            width: hoverHandler.width - (anchors.margins * 2)
            
            sourceComponent: Item { 
                 
                 readonly property Image source: albumArtImage
                 width: overlayControlsLoader.width
                 height: controlsColumn.height + (Kirigami.Units.smallSpacing * 2)
                
                readonly property bool hoveredState: thumbnailSourceItem.thumbnailAreaHovered
                readonly property bool isHovered: overlayHover.hovered
                readonly property bool childrenVisible: controlsColumn.children.some(child => child.visible)

                HoverHandler {
                    id: overlayHover
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.6)
                    radius: Kirigami.Units.smallSpacing
                    
                    opacity: parent.hoveredState ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                }
                
                ColumnLayout {
                    id: controlsColumn
                    anchors.centerIn: parent
                    width: parent.width - (Kirigami.Units.smallSpacing * 2)
                    
                    opacity: parent.hoveredState ? 1.0 : 0.4
                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

                    Loader {
                        sourceComponent: mediaControlsComponent
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // Title Overlay (Top-Left)

        // Title Overlay (Top-Left)
        Item {
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
            
            width: Kirigami.Units.iconSizes.smallMedium
            height: Kirigami.Units.iconSizes.smallMedium

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
}
    
    readonly property bool showPlayerControls: index !== -1 && playerData && playerData.canControl && 
        (
            hasWindowSpecificStream(thumbnailSourceItem.winId) || 
            titleIncludesTrack || 
            isPlayingAudio || 
            // Allow single-window apps to show if they have a stream (e.g. Spotify).
            // This also covers background tabs in parent processes (where WinID is missing).
            hasAudioStream
        ) &&
        (playerData.playbackStatus === Mpris.PlaybackStatus.Playing || 
         playerData.playbackStatus === Mpris.PlaybackStatus.Paused || 
         (playerData.track && playerData.track.length > 0))

    readonly property bool showVolumeControls: index !== -1 && pulseAudio.item !== null && audioIndicatorsEnabled && (isPlayingAudio || hasAudioStream)
    
    property bool controlsAreEffective: showPlayerControls || showVolumeControls
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

    // Reusable Media Controls Component
    Component {
        id: mediaControlsComponent
        
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            
            // MPRIS Controls
            Loader {
                id: playerController
                active: root.showPlayerControls
                asynchronous: false 
                visible: active
                Layout.fillWidth: true
                
                sourceComponent: PlayerController {
                    playerData: root.playerData
                    isWin: toolTipDelegate.isWin
                }
            }    

            // Volume Controls
            Loader {
                id: volumeControlsLoader
                active: root.showVolumeControls || (root.delayedControlsActive && root.hasAudioStream) // Keep visible during debounce if we had stream
                asynchronous: false 
                visible: active
                Layout.fillWidth: true

                sourceComponent: RowLayout {
                    PlasmaComponents3.ToolButton {
                        icon.width: Kirigami.Units.iconSizes.small
                        icon.height: Kirigami.Units.iconSizes.small
                      
                        icon.name: if (checked) {
                            "audio-volume-muted";
                        } else if (Math.round(slider.value / slider.to * 100) <= 25) {
                            "audio-volume-low";
                        } else if (Math.round(slider.value / slider.to * 100) <= 75) {
                            "audio-volume-medium";
                        } else {
                            "audio-volume-high";
                        }
                        
                        text: i18n("Mute")
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        checkable: true
                        checked: root.muted
                        onClicked: root.toggleMuted()
                    }

                    PlasmaComponents3.Slider {
                        id: slider
                        Layout.fillWidth: true
                        
                        from: root.pulseAudio.item.minimalVolume
                        to: root.pulseAudio.item.normalVolume
                        
                        // Use max volume of all streams
                        value: root.hasAudioStream && root.audioStreams.length > 0 ? 
                               root.audioStreams.reduce((max, s) => Math.max(max, s.volume), 0) : 0
                        
                        onMoved: {
                            root.audioStreams.forEach(item => {
                                // Scale relative to original volume if needed, or just set absolute?
                                // Simple approach: Set all streams to this volume
                                item.setVolume(value);
                                if (value > 0 && item.muted) item.unmute();
                            });
                        }
                    }
                    
                    PlasmaComponents3.Label {
                        text: Math.round(slider.value / slider.to * 100) + "%"
                        Layout.minimumWidth: 3 * Kirigami.Units.gridUnit 
                        horizontalAlignment: Text.AlignRight
                    }
                }
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
