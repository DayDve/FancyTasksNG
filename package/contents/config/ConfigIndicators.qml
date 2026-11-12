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
    id: indicatorsPage

    // Silence KCM errors for legacy/removed properties
    readonly property bool plasmaPaAvailable: true

    ConfigFormPage {
        cfg_page: indicatorsPage

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
            Item { implicitWidth: indicatorsPage.gridUnit }
            ColumnLayout {
                CheckBox {
                    id: cfg_badgeHighlightNew
                    text: Wrappers.i18n("Highlight new notifications")
                    checked: indicatorsPage.cfg_badgeHighlightNew
                    onToggled: indicatorsPage.cfg_badgeHighlightNew = checked
                }
                RowLayout {
                    spacing: indicatorsPage.smallSpacing
                    CheckBox {
                        id: cfg_showBadgesOnLaunchers
                        text: Wrappers.i18n("Show badges on pinned application icons")
                        checked: indicatorsPage.cfg_showBadgesOnLaunchers
                        onToggled: indicatorsPage.cfg_showBadgesOnLaunchers = checked
                    }
                    Kirigami.Icon {
                        source: "help-about"
                        implicitWidth: indicatorsPage.gridUnit
                        implicitHeight: indicatorsPage.gridUnit
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
                RowLayout {
                    spacing: indicatorsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Badge background color:")
                    }
                    ComboBox {
                        id: cfg_badgeColorMode
                        Layout.fillWidth: true
                        model: [
                            Wrappers.i18n("Adaptive (theme color)"),
                            Wrappers.i18n("Fixed red (Classic)"),
                            Wrappers.i18n("System accent color"),
                            Wrappers.i18n("Custom color")
                        ]
                        currentIndex: indicatorsPage.cfg_badgeColorMode
                        onActivated: (index) => indicatorsPage.cfg_badgeColorMode = index
                    }
                }
                RowLayout {
                    visible: cfg_badgeColorMode.currentIndex === 3
                    spacing: indicatorsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Custom badge color:")
                    }
                    KQuickAddons.ColorButton {
                        id: badgeCustomColor
                        showAlphaChannel: true
                        color: indicatorsPage.cfg_badgeCustomColor
                        onColorChanged: {
                            if (!Qt.colorEqual(color, indicatorsPage.cfg_badgeCustomColor)) {
                                indicatorsPage.cfg_badgeCustomColor = color
                            }
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

        RowLayout {
            visible: cfg_showBadges.checked || cfg_indicateAudioStreams.checked
            spacing: indicatorsPage.smallSpacing
            Label {
                text: Wrappers.i18n("Show badges as dots:")
            }
            ComboBox {
                id: badgeDotMode
                model: [
                    Wrappers.i18nc("Show badges as dots", "Never"),
                    Wrappers.i18nc("Show badges as dots", "Always"),
                    Wrappers.i18nc("Show badges as dots", "When smaller than")
                ]
                currentIndex: indicatorsPage.cfg_badgeDotMode
                onActivated: index => indicatorsPage.cfg_badgeDotMode = index
            }
            SpinBox {
                visible: badgeDotMode.currentIndex === 2
                from: 4
                to: 64
                value: indicatorsPage.cfg_badgeDotThreshold
                onValueModified: indicatorsPage.cfg_badgeDotThreshold = value
            }
            Label {
                visible: badgeDotMode.currentIndex === 2
                text: "px"
            }
        }

        Item { height: indicatorsPage.largeSpacing }
    
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
            spacing: indicatorsPage.smallSpacing
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
            spacing: indicatorsPage.smallSpacing
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
                implicitWidth: indicatorsPage.largeSpacing
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
    }
}
