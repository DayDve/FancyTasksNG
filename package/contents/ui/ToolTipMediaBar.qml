/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.mpris as Mpris

import "code/singletones"

Item {
    id: barRoot

    required property var mediaController

    width: parent.width
    height: Kirigami.Units.gridUnit * 1.4

    readonly property bool hasPlayer: mediaController ? mediaController.showPlayerControls : false
    readonly property bool hasVolume: mediaController ? mediaController.showVolumeControls : false
    // Volume-only mode: no player controls, just audio stream
    readonly property bool volumeOnlyMode: hasVolume && !hasPlayer



    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // [prev][play/pause][next] Buttons
        RowLayout {
            id: playerButtons
            visible: barRoot.hasPlayer
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            PlasmaComponents3.ToolButton {
                implicitWidth: Kirigami.Units.gridUnit * 1.2
                implicitHeight: Kirigami.Units.gridUnit * 1.2
                padding: 0
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small

                enabled: barRoot.mediaController && barRoot.mediaController.playerData ? barRoot.mediaController.playerData.canGoPrevious : false
                icon.name: mirrored ? "media-skip-forward" : "media-skip-backward"
                onClicked: if (barRoot.mediaController && barRoot.mediaController.playerData) barRoot.mediaController.playerData.Previous()
            }

            PlasmaComponents3.ToolButton {
                implicitWidth: Kirigami.Units.gridUnit * 1.2
                implicitHeight: Kirigami.Units.gridUnit * 1.2
                padding: 0
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small

                readonly property bool isPlaying: barRoot.mediaController && barRoot.mediaController.playerData ? barRoot.mediaController.playerData.playbackStatus === Mpris.PlaybackStatus.Playing : false
                enabled: barRoot.mediaController && barRoot.mediaController.playerData ? (isPlaying ? barRoot.mediaController.playerData.canPause : barRoot.mediaController.playerData.canPlay) : false
                icon.name: isPlaying ? "media-playback-pause" : "media-playback-start"
                onClicked: {
                    if (barRoot.mediaController && barRoot.mediaController.playerData) {
                        if (!isPlaying) {
                            barRoot.mediaController.playerData.Play();
                        } else {
                            barRoot.mediaController.playerData.Pause();
                        }
                    }
                }
            }

            PlasmaComponents3.ToolButton {
                implicitWidth: Kirigami.Units.gridUnit * 1.2
                implicitHeight: Kirigami.Units.gridUnit * 1.2
                padding: 0
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small

                enabled: barRoot.mediaController && barRoot.mediaController.playerData ? barRoot.mediaController.playerData.canGoNext : false
                icon.name: mirrored ? "media-skip-backward" : "media-skip-forward"
                onClicked: if (barRoot.mediaController && barRoot.mediaController.playerData) barRoot.mediaController.playerData.Next()
            }
        }

        // Scrollable track/artist title with fade hint when text overflows
        ScrollableTextWrapper {
            id: songTextWrapper
            visible: barRoot.hasPlayer
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: songText.height
            implicitWidth: songText.implicitWidth

            textItem: PlasmaComponents3.Label {
                id: songText
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                elide: parent.state ? Text.ElideNone : Text.ElideRight
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                textFormat: Text.PlainText
                text: {
                    if (!barRoot.mediaController || !barRoot.mediaController.playerData) return "";
                    let track = barRoot.mediaController.playerData.track || "";
                    let artist = barRoot.mediaController.playerData.artist || "";
                    if (track && artist) {
                        return artist + " - " + track;
                    }
                    return track || artist || "";
                }
            }

            // Fade hint on the right edge so users know the text continues
            Rectangle {
                visible: songTextWrapper.state === "" && songText.implicitWidth > songTextWrapper.width
                anchors.right: parent.right
                width: Kirigami.Units.gridUnit * 1.5
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Kirigami.Theme.backgroundColor }
                }
            }
        }

        // [D] - Mute & Hover Volume Button (only when player controls are present)
        PlasmaComponents3.ToolButton {
            id: volumeButton
            visible: barRoot.hasVolume && !barRoot.volumeOnlyMode
            implicitWidth: Kirigami.Units.gridUnit * 1.2
            implicitHeight: Kirigami.Units.gridUnit * 1.2
            padding: 0
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
            Layout.alignment: Qt.AlignVCenter

            icon.name: {
                if (barRoot.mediaController && barRoot.mediaController.muted) {
                    return "audio-volume-muted";
                }
                let volPercent = barRoot.mediaController ? Math.round(barRoot.mediaController.appVolume / 65536 * 100) : 0;
                if (volPercent <= 25) {
                    return "audio-volume-low";
                } else if (volPercent <= 75) {
                    return "audio-volume-medium";
                } else {
                    return "audio-volume-high";
                }
            }

            text: Wrappers.i18n("Mute")
            display: PlasmaComponents3.AbstractButton.IconOnly
            checkable: true
            checked: barRoot.mediaController ? barRoot.mediaController.muted : false
            onClicked: {
                if (barRoot.mediaController) {
                    barRoot.mediaController.toggleMuted();
                }
            }

            // Hover tracking to show vertical slider
            HoverHandler {
                id: volumeButtonHover
            }

            // Mouse wheel support directly on the icon!
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    if (barRoot.mediaController) {
                        // Scale by actual scroll delta so touchpad kinetic micro-events
                        // don't cause full 5% jumps. Standard wheel notch = 120 units = 5%.
                        let step = Math.round(65536 * 0.05 * wheel.angleDelta.y / 120);
                        if (step !== 0)
                            barRoot.mediaController.adjustAppVolume(step);
                        wheel.accepted = true;
                    }
                }
            }

            // Vertical Pop-up Volume Slider (Declared inside the button to allow proper anchors to parent)
            Item {
                id: volumePopup
                visible: barRoot.showSlider && barRoot.hasVolume
                width: Kirigami.Units.gridUnit * 1.7
                height: Kirigami.Units.gridUnit * 6.5
                
                // Align right edge of popup to right edge of the button
                // so it never overflows the tooltip boundary
                anchors.bottom: parent.top
                anchors.bottomMargin: Kirigami.Units.smallSpacing
                anchors.right: parent.right
                z: 99999

                // Keep popup alive when hovered
                HoverHandler {
                    id: sliderHover
                }

                // Global wheel listener for the entire popup (including Label and Slider)
                // Using acceptedButtons: Qt.NoButton lets clicks/drags pass through to the Slider below,
                // while cleanly intercepting all scroll events!
                MouseArea {
                    anchors.fill: parent
                    z: 99999
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        if (barRoot.mediaController) {
                            let step = Math.round(65536 * 0.05 * wheel.angleDelta.y / 120);
                            if (step !== 0)
                                barRoot.mediaController.adjustAppVolume(step);
                            wheel.accepted = true;
                        }
                    }
                }

                // Semi-transparent background so slider doesn't blend into thumbnail
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.55)
                    radius: Kirigami.Units.smallSpacing
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: 2

                    PlasmaComponents3.Label {
                        text: {
                            let volPercent = barRoot.mediaController ? Math.round(barRoot.mediaController.appVolume / 65536 * 100) : 0;
                            return volPercent + "%";
                        }
                        color: "white"
                        font.bold: false
                        opacity: 0.85
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    PlasmaComponents3.Slider {
                        id: volumeSlider
                        orientation: Qt.Vertical
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        
                        topPadding: 6
                        bottomPadding: 6

                        from: barRoot.mediaController && barRoot.mediaController.audioStreamManager ? barRoot.mediaController.audioStreamManager.item.minimalVolume : 0
                        to: barRoot.mediaController && barRoot.mediaController.audioStreamManager ? barRoot.mediaController.audioStreamManager.item.normalVolume : 65536
                        // Block built-in QML Slider wheel handling completely to prevent duplicate scroll bugs!
						WheelHandler {
							acceptedButtons: Qt.NoButton
							onWheel: (event) => {
								event.accepted = true;
							}
						}

						Binding {
							target: volumeSlider
							property: "value"
							value: barRoot.mediaController ? barRoot.mediaController.appVolume : 0
							when: !volumeSlider.pressed
						}

                        onMoved: {
                            if (barRoot.mediaController) {
                                barRoot.mediaController.setVolume(value);
                            }
                        }

                        // Custom handle to make it elegant and prevent clunky look
                        handle: Rectangle {
                            id: handleRect
                            x: volumeSlider.leftPadding + (volumeSlider.availableWidth - width) / 2
                            y: volumeSlider.topPadding + volumeSlider.visualPosition * (volumeSlider.availableHeight - height)
                            
                            // Dynamic sizing: 8px default, 12px on hover/press
                            width: handleHover.hovered || volumeSlider.pressed ? 12 : 8
                            height: width
                            radius: width / 2
                            
                            color: volumeSlider.pressed ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                            border.color: Kirigami.Theme.backgroundColor
                            border.width: 1
                            
                            HoverHandler {
                                id: handleHover
                            }
                            
                            Behavior on width {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        
                        // Custom background track
                        background: Rectangle {
                            x: volumeSlider.leftPadding + (volumeSlider.availableWidth - width) / 2
                            y: volumeSlider.topPadding
                            width: 3
                            height: volumeSlider.availableHeight
                            radius: 1.5
                            color: Qt.rgba(255, 255, 255, 0.15)
                            
                            Rectangle {
                                width: parent.width
                                height: parent.height - volumeSlider.visualPosition * parent.height
                                y: parent.height - height
                                color: Kirigami.Theme.highlightColor
                                radius: 1.5
                            }
                        }

                     }
                }
            }
        }

        // Inline horizontal volume slider for volume-only mode (no player controls)
        RowLayout {
            visible: barRoot.volumeOnlyMode
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignVCenter

            MouseArea {
                anchors.fill: parent
                z: 1
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    if (barRoot.mediaController) {
                        let step = Math.round(65536 * 0.05 * wheel.angleDelta.y / 120);
                        if (step !== 0)
                            barRoot.mediaController.adjustAppVolume(step);
                        wheel.accepted = true;
                    }
                }
            }

            PlasmaComponents3.ToolButton {
                implicitWidth: Kirigami.Units.gridUnit * 1.2
                implicitHeight: Kirigami.Units.gridUnit * 1.2
                padding: 0
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small

                icon.name: {
                    if (checked) return "audio-volume-muted";
                    let pct = Math.round(inlineVolumeSlider.value / inlineVolumeSlider.to * 100);
                    if (pct <= 25) return "audio-volume-low";
                    if (pct <= 75) return "audio-volume-medium";
                    return "audio-volume-high";
                }

                text: Wrappers.i18n("Mute")
                display: PlasmaComponents3.AbstractButton.IconOnly
                checkable: true
                checked: barRoot.mediaController ? barRoot.mediaController.muted : false
                onClicked: {
                    if (barRoot.mediaController)
                        barRoot.mediaController.toggleMuted();
                }
            }

            PlasmaComponents3.Slider {
                id: inlineVolumeSlider
                Layout.fillWidth: true
                topPadding: 4
                bottomPadding: 4

                from: barRoot.mediaController && barRoot.mediaController.audioStreamManager ? barRoot.mediaController.audioStreamManager.item.minimalVolume : 0
                to: barRoot.mediaController && barRoot.mediaController.audioStreamManager ? barRoot.mediaController.audioStreamManager.item.normalVolume : 65536

                WheelHandler {
                    acceptedButtons: Qt.NoButton
                    onWheel: (event) => {
                        event.accepted = true;
                    }
                }

                Binding {
                    target: inlineVolumeSlider
                    property: "value"
                    value: barRoot.mediaController ? barRoot.mediaController.appVolume : 0
                    when: !inlineVolumeSlider.pressed
                }

                onMoved: {
                    if (barRoot.mediaController)
                        barRoot.mediaController.setVolume(value);
                }

                handle: Rectangle {
                    x: inlineVolumeSlider.leftPadding + inlineVolumeSlider.visualPosition * (inlineVolumeSlider.availableWidth - width)
                    y: inlineVolumeSlider.topPadding + (inlineVolumeSlider.availableHeight - height) / 2

                    width: inlineHandleHover.hovered || inlineVolumeSlider.pressed ? 10 : 6
                    height: width
                    radius: width / 2

                    color: inlineVolumeSlider.pressed ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    border.color: Kirigami.Theme.backgroundColor
                    border.width: 1

                    HoverHandler { id: inlineHandleHover }

                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }

                background: Rectangle {
                    x: inlineVolumeSlider.leftPadding
                    y: inlineVolumeSlider.topPadding + (inlineVolumeSlider.availableHeight - height) / 2
                    width: inlineVolumeSlider.availableWidth
                    height: 2
                    radius: 1
                    color: Qt.rgba(255, 255, 255, 0.15)

                    Rectangle {
                        width: inlineVolumeSlider.visualPosition * parent.width
                        height: parent.height
                        color: Kirigami.Theme.highlightColor
                        radius: 1
                    }
                }
            }

            PlasmaComponents3.Label {
                text: Math.round(inlineVolumeSlider.value / inlineVolumeSlider.to * 100) + "%"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 1.5
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Hover State Logic for vertical slider
    property bool showSlider: volumeButtonHover.hovered || sliderHover.hovered || hoverTimer.running

    onShowSliderChanged: {
        if (!showSlider) {
            hoverTimer.stop();
        }
    }

    Timer {
        id: hoverTimer
        interval: 250 // highly responsive and smooth fade-out delay
        repeat: false
    }

    // Trigger timer when mouse leaves
    Connections {
        target: volumeButtonHover
        function onHoveredChanged() {
            if (!volumeButtonHover.hovered && !sliderHover.hovered) {
                hoverTimer.start();
            } else {
                hoverTimer.stop();
            }
        }
    }

    Connections {
        target: sliderHover
        function onHoveredChanged() {
            if (!volumeButtonHover.hovered && !sliderHover.hovered) {
                hoverTimer.start();
            } else {
                hoverTimer.stop();
            }
        }
    }
}
