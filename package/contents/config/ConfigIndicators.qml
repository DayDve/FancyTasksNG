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
    readonly property bool plasmaPaAvailable: Qt.createComponent("../ui/PulseAudio.qml").status === Component.Ready

    readonly property bool isLineStyle: cfg_page.cfg_indicatorStyle === 0

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        LivePreview {
            cfg_page: cfg_page
            Layout.fillWidth: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
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

                Item { width: Kirigami.Units.largeSpacing; visible: isLineStyle }

                Label {
                    visible: isLineStyle
                    text: Wrappers.i18n("Side padding:")
                }
                SpinBox {
                    id: indicatorShrink
                    visible: isLineStyle
                    from: 0
                    to: 999
                    value: cfg_page.cfg_indicatorShrink
                    onValueModified: cfg_page.cfg_indicatorShrink = value
                }
                Label {
                    visible: isLineStyle
                    text: "px"
                }
            }

            CheckBox {
                visible: indicatorsEnabled.checked && isLineStyle
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
                    Wrappers.i18n("Fill button"),
                    Wrappers.i18n("Top edge"),
                    Wrappers.i18n("Bottom edge")
                ]
                currentIndex: cfg_page.cfg_indicatorProgressStyle
                onActivated: cfg_page.cfg_indicatorProgressStyle = currentIndex
            }

            RowLayout {
                visible: indicatorProgressStyle.currentIndex > 1
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
                visible: indicatorProgressStyle.currentIndex > 1
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Thickness:")
                }
                Slider {
                    id: indicatorProgressThickness
                    from: 1
                    to: 10
                    stepSize: 1
                    value: cfg_page.cfg_indicatorProgressThickness
                    onMoved: cfg_page.cfg_indicatorProgressThickness = value
                }

                Item {
                    width: Kirigami.Units.largeSpacing
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
        }
    }
}
}
