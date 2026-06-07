/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kquickcontrols as KQuickAddons

import "../ui/code/singletones"

ConfigPage {
    id: indicatorsPage

    // Silence KCM errors for legacy/removed properties
    readonly property bool plasmaPaAvailable: true

    readonly property bool isLineStyle: indicatorsPage.cfg_indicatorStyle === 0

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        LivePreview {
            cfg_page: indicatorsPage
            location: Plasmoid.location
            Layout.fillWidth: true
            visible: Plasmoid.location !== PlasmaCore.Types.Floating
        }

        ConfigScrollView {

                Kirigami.FormLayout {
                    width: parent.width - Kirigami.Units.gridUnit * 2

            Label {
                text: Wrappers.i18n("Active application indicators:")
            }

            CheckBox {
                id: indicatorsEnabled
                text: Wrappers.i18nc("State", "Enabled")
                checked: indicatorsPage.cfg_indicatorsEnabled
                onToggled: indicatorsPage.cfg_indicatorsEnabled = checked
            }

            CheckBox {
                visible: indicatorsEnabled.checked
                id: indicatorsAnimated
                text: Wrappers.i18n("Animate indicators")
                checked: indicatorsPage.cfg_indicatorsAnimated
                onToggled: indicatorsPage.cfg_indicatorsAnimated = checked
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
                    currentIndex: indicatorsPage.cfg_indicatorStyle
                    onActivated: (index) => indicatorsPage.cfg_indicatorStyle = index
                }
            }

            CheckBox {
                visible: indicatorsEnabled.checked
                id: indicatorOverride
                text: Wrappers.i18n("Override indicator location")
                checked: indicatorsPage.cfg_indicatorOverride
                onToggled: indicatorsPage.cfg_indicatorOverride = checked
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
                currentIndex: indicatorsPage.cfg_indicatorLocation
                onActivated: (index) => indicatorsPage.cfg_indicatorLocation = index
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
                    value: indicatorsPage.cfg_indicatorEdgeOffset
                    onValueModified: indicatorsPage.cfg_indicatorEdgeOffset = value
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
                    value: indicatorsPage.cfg_indicatorSize
                    onValueModified: indicatorsPage.cfg_indicatorSize = value
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
                    value: indicatorsPage.cfg_indicatorLength
                    onValueModified: indicatorsPage.cfg_indicatorLength = value
                }
                Label {
                    text: "px"
                }
            }

            RowLayout {
                visible: indicatorsEnabled.checked
                spacing: Kirigami.Units.smallSpacing
                CheckBox {
                    id: indicatorResize
                    text: Wrappers.i18n("Resize indicators on activation/hover")
                    checked: indicatorsPage.cfg_indicatorResize
                    onToggled: indicatorsPage.cfg_indicatorResize = checked
                }
            }

            RowLayout {
                visible: indicatorsEnabled.checked && indicatorResize.checked
                spacing: Kirigami.Units.smallSpacing
                Item { width: Kirigami.Units.gridUnit }

                Label {
                    text: Wrappers.i18n("Length:")
                }
                SpinBox {
                    id: indicatorActiveLength
                    from: 1
                    to: 999
                    value: indicatorsPage.cfg_indicatorActiveLength
                    onValueModified: indicatorsPage.cfg_indicatorActiveLength = value
                }
                Label {
                    text: "px"
                }

                Item { width: Kirigami.Units.largeSpacing }

                Label {
                    text: Wrappers.i18n("Thickness:")
                }
                SpinBox {
                    id: indicatorActiveSize
                    from: 1
                    to: 999
                    value: indicatorsPage.cfg_indicatorActiveSize
                    onValueModified: indicatorsPage.cfg_indicatorActiveSize = value
                }
                Label {
                    text: "px"
                }
            }

            RowLayout {
                visible: indicatorsEnabled.checked && indicatorResize.checked
                spacing: Kirigami.Units.smallSpacing
                Item { width: Kirigami.Units.gridUnit }
                Label {
                    text: Wrappers.i18n("Segment alignment:")
                }
                ComboBox {
                    id: indicatorAlignment
                    model: {
                        let isVertical = indicatorsPage.cfg_indicatorOverride ? 
                            (indicatorsPage.cfg_indicatorLocation === 1 || indicatorsPage.cfg_indicatorLocation === 2) :
                            (Plasmoid.location === PlasmaCore.Types.LeftEdge || Plasmoid.location === PlasmaCore.Types.RightEdge);

                        return isVertical ? [
                            Wrappers.i18n("Align Left"),
                            Wrappers.i18n("Align Center"),
                            Wrappers.i18n("Align Right")
                        ] : [
                            Wrappers.i18n("Align Top"),
                            Wrappers.i18n("Align Center"),
                            Wrappers.i18n("Align Bottom")
                        ];
                    }
                    currentIndex: indicatorsPage.cfg_indicatorAlignment
                    onActivated: (index) => indicatorsPage.cfg_indicatorAlignment = index
                }
            }

            RowLayout {
                visible: indicatorsEnabled.checked && indicatorResize.checked
                spacing: Kirigami.Units.smallSpacing
                Item { width: Kirigami.Units.gridUnit }
                CheckBox {
                    id: indicatorHoverSeparate
                    text: Wrappers.i18n("Separate settings for hovered indicators")
                    checked: indicatorsPage.cfg_indicatorHoverSeparate
                    onToggled: indicatorsPage.cfg_indicatorHoverSeparate = checked
                }
            }

            RowLayout {
                visible: indicatorsEnabled.checked && indicatorResize.checked && indicatorHoverSeparate.checked
                spacing: Kirigami.Units.smallSpacing
                Item { width: Kirigami.Units.gridUnit * 2 }

                Label {
                    text: Wrappers.i18n("Thickness:")
                }
                SpinBox {
                    id: indicatorHoverSize
                    from: 1
                    to: 999
                    value: indicatorsPage.cfg_indicatorHoverSize
                    onValueModified: indicatorsPage.cfg_indicatorHoverSize = value
                }
                Label {
                    text: "px"
                }

                Item { width: Kirigami.Units.largeSpacing }

                Label {
                    text: Wrappers.i18n("Length:")
                }
                SpinBox {
                    id: indicatorHoverLength
                    from: 1
                    to: 999
                    value: indicatorsPage.cfg_indicatorHoverLength
                    onValueModified: indicatorsPage.cfg_indicatorHoverLength = value
                }
                Label {
                    text: "px"
                }
            }

            RowLayout {
                visible: indicatorsEnabled.checked && indicatorResize.checked
                spacing: Kirigami.Units.smallSpacing
                Item { width: Kirigami.Units.gridUnit }
                CheckBox {
                    id: indicatorHighlightActive
                    text: Wrappers.i18n("Highlight active window in group")
                    checked: indicatorsPage.cfg_indicatorHighlightActive
                    onToggled: indicatorsPage.cfg_indicatorHighlightActive = checked
                }
            }

            RowLayout {
                visible: indicatorsEnabled.checked && indicatorResize.checked && indicatorHighlightActive.checked
                spacing: Kirigami.Units.smallSpacing
                Item { width: Kirigami.Units.gridUnit * 2 }
                CheckBox {
                    id: indicatorGroupSeparate
                    text: Wrappers.i18n("Separate settings for group indicators")
                    checked: indicatorsPage.cfg_indicatorGroupSeparate
                    onToggled: indicatorsPage.cfg_indicatorGroupSeparate = checked
                }
            }

            RowLayout {
                visible: indicatorsEnabled.checked && indicatorResize.checked && indicatorHighlightActive.checked && indicatorGroupSeparate.checked
                spacing: Kirigami.Units.smallSpacing
                Item { width: Kirigami.Units.gridUnit * 3 }

                Label {
                    text: Wrappers.i18n("Thickness:")
                }
                SpinBox {
                    id: indicatorGroupSize
                    from: 1
                    to: 999
                    value: indicatorsPage.cfg_indicatorGroupSize
                    onValueModified: indicatorsPage.cfg_indicatorGroupSize = value
                }
                Label {
                    text: "px"
                }

                Item { width: Kirigami.Units.largeSpacing }

                Label {
                    text: Wrappers.i18n("Length:")
                }
                SpinBox {
                    id: indicatorGroupLength
                    from: 1
                    to: 999
                    value: indicatorsPage.cfg_indicatorGroupLength
                    onValueModified: indicatorsPage.cfg_indicatorGroupLength = value
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
                    value: indicatorsPage.cfg_indicatorRadius
                    onValueModified: indicatorsPage.cfg_indicatorRadius = value
                }
                Label {
                    text: "%"
                }

                Item { width: Kirigami.Units.largeSpacing; visible: indicatorsPage.isLineStyle }

                Label {
                    visible: indicatorsPage.isLineStyle
                    text: Wrappers.i18n("Side padding:")
                }
                SpinBox {
                    id: indicatorShrink
                    visible: indicatorsPage.isLineStyle
                    from: 0
                    to: 999
                    value: indicatorsPage.cfg_indicatorShrink
                    onValueModified: indicatorsPage.cfg_indicatorShrink = value
                }
                Label {
                    visible: indicatorsPage.isLineStyle
                    text: "px"
                }
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
                    value: indicatorsPage.cfg_indicatorMaxLimit
                    onValueModified: indicatorsPage.cfg_indicatorMaxLimit = value
                }
            }

            CheckBox {
                visible: indicatorsEnabled.checked
                id: indicatorShowPlus
                text: Wrappers.i18n("Show '+' on overflow")
                checked: indicatorsPage.cfg_indicatorShowPlus
                onToggled: indicatorsPage.cfg_indicatorShowPlus = checked
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
                checked: indicatorsPage.cfg_indicatorAccentColor
                onToggled: indicatorsPage.cfg_indicatorAccentColor = checked
            }

            CheckBox {
                visible: indicatorsEnabled.checked && !indicatorAccentColor.checked
                id: indicatorDominantColor
                text: Wrappers.i18n("Use dominant icon color")
                checked: indicatorsPage.cfg_indicatorDominantColor
                onToggled: indicatorsPage.cfg_indicatorDominantColor = checked
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
                    color: indicatorsPage.cfg_indicatorCustomColor
                    onColorChanged: {
                        if (!Qt.colorEqual(color, indicatorsPage.cfg_indicatorCustomColor)) {
                            indicatorsPage.cfg_indicatorCustomColor = color
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
                checked: indicatorsPage.cfg_indicatorDesaturate
                onToggled: indicatorsPage.cfg_indicatorDesaturate = checked
            }



            Label {
                text: Wrappers.i18n("Feedback:")
            }

            CheckBox {
                id: cfg_showBadges
                text: Wrappers.i18n("Show badges")
                checked: indicatorsPage.cfg_showBadges
                onToggled: indicatorsPage.cfg_showBadges = checked
            }

            RowLayout {
                visible: cfg_showBadges.checked
                Item { implicitWidth: Kirigami.Units.gridUnit }
                ColumnLayout {
                    CheckBox {
                        id: cfg_badgeHighlightNew
                        text: Wrappers.i18n("Highlight new notifications")
                        checked: indicatorsPage.cfg_badgeHighlightNew
                        onToggled: indicatorsPage.cfg_badgeHighlightNew = checked
                    }
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        CheckBox {
                            id: cfg_showBadgesOnLaunchers
                            text: Wrappers.i18n("Show badges on pinned application icons")
                            checked: indicatorsPage.cfg_showBadgesOnLaunchers
                            onToggled: indicatorsPage.cfg_showBadgesOnLaunchers = checked
                        }
                        Kirigami.Icon {
                            source: "help-about"
                            implicitWidth: Kirigami.Units.gridUnit
                            implicitHeight: Kirigami.Units.gridUnit
                            opacity: 0.6
                            ToolTip.text: Wrappers.i18n("Show counters even when the application has no windows in the current view (e.g., minimized to tray or on another screen/desktop/activity).")
                            ToolTip.visible: infoMouseArea.containsMouse
                            MouseArea {
                                id: infoMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }
            }

            CheckBox {
                id: cfg_indicateAudioStreams
                text: Wrappers.i18n("Mark applications playing audio")
                checked: indicatorsPage.cfg_indicateAudioStreams
                onToggled: indicatorsPage.cfg_indicateAudioStreams = checked
                visible: indicatorsPage.plasmaPaAvailable
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Progress:")
            }

            ComboBox {
                id: indicatorProgressStyle
                model: [
                    Wrappers.i18nc("State", "Disabled"),
                    Wrappers.i18n("Fill (Left-Right)"),
                    Wrappers.i18n("Fill (Bottom-Top)"),
                    Wrappers.i18n("Strip (Top)"),
                    Wrappers.i18n("Strip (Bottom)"),
                    Wrappers.i18n("Strip (Left)"),
                    Wrappers.i18n("Strip (Right)")
                ]
                currentIndex: indicatorsPage.cfg_indicatorProgressStyle
                onActivated: indicatorsPage.cfg_indicatorProgressStyle = currentIndex
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
                    color: indicatorsPage.cfg_indicatorProgressColor
                    onColorChanged: {
                        if (!Qt.colorEqual(color, indicatorsPage.cfg_indicatorProgressColor)) {
                            indicatorsPage.cfg_indicatorProgressColor = color
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
                    value: indicatorsPage.cfg_indicatorProgressThickness
                    onMoved: indicatorsPage.cfg_indicatorProgressThickness = value
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
                    value: indicatorsPage.cfg_indicatorProgressOpacity
                    onMoved: indicatorsPage.cfg_indicatorProgressOpacity = value
                }
                }
            } // FormLayout
        } // ConfigScrollView
    } // ColumnLayout
} // ConfigPage
