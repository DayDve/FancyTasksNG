/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickAddons

import "../ui/code/singletones"

ConfigPage {
    id: cfg_page

    // Silence KCM errors for legacy/removed properties
    readonly property bool plasmaPaAvailable: Qt.createComponent("../ui/PulseAudio.qml").status === Component.Ready

    readonly property bool isLineStyle: cfg_page.cfg_indicatorStyle === 0

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        LivePreview {
            cfg_page: cfg_page
            Layout.fillWidth: true
        }

        Item {
            id: containerWrapper
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            property int scrollDir: 0
            property real _lastY: 0
            
            Component.onCompleted: _lastY = scrollView.contentItem.contentY

            Connections {
                target: scrollView.contentItem
                function onContentYChanged() {
                    let dy = scrollView.contentItem.contentY - containerWrapper._lastY
                    if (Math.abs(dy) > 0.5) {
                        containerWrapper.scrollDir = dy > 0 ? 1 : -1
                        scrollDirTimer.restart()
                    }
                    containerWrapper._lastY = scrollView.contentItem.contentY
                }
            }
            
            Timer {
                id: scrollDirTimer
                interval: 150
                onTriggered: containerWrapper.scrollDir = 0
            }

            ScrollView {
                id: scrollView
                anchors.fill: parent
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Kirigami.FormLayout {
                    width: parent.width - Kirigami.Units.gridUnit * 2

            Label {
                text: Wrappers.i18n("Active application indicators:")
            }

            CheckBox {
                id: indicatorsEnabled
                text: Wrappers.i18n("Enable")
                checked: cfg_page.cfg_indicatorsEnabled
                onToggled: cfg_page.cfg_indicatorsEnabled = checked
            }

            CheckBox {
                visible: indicatorsEnabled.checked
                id: indicatorsAnimated
                text: Wrappers.i18n("Animate indicators")
                checked: cfg_page.cfg_indicatorsAnimated
                onToggled: cfg_page.cfg_indicatorsAnimated = checked
            }

            Item { height: Kirigami.Units.largeSpacing; visible: indicatorsEnabled.checked }

            RowLayout {
                visible: indicatorsEnabled.checked
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Style:")
                }
                ComboBox {
                    id: indicatorStyle
                    Layout.fillWidth: true
                    model: [
                        Wrappers.i18n("Line"),
                        Wrappers.i18n("Dashes")
                    ]
                    currentIndex: cfg_page.cfg_indicatorStyle
                    onActivated: (index) => cfg_page.cfg_indicatorStyle = index
                }
            }

            CheckBox {
                visible: indicatorsEnabled.checked
                id: indicatorOverride
                text: Wrappers.i18n("Override indicator location")
                checked: cfg_page.cfg_indicatorOverride
                onToggled: cfg_page.cfg_indicatorOverride = checked
            }

            ComboBox {
                visible: indicatorsEnabled.checked && indicatorOverride.checked
                id: indicatorLocation
                Layout.fillWidth: true
                model: [
                    Wrappers.i18n("Bottom"),
                    Wrappers.i18n("Left"),
                    Wrappers.i18n("Right"),
                    Wrappers.i18n("Top")
                ]
                currentIndex: cfg_page.cfg_indicatorLocation
                onActivated: (index) => cfg_page.cfg_indicatorLocation = index
            }

            Item { height: Kirigami.Units.smallSpacing; visible: indicatorsEnabled.checked }

            RowLayout {
                visible: indicatorsEnabled.checked
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Edge offset:")
                }
                SpinBox {
                    id: indicatorEdgeOffset
                    from: 0
                    to: 999
                    value: cfg_page.cfg_indicatorEdgeOffset
                    onValueModified: cfg_page.cfg_indicatorEdgeOffset = value
                }
                Label {
                    text: "px"
                }
            }

            RowLayout {
                visible: indicatorsEnabled.checked
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Thickness:")
                }
                SpinBox {
                    id: indicatorSize
                    from: 1
                    to: 999
                    value: cfg_page.cfg_indicatorSize
                    onValueModified: cfg_page.cfg_indicatorSize = value
                }
                Label {
                    text: "px"
                }

                Item { width: Kirigami.Units.largeSpacing }

                Label {
                    text: Wrappers.i18n("Segment length:")
                }
                SpinBox {
                    id: indicatorLength
                    from: 1
                    to: 999
                    value: cfg_page.cfg_indicatorLength
                    onValueModified: cfg_page.cfg_indicatorLength = value
                }
                Label {
                    text: "px"
                }
            }

            RowLayout {
                visible: indicatorsEnabled.checked
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Roundness:")
                }
                SpinBox {
                    id: indicatorRadius
                    from: 0
                    to: 100
                    value: cfg_page.cfg_indicatorRadius
                    onValueModified: cfg_page.cfg_indicatorRadius = value
                }
                Label {
                    text: "%"
                }

                Item { width: Kirigami.Units.largeSpacing; visible: cfg_page.isLineStyle }

                Label {
                    visible: cfg_page.isLineStyle
                    text: Wrappers.i18n("Side padding:")
                }
                SpinBox {
                    id: indicatorShrink
                    visible: cfg_page.isLineStyle
                    from: 0
                    to: 999
                    value: cfg_page.cfg_indicatorShrink
                    onValueModified: cfg_page.cfg_indicatorShrink = value
                }
                Label {
                    visible: cfg_page.isLineStyle
                    text: "px"
                }
            }

            CheckBox {
                visible: indicatorsEnabled.checked && cfg_page.isLineStyle
                text: Wrappers.i18n("Darken extra segments")
                checked: cfg_page.cfg_indicatorDarkenExtras
                onToggled: cfg_page.cfg_indicatorDarkenExtras = checked
            }

            Item { height: Kirigami.Units.largeSpacing; visible: indicatorsEnabled.checked }

            RowLayout {
                visible: indicatorsEnabled.checked
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Max segments:")
                }
                SpinBox {
                    id: indicatorMaxLimit
                    from: 1
                    to: 99
                    value: cfg_page.cfg_indicatorMaxLimit
                    onValueModified: cfg_page.cfg_indicatorMaxLimit = value
                }
            }

            Item { height: Kirigami.Units.largeSpacing; visible: indicatorsEnabled.checked }

            Label {
                visible: indicatorsEnabled.checked
                text: Wrappers.i18n("Colors:")
            }

            CheckBox {
                visible: indicatorsEnabled.checked
                id: indicatorAccentColor
                text: Wrappers.i18n("Use plasma accent color")
                checked: cfg_page.cfg_indicatorAccentColor
                onToggled: cfg_page.cfg_indicatorAccentColor = checked
            }

            CheckBox {
                visible: indicatorsEnabled.checked && !indicatorAccentColor.checked
                id: indicatorDominantColor
                text: Wrappers.i18n("Use dominant icon color")
                checked: cfg_page.cfg_indicatorDominantColor
                onToggled: cfg_page.cfg_indicatorDominantColor = checked
            }

            RowLayout {
                visible: indicatorsEnabled.checked && !indicatorAccentColor.checked && !indicatorDominantColor.checked
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Custom color:")
                }
                KQuickAddons.ColorButton {
                    id: indicatorCustomColor
                    showAlphaChannel: true
                    color: cfg_page.cfg_indicatorCustomColor
                    onColorChanged: {
                        if (!Qt.colorEqual(color, cfg_page.cfg_indicatorCustomColor)) {
                            cfg_page.cfg_indicatorCustomColor = color
                        }
                    }
                }
            }

            Item { height: Kirigami.Units.largeSpacing; visible: indicatorsEnabled.checked }

            Label {
                visible: indicatorsEnabled.checked
                text: Wrappers.i18n("Behavior:")
            }

            CheckBox {
                visible: indicatorsEnabled.checked
                id: indicatorDesaturate
                text: Wrappers.i18n("Desaturate when minimized")
                checked: cfg_page.cfg_indicatorDesaturate
                onToggled: cfg_page.cfg_indicatorDesaturate = checked
            }



            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Group Indicators:")
            }

            CheckBox {
                id: groupIconEnabled
                text: Wrappers.i18n("Standard group overlay")
                checked: cfg_page.cfg_groupIconEnabled
                onToggled: cfg_page.cfg_groupIconEnabled = checked
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Feedback:")
            }

            CheckBox {
                id: cfg_showBadges
                text: Wrappers.i18n("Show badges")
                checked: cfg_page.cfg_showBadges
                onToggled: cfg_page.cfg_showBadges = checked
            }

            CheckBox {
                id: cfg_indicateAudioStreams
                text: Wrappers.i18n("Mark applications playing audio")
                checked: cfg_page.cfg_indicateAudioStreams
                onToggled: cfg_page.cfg_indicateAudioStreams = checked
                visible: cfg_page.plasmaPaAvailable
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Progress:")
            }

            ComboBox {
                id: indicatorProgressStyle
                model: [
                    Wrappers.i18n("Disabled"),
                    Wrappers.i18n("Fill (Left-Right)"),
                    Wrappers.i18n("Fill (Bottom-Top)"),
                    Wrappers.i18n("Strip (Top)"),
                    Wrappers.i18n("Strip (Bottom)"),
                    Wrappers.i18n("Strip (Left)"),
                    Wrappers.i18n("Strip (Right)")
                ]
                currentIndex: cfg_page.cfg_indicatorProgressStyle
                onActivated: cfg_page.cfg_indicatorProgressStyle = currentIndex
            }

            RowLayout {
                visible: indicatorProgressStyle.currentIndex > 0
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Progress color:")
                }
                KQuickAddons.ColorButton {
                    id: indicatorProgressColor
                    showAlphaChannel: true
                    color: cfg_page.cfg_indicatorProgressColor
                    onColorChanged: {
                        if (!Qt.colorEqual(color, cfg_page.cfg_indicatorProgressColor)) {
                            cfg_page.cfg_indicatorProgressColor = color
                        }
                    }
                }
            }

            RowLayout {
                visible: indicatorProgressStyle.currentIndex > 0
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Thickness:")
                    visible: indicatorProgressStyle.currentIndex >= 3 // Only show label for strips
                }
                Slider {
                    id: indicatorProgressThickness
                    visible: indicatorProgressStyle.currentIndex >= 3 // Thickness only for strips
                    from: 1
                    to: 10
                    stepSize: 1
                    value: cfg_page.cfg_indicatorProgressThickness
                    onMoved: cfg_page.cfg_indicatorProgressThickness = value
                }

                Item {
                    width: Kirigami.Units.largeSpacing
                    visible: indicatorProgressStyle.currentIndex > 0
                }

                Label {
                    text: Wrappers.i18n("Opacity:")
                }
                Slider {
                    id: indicatorProgressOpacity
                    from: 10
                    to: 100
                    stepSize: 5
                    value: cfg_page.cfg_indicatorProgressOpacity
                    onMoved: cfg_page.cfg_indicatorProgressOpacity = value
                }
                }
            } // FormLayout
        } // ScrollView

        // Top edge shadow (visor style)
        Canvas {
            z: 99
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: scrollView.ScrollBar.vertical.width > 0 ? scrollView.ScrollBar.vertical.width : 0
            
            property real activeFactor: containerWrapper.scrollDir === -1 ? 1.0 : 0.0
            Behavior on activeFactor { NumberAnimation { duration: Kirigami.Units.shortDuration } }
            
            height: Kirigami.Units.largeSpacing + (Kirigami.Units.largeSpacing * 0.5 * activeFactor)
            opacity: scrollView.ScrollBar.vertical.position > 0.01 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
            
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                let gradient = ctx.createLinearGradient(0, 0, 0, height);
                let alpha = 0.20 + (0.15 * activeFactor);
                gradient.addColorStop(0, "rgba(0, 0, 0, " + alpha.toFixed(3) + ")");
                gradient.addColorStop(1, "rgba(0, 0, 0, 0)");
                
                ctx.fillStyle = gradient;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.quadraticCurveTo(width / 2, height * 2, width, 0);
                ctx.closePath();
                ctx.fill();
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onActiveFactorChanged: requestPaint()
        }

        // Bottom edge shadow (visor style)
        Canvas {
            z: 99
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: scrollView.ScrollBar.vertical.width > 0 ? scrollView.ScrollBar.vertical.width : 0
            
            property real activeFactor: containerWrapper.scrollDir === 1 ? 1.0 : 0.0
            Behavior on activeFactor { NumberAnimation { duration: Kirigami.Units.shortDuration } }
            
            height: Kirigami.Units.largeSpacing + (Kirigami.Units.largeSpacing * 0.5 * activeFactor)
            opacity: scrollView.ScrollBar.vertical.position < (1.0 - scrollView.ScrollBar.vertical.size) - 0.01 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
            
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                let gradient = ctx.createLinearGradient(0, height, 0, 0);
                let alpha = 0.20 + (0.15 * activeFactor);
                gradient.addColorStop(0, "rgba(0, 0, 0, " + alpha.toFixed(3) + ")");
                gradient.addColorStop(1, "rgba(0, 0, 0, 0)");
                
                ctx.fillStyle = gradient;
                ctx.beginPath();
                ctx.moveTo(0, height);
                ctx.quadraticCurveTo(width / 2, -height, width, height);
                ctx.closePath();
                ctx.fill();
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onActiveFactorChanged: requestPaint()
        }
        } // Item
    } // ColumnLayout
} // ConfigPage
