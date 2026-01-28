/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem
import org.kde.plasma.private.mpris as Mpris

import "code/singletones"

ColumnLayout {
    id: root
    
    anchors.margins: Kirigami.Units.gridUnit

    readonly property alias isHovered: rootHover.hovered

    required property var toolTipDelegate
    required property var tasksModel
    property var mpris2Model

    // FIX: Свойство для приема явного ID окна из делегата
    property var explicitWinId: undefined
    property var pulseAudio

    HoverHandler {
        id: rootHover
    }

    required property int index
    required property var submodelIndex
    required property int appPid
    property string appId: ""
    required property string display
    required property bool isMinimized
    required property bool isOnAllVirtualDesktops
    required property var virtualDesktops
    required property list<string> activities

    readonly property string calculatedAppName: {
        console.log("ToolTipInstance (" + index + ") Pid: " + appPid + " AppId: " + appId + " Url: " + toolTipDelegate.launcherUrl)
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
    readonly property var playerData: mpris2Model && mpris2Model.playerForLauncherUrl ? mpris2Model.playerForLauncherUrl(toolTipDelegate.launcherUrl, appPid) : null
    readonly property bool titleIncludesTrack: playerData !== null && title.includes(playerData.track)

    // Audio Streams
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    function updateAudioStreams(args) {
        if (args && args.delay) {
             delayAudioStreamIndicator = true;
        }
        var pa = root.pulseAudio.item;
        if (!pa) {
            audioStreams = [];
            return;
        }

        // Check appid first for app using portal
        // https://docs.pipewire.org/page_portal.html
        // Check appid first for app using portal
        // https://docs.pipewire.org/page_portal.html
        var streams = pa.streamsForAppId(appId.replace(/\.desktop/, '')); 
        if (!streams.length) {
            streams = pa.streamsForPid(appPid);
            if (streams.length) {
                // pa.registerPidMatch(calculatedAppName); 
            } else {
                 if (!pa.hasPidMatch(calculatedAppName)) {
                     streams = pa.streamsForAppName(calculatedAppName);
                 }
            }
        }
        audioStreams = streams;
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

    onAppPidChanged: updateAudioStreams({delay: false})
    onAppIdChanged: updateAudioStreams({delay: false})
    Component.onCompleted: updateAudioStreams({delay: false})

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        id: header
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
                opacity: root.index === 0 ? 1 : 0
                visible: text.length !== 0
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
                visible: root.title.length !== 0 && root.title !== appNameHeading.text
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
                tasksModel.requestClose(root.submodelIndex);
            }
        }
    }

    Item {
        id: thumbnailSourceItem

        readonly property int targetWidth: Kirigami.Units.gridUnit * 14
        readonly property int targetHeight: targetWidth / (Screen.width / Screen.height)

        Layout.preferredWidth: targetWidth
        Layout.preferredHeight: targetHeight

        Layout.alignment: Qt.AlignCenter
        clip: true
        
        visible: toolTipDelegate.isWin && Plasmoid.configuration.showToolTips

        // FIX: Использование явного ID если он передан, иначе fallback (хотя explicitWinId теперь будет всегда для групп)
        readonly property var winId: explicitWinId !== undefined ?
            explicitWinId : (toolTipDelegate.isWin ? toolTipDelegate.windows[root.index] : undefined)

        PlasmaExtras.Highlight {
            anchors.fill: hoverHandler 
            visible: rootHover.hovered
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
                    opacity: pipeWireLoader.active ? 0 : 1
                    
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.gridUnit 

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
            }
        }
    }

    Loader {
        id: playerController
        active: root.playerData && 
                root.playerData.canControl && 
                root.index !== -1 &&
                (root.playerData.playbackStatus === Mpris.PlaybackStatus.Playing || 
                 root.playerData.playbackStatus === Mpris.PlaybackStatus.Paused || 
                 (root.playerData.track && root.playerData.track.length > 0))
        asynchronous: false 
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: header.Layout.maximumWidth
        Layout.leftMargin: header.Layout.margins
        Layout.rightMargin: header.Layout.margins

        sourceComponent: PlayerController {
            playerData: root.playerData
            isWin: toolTipDelegate.isWin
        }
    }    

    Loader {
        active: root.pulseAudio.item !== null && root.audioIndicatorsEnabled && root.hasAudioStream && root.index !== -1 
        asynchronous: false 
        visible: active
        Layout.fillWidth: true
        Layout.maximumWidth: header.Layout.maximumWidth
        Layout.leftMargin: header.Layout.margins
        Layout.rightMargin: header.Layout.margins
        sourceComponent: RowLayout {
            PlasmaComponents3.ToolButton {
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
              
                icon.name: if (checked) {
                    "audio-volume-muted";
                } else if (slider.displayValue <= 25) {
                    "audio-volume-low";
                } else if (slider.displayValue <= 75) {
                    "audio-volume-medium";
                } else {
                    "audio-volume-high";
                }
                onClicked: root.toggleMuted()
                checked: root.muted

                PlasmaComponents3.ToolTip {
                    text: parent.checked ? Wrappers.i18nc("button to unmute app", "Unmute %1", root.calculatedAppName) : Wrappers.i18nc("button to mute app", "Mute %1", root.calculatedAppName)
                }
            }

            PlasmaComponents3.Slider {
                id: slider
                readonly property int displayValue: Math.round(value / to * 100)
                readonly property int loudestVolume: root.audioStreams.reduce((loudestVolume, stream) => Math.max(loudestVolume, stream.volume), 0)

                Layout.fillWidth: true
                from: root.pulseAudio.item.minimalVolume
                to: root.pulseAudio.item.normalVolume
                value: loudestVolume
                stepSize: to / 100
                opacity: root.audioStreams.every(stream => stream.muted) ? 0.5 : 1

                Accessible.name: Wrappers.i18nc("Accessibility data on volume slider", "Adjust volume for %1", root.calculatedAppName)

                onMoved: root.audioStreams.forEach(stream => {
                    let v = Math.max(from, value);
                    if (v > 0 && loudestVolume > 0) {
                        v = Math.min(Math.round(stream.volume / loudestVolume * v), to);
                    }
                    stream.model.Volume = v;
                    stream.model.Muted = v === 0;
                })
            }
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.minimumWidth: percentMetrics.advanceWidth
                horizontalAlignment: Qt.AlignRight
            
                text: Wrappers.i18nc("volume percentage", "%1%", slider.displayValue)
               
                textFormat: Text.PlainText
                TextMetrics {
                    id: percentMetrics
                    text: Wrappers.i18nc("only used for sizing, should be widest possible string", "100%")
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
}
