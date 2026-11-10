/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import "code/singletones"

Item {
    id: barRoot

    required property var mediaController

    // Emitted when the track title is clicked. This row sits below the
    // thumbnail, outside the thumbnail's own activate-on-click area, so
    // nothing else here can activate the window (#55).
    signal activateRequested()

    width: parent.width
    height: Kirigami.Units.gridUnit * 1.4

    readonly property bool hasPlayer: mediaController ? mediaController.showPlayerControls : false
    readonly property bool hasVolume: mediaController ? mediaController.showVolumeControls : false
    // Volume-only mode: no player controls, just audio stream
    readonly property bool volumeOnlyMode: hasVolume && !hasPlayer

    // Local cached properties for optimized property bindings and less verbosity
    readonly property var player: mediaController ? mediaController.playerData : null
    readonly property var mediaRegistry: mediaController ? mediaController.mediaRegistry : null
    readonly property real appVolume: mediaController ? mediaController.appVolume : 0
    readonly property bool muted: mediaController ? mediaController.muted : false

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        PlayerController {
            visible: barRoot.hasPlayer
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            showText: false
            playerData: barRoot.player
            isWin: barRoot.mediaController && barRoot.mediaController.toolTipDelegate ? barRoot.mediaController.toolTipDelegate.isWin : false
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
                    if (!barRoot.player) return "";
                    let track = barRoot.player.track || "";
                    let artist = barRoot.player.artist || "";
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

            // songTextWrapper itself declines presses (it's only a MouseArea
            // for hover-to-scroll), so this nested one gets first refusal on
            // clicks landing here instead.
            MouseArea {
                anchors.fill: parent
                onClicked: barRoot.activateRequested()
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
                if (barRoot.muted) {
                    return "audio-volume-muted";
                }
                let volPercent = Math.round(barRoot.appVolume / 65536 * 100);
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
            checked: barRoot.muted
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
                        barRoot.mediaController.wheelVolume(wheel.angleDelta.y);
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
                            barRoot.mediaController.wheelVolume(wheel.angleDelta.y);
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
                            let volPercent = Math.round(barRoot.appVolume / 65536 * 100);
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

                        from: barRoot.mediaRegistry ? barRoot.mediaRegistry.minimalVolume : 0
                        to: barRoot.mediaRegistry ? barRoot.mediaRegistry.normalVolume : 65536
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
                            value: barRoot.appVolume
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
        MediaVolumeRow {
            visible: barRoot.volumeOnlyMode
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            mediaController: barRoot.mediaController
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
