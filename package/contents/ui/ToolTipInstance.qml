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
import Qt5Compat.GraphicalEffects as GE

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem

Item {
    id: root

    // Explicitly forward sizing from the layout
    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight

    required property int index
    required property /*QModelIndex*/        var submodelIndex
    required property int appPid
    required property string display
    required property bool isMinimized
    required property bool isOnAllVirtualDesktops
    required property /*list<var>*/        var virtualDesktops // Can't use list<var> because of QTBUG-127600
    required property list<string> activities

    // HACK: Avoid blank space in the tooltip after closing a window
    ListView.onPooled: width = height = 0
    ListView.onReused: width = height = undefined

    readonly property string title: {
        if (!toolTipDelegate.isWin) {
            return toolTipDelegate.genericName;
        }

        let text = display;
        if (toolTipDelegate.isGroup && text === "") {
            return "";
        }

        // Normally the window title will always have " — [app name]" at the end of
        // the window-provided title.
        // But if it doesn't, this is intentional 100%
        // of the time because the developer or user has deliberately removed that
        // part, so just display it with no more fancy processing.
        if (!text.match(/\s+(—|-|–)/)) {
            return text;
        }

        // KWin appends increasing integers in between pointy brackets to otherwise equal window titles.
        // In this case save <#number> as counter and delete it at the end of text.
        text = `${(text.match(/.*(?=\s+(—|-|–))/) || [""])[0]}${(text.match(/<\d+>/) || [""]).pop()}`;

        // In case the window title had only redundant information (i.e. appName), text is now empty.
        // Add a hyphen to indicate that and avoid empty space.
        if (text === "") {
            text = "—";
        }
        return text;
    }

    readonly property var winId: toolTipDelegate.isWin ? toolTipDelegate.windows[root.index] : undefined

    readonly property bool titleIncludesTrack: toolTipDelegate.playerData !== null && title.includes(toolTipDelegate.playerData.track)

    // Global MouseArea for the entire tooltip
    // Handles window highlight (hover) and thumbnail click behavior
    ToolTipWindowMouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 0 // Below controls like Close Button if they are above in z-order or layout order
        
        rootTask: toolTipDelegate.parentTask
        modelIndex: root.submodelIndex
        winId: root.winId
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        
        spacing: Kirigami.Units.smallSpacing

        // text labels + close button
        RowLayout {
            id: header
            // Spacing between text block and close button
            spacing: toolTipDelegate.isWin ? Kirigami.Units.smallSpacing : Kirigami.Units.gridUnit

            Layout.maximumWidth: toolTipDelegate.tooltipInstanceMaximumWidth
            Layout.minimumWidth: 0
            
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.margins: toolTipDelegate.isWin ? Kirigami.Units.smallSpacing : Kirigami.Units.gridUnit / 2
            Layout.fillWidth: true

            // all textlabels
            ColumnLayout {
                spacing: 0
                
                // This column must take all available space to the left of the button
                Layout.fillWidth: true
                Layout.minimumWidth: 0

                // app name
                MarqueeLabel {
                    id: appNameHeading
                    // Styling to match previous Heading level 3
                    font: Kirigami.Theme.defaultFont // Or strictly Heading font? Heading usually uses Theme.headerFont.
                    // To be safe/consistent with Plasma style:
                    // Using default font with bold might be closer if Heading component isn't used directly
                    // But MarqueeLabel wraps Label which uses default font.
                    // Let's use standard font for now, maybe bold it.
                    // Heading level 3 is usually larger.
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                    font.weight: Font.Bold

                    Layout.fillWidth: true

                    text: toolTipDelegate.appName
                    opacity: root.index === 0 ? 1 : 0
                    visible: text.length !== 0
                }
                
                // window title
                MarqueeLabel {
                    id: winTitle

                    Layout.fillWidth: true

                    text: root.titleIncludesTrack ? "" : root.title
                    opacity: 0.75
                    visible: root.title.length !== 0 && root.title !== appNameHeading.text
                }
                // subtext removed as per requirements
            }

            // Count badge.
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

            // close button
            PlasmaComponents3.ToolButton {
                id: closeButton
                Layout.alignment: Qt.AlignRight | Qt.AlignTop
                // Ensure z-index is higher than background MouseArea if needed, though RowLayout children should be on top of anchors.fill sibling
                z: 1

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

        // thumbnail container
        Item {
            id: thumbnailSourceItem

            readonly property int targetWidth: Kirigami.Units.gridUnit * 14
            readonly property int targetHeight: targetWidth / (Screen.width / Screen.height)

            // Fill the width of the Layout (which is constrained by header max width usually)
            Layout.fillWidth: true
            Layout.preferredHeight: targetHeight

            Layout.alignment: Qt.AlignCenter
            clip: true
            visible: toolTipDelegate.isWin

            // winId property moved to root

            PlasmaExtras.Highlight {
                anchors.fill: parent
                // Check the root MouseArea for hover state
                visible: (mouseArea.containsMouse)
                // But mouseArea isn't id'd. Let's id it.
                // Wait, ToolTipWindowMouseArea handles hover logic internally via windowsHovered.
                // This Highlight is visual. It should show when hovered.
                // Since the mouse area covers the whole tooltip now, this highlight will show when hovering header too?
                // The requirement: "Hovering... over the tooltip... window should be highlighted".
                // The visual highlight inside the thumbnail usually indicates the thumbnail is active/hovered.
                // If I hover the header, should the thumbnail light up? Probably yes, if "window highlighted" implies the external window.
                // But this PlasmaExtras.Highlight is a UI element *on* the thumbnail.
                // I will assume it should follow the mouse presence on the tooltip.
                // However, I need to reference the MouseArea.
            }

            Loader {
                id: thumbnailLoader
                active: !toolTipDelegate.isLauncher && !albumArtImage.visible && (Number.isInteger(root.winId) || pipeWireLoader.item && !pipeWireLoader.item.hasThumbnail) && root.index !== -1
                asynchronous: true
                visible: active

                anchors.fill: parent
                anchors.margins: 0

                sourceComponent: root.isMinimized || pipeWireLoader.active ? iconItem : x11Thumbnail

                Component {
                    id: x11Thumbnail
                    PlasmaCore.WindowThumbnail {
                        winId: root.winId
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
                anchors.fill: parent
                // Indent a little bit so that neither the thumbnail nor the drop
                // shadow can cover up the highlight
                anchors.margins: thumbnailLoader.anchors.margins

                active: !toolTipDelegate.isLauncher && !albumArtImage.visible && KWindowSystem.isPlatformWayland && root.index !== -1
                asynchronous: true
                //In a loader since we might not have PipeWire available yet (WITH_PIPEWIRE could be undefined in plasma-workspace/libtaskmanager/declarative/taskmanagerplugin.cpp)
                source: "PipeWireThumbnail.qml"
            }

            Loader {
                active: (pipeWireLoader.item?.hasThumbnail ?? false) || (thumbnailLoader.status === Loader.Ready && !root.isMinimized)
                asynchronous: true
                visible: active
                anchors.fill: pipeWireLoader.active ? pipeWireLoader : thumbnailLoader

                sourceComponent: GE.DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 3
                    radius: 8
                    samples: Math.round(radius * 1.5)
                    color: "Black"
                    source: pipeWireLoader.active ? pipeWireLoader.item : thumbnailLoader.item // source could be undefined when albumArt is available, so put it in a Loader.
                }
            }

            Loader {
                active: albumArtImage.visible && albumArtImage.status === Image.Ready && root.index !== -1 // Avoid loading when the instance is going to be destroyed
                asynchronous: true
                visible: active
                anchors.centerIn: parent

                sourceComponent: ShaderEffect {
                    id: albumArtBackground
                    readonly property Image source: albumArtImage

                    // Manual implementation of Image.PreserveAspectCrop
                    // Use parent (thumbnailSourceItem) for sizing
                    readonly property real scaleFactor: Math.max(thumbnailSourceItem.width / source.paintedWidth, thumbnailSourceItem.height / source.paintedHeight)
                    width: Math.round(source.paintedWidth * scaleFactor)
                    height: Math.round(source.paintedHeight * scaleFactor)
                    layer.enabled: true
                    opacity: 0.25
                    layer.effect: GE.FastBlur {
                        source: albumArtBackground
                        anchors.fill: source
                        radius: 30
                    }
                }
            }

            Image {
                id: albumArtImage
                // also Image.Loading to prevent loading thumbnails just because the album art takes a split second to load
                // if this is a group tooltip, we check if window title and track match, to allow distinguishing the different windows
                // if this app is a browser, we also check the title, so album art is not shown when the user is on some other tab
                // in all other cases we can safely show the album art without checking the title
                readonly property bool available: (status === Image.Ready || status === Image.Loading) && (!(toolTipDelegate.isGroup || backend.applicationCategories(launcherUrl).includes("WebBrowser")) || root.titleIncludesTrack)

                anchors.fill: parent
                // Indent by one pixel to make sure we never cover up the entire highlight
                anchors.margins: 1
                sourceSize: Qt.size(parent.width, parent.height)

                asynchronous: true
                source: toolTipDelegate.playerData?.artUrl ?? ""
                fillMode: Image.PreserveAspectFit
                visible: available
            }

            // Removed the Loader for hoverHandler here, as it is now at the root level.
        }

        // Player controls row, load on demand so group tooltips could be loaded faster
        Loader {
            id: playerController
            active: toolTipDelegate.playerData && root.index !== -1 // Avoid loading when the instance is going to be destroyed
            asynchronous: true
            visible: active
            Layout.fillWidth: true
            Layout.maximumWidth: header.Layout.maximumWidth
            Layout.leftMargin: header.Layout.margins
            Layout.rightMargin: header.Layout.margins

            source: "PlayerController.qml"
        }

        // Volume controls
        Loader {
            active: toolTipDelegate.parentTask !== null && pulseAudio.item !== null && toolTipDelegate.parentTask.audioIndicatorsEnabled && toolTipDelegate.parentTask.hasAudioStream && root.index !== -1 // Avoid loading when the instance is going to be destroyed
            asynchronous: true
            visible: active
            Layout.fillWidth: true
            Layout.maximumWidth: header.Layout.maximumWidth
            Layout.leftMargin: header.Layout.margins
            Layout.rightMargin: header.Layout.margins
            sourceComponent: RowLayout {
                PlasmaComponents3.ToolButton {
                    // Mute button
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
                    onClicked: toolTipDelegate.parentTask.toggleMuted()
                    checked: toolTipDelegate.parentTask.muted

                    PlasmaComponents3.ToolTip {
                        text: parent.checked ? i18nc("button to unmute app", "Unmute %1", toolTipDelegate.parentTask.appName) : i18nc("button to mute app", "Mute %1", toolTipDelegate.parentTask.appName)
                    }
                }

                PlasmaComponents3.Slider {
                    id: slider

                    readonly property int displayValue: Math.round(value / to * 100)
                    readonly property int loudestVolume: toolTipDelegate.parentTask.audioStreams.reduce((loudestVolume, stream) => Math.max(loudestVolume, stream.volume), 0)

                    Layout.fillWidth: true
                    from: pulseAudio.item.minimalVolume
                    to: pulseAudio.item.normalVolume
                    value: loudestVolume
                    stepSize: to / 100
                    opacity: toolTipDelegate.parentTask.muted ? 0.5 : 1

                    Accessible.name: i18nc("Accessibility data on volume slider", "Adjust volume for %1", toolTipDelegate.parentTask.appName)

                    onMoved: toolTipDelegate.parentTask.audioStreams.forEach(stream => {
                        let v = Math.max(from, value);
                        if (v > 0 && loudestVolume > 0) {
                            // prevent divide by 0
                            // adjust volume relative to the loudest stream
                            v = Math.min(Math.round(stream.volume / loudestVolume * v), to);
                        }
                        stream.model.Volume = v;
                        stream.model.Muted = v === 0;
                    })
                }
                PlasmaComponents3.Label {
                    // percent label
                    Layout.alignment: Qt.AlignHCenter
                    Layout.minimumWidth: percentMetrics.advanceWidth
                    horizontalAlignment: Qt.AlignRight
                    text: i18nc("volume percentage", "%1%", slider.displayValue)
                    textFormat: Text.PlainText
                    TextMetrics {
                        id: percentMetrics
                        text: i18nc("only used for sizing, should be widest possible string", "100%")
                    }
                }
            }
        }

        // generateSubText() function removed as it is no longer used
    }
}
