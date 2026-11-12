/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kquickcontrols as KQuickAddons

import "../ui/code/singletones"

// App signals: what an app reports on its task button (the audio mark, the
// notification count, progress) and a window asking for attention.
ConfigPage {
    id: signalsPage
    fullTitle: Wrappers.i18n("App Signals")

    readonly property string offReason: Wrappers.i18n("App signals are turned off.")

    function turnOnFirst(option: string): string {
        return Wrappers.i18n("Turn on \"%1\" first.", option);
    }

    ConfigTabbedPage {
        cfg_page: signalsPage

        header: Kirigami.FormLayout {
            RowLayout {
                CheckBox {
                    text: Wrappers.i18n("Show app signals")
                    checked: signalsPage.cfg_showAppSignals
                    onToggled: signalsPage.cfg_showAppSignals = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("The audio mark, the notification count and progress on task buttons. Turning this off keeps their own settings.")
                }
            }
            RowLayout {
                CheckBox {
                    id: indicateAudioStreams
                    enabled: signalsPage.cfg_showAppSignals
                    text: Wrappers.i18n("Mark applications playing audio")
                    checked: signalsPage.cfg_indicateAudioStreams
                    onToggled: signalsPage.cfg_indicateAudioStreams = checked
                }
                ConfigHint {
                    target: indicateAudioStreams
                    reason: signalsPage.offReason
                }
            }
            RowLayout {
                spacing: signalsPage.smallSpacing
                RowLayout {
                    id: dotMode
                    enabled: signalsPage.cfg_showAppSignals && (signalsPage.cfg_showBadges || signalsPage.cfg_indicateAudioStreams)
                    spacing: signalsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Show signal badges as dots:")
                    }
                    ComboBox {
                        id: badgeDotMode
                        model: [
                            Wrappers.i18nc("Show badges as dots", "Never"),
                            Wrappers.i18nc("Show badges as dots", "Always"),
                            Wrappers.i18nc("Show badges as dots", "When smaller than")
                        ]
                        currentIndex: signalsPage.cfg_badgeDotMode
                        onActivated: (index) => signalsPage.cfg_badgeDotMode = index
                    }
                    SpinBox {
                        enabled: badgeDotMode.currentIndex === 2
                        from: 4
                        to: 64
                        value: signalsPage.cfg_badgeDotThreshold
                        onValueModified: signalsPage.cfg_badgeDotThreshold = value
                    }
                    Label {
                        enabled: badgeDotMode.currentIndex === 2
                        text: "px"
                    }
                }
                ConfigHint {
                    target: dotMode
                    info: Wrappers.i18n("The audio and notification count badges on task icons. A dot grows into the full badge while its task is under the cursor; \"When smaller than\" keeps the full badges on big icons.")
                    reason: !signalsPage.cfg_showAppSignals ? signalsPage.offReason
                        : Wrappers.i18n("Turn on the audio mark or the notification count first.")
                }
            }
        }

        ConfigTab {
            id: counterTab
            title: Wrappers.i18n("Counter")
            iconName: "notifications"
            available: signalsPage.cfg_showAppSignals
            unavailableReason: signalsPage.offReason

            CheckBox {
                id: showBadges
                text: Wrappers.i18n("Show badges")
                checked: signalsPage.cfg_showBadges
                onToggled: signalsPage.cfg_showBadges = checked
            }

            readonly property string badgesReason: signalsPage.turnOnFirst(showBadges.text)

            RowLayout {
                Item { implicitWidth: signalsPage.gridUnit }
                CheckBox {
                    id: badgeHighlightNew
                    enabled: showBadges.checked
                    text: Wrappers.i18n("Highlight new notifications")
                    checked: signalsPage.cfg_badgeHighlightNew
                    onToggled: signalsPage.cfg_badgeHighlightNew = checked
                }
                ConfigHint {
                    target: badgeHighlightNew
                    reason: counterTab.badgesReason
                }
            }
            RowLayout {
                Item { implicitWidth: signalsPage.gridUnit }
                CheckBox {
                    id: showBadgesOnLaunchers
                    enabled: showBadges.checked
                    text: Wrappers.i18n("Show badges on pinned application icons")
                    checked: signalsPage.cfg_showBadgesOnLaunchers
                    onToggled: signalsPage.cfg_showBadgesOnLaunchers = checked
                }
                ConfigHint {
                    target: showBadgesOnLaunchers
                    info: Wrappers.i18n("Show counters even when the application has no windows in the current view (e.g., minimized to tray or on another screen/desktop/activity).")
                    reason: counterTab.badgesReason
                }
            }
            RowLayout {
                spacing: signalsPage.smallSpacing
                Item { implicitWidth: signalsPage.gridUnit }
                RowLayout {
                    id: badgeColor
                    enabled: showBadges.checked
                    spacing: signalsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Count background color:")
                    }
                    ComboBox {
                        id: badgeColorMode
                        Layout.fillWidth: true
                        model: [
                            Wrappers.i18n("Adaptive (theme color)"),
                            Wrappers.i18n("Fixed red (Classic)"),
                            Wrappers.i18n("System accent color"),
                            Wrappers.i18n("Custom color")
                        ]
                        currentIndex: signalsPage.cfg_badgeColorMode
                        onActivated: (index) => signalsPage.cfg_badgeColorMode = index
                    }
                    KQuickAddons.ColorButton {
                        enabled: badgeColorMode.currentIndex === 3
                        showAlphaChannel: true
                        Layout.maximumHeight: badgeColorMode.height
                        color: signalsPage.cfg_badgeCustomColor
                        onColorChanged: {
                            if (!Qt.colorEqual(color, signalsPage.cfg_badgeCustomColor))
                                signalsPage.cfg_badgeCustomColor = color;
                        }
                    }
                }
                ConfigHint {
                    target: badgeColor
                    reason: counterTab.badgesReason
                }
            }
        }

        ConfigTab {
            id: progressTab
            title: Wrappers.i18n("Progress")
            iconName: "chronometer"
            available: signalsPage.cfg_showAppSignals
            unavailableReason: signalsPage.offReason

            Label {
                text: Wrappers.i18n("Style:")
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
                currentIndex: signalsPage.cfg_indicatorProgressStyle
                onActivated: (index) => signalsPage.cfg_indicatorProgressStyle = index
            }

            readonly property bool progressOn: indicatorProgressStyle.currentIndex > 0
            readonly property string progressReason: Wrappers.i18n("Choose a progress style first.")

            RowLayout {
                spacing: signalsPage.smallSpacing
                RowLayout {
                    id: progressColor
                    enabled: progressTab.progressOn
                    spacing: signalsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Progress color:")
                    }
                    KQuickAddons.ColorButton {
                        showAlphaChannel: true
                        color: signalsPage.cfg_indicatorProgressColor
                        onColorChanged: {
                            if (!Qt.colorEqual(color, signalsPage.cfg_indicatorProgressColor))
                                signalsPage.cfg_indicatorProgressColor = color;
                        }
                    }
                }
                ConfigHint {
                    target: progressColor
                    reason: progressTab.progressReason
                }
            }
            RowLayout {
                spacing: signalsPage.smallSpacing
                RowLayout {
                    id: progressThickness
                    // Only strips have a thickness.
                    enabled: indicatorProgressStyle.currentIndex >= 3
                    spacing: signalsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Thickness:")
                    }
                    Slider {
                        from: 1
                        to: 10
                        stepSize: 1
                        value: signalsPage.cfg_indicatorProgressThickness
                        onMoved: signalsPage.cfg_indicatorProgressThickness = value
                    }
                }
                ConfigHint {
                    target: progressThickness
                    reason: progressTab.progressOn ? Wrappers.i18n("Only for the strip styles.") : progressTab.progressReason
                }
            }
            RowLayout {
                spacing: signalsPage.smallSpacing
                RowLayout {
                    id: progressOpacity
                    enabled: progressTab.progressOn
                    spacing: signalsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Opacity:")
                    }
                    Slider {
                        from: 10
                        to: 100
                        stepSize: 5
                        value: signalsPage.cfg_indicatorProgressOpacity
                        onMoved: signalsPage.cfg_indicatorProgressOpacity = value
                    }
                }
                ConfigHint {
                    target: progressOpacity
                    reason: progressTab.progressReason
                }
            }
        }

        // Not affected by "Show app signals": it's the window's state, not
        // something the app draws on its button.
        ConfigTab {
            title: Wrappers.i18n("Attention request")
            iconName: "flag"

            RowLayout {
                CheckBox {
                    id: unhideOnAttention
                    enabled: signalsPage.plasmoidLocation !== PlasmaCore.Types.Floating
                    text: Wrappers.i18n("Unhide panel when a window wants attention")
                    checked: signalsPage.cfg_unhideOnAttention
                    onToggled: signalsPage.cfg_unhideOnAttention = checked
                }
                ConfigHint {
                    target: unhideOnAttention
                    reason: Wrappers.i18n("Only when the widget is on a panel.")
                }
            }
            RowLayout {
                CheckBox {
                    id: animateAttentionStatus
                    enabled: signalsPage.cfg_iconOnly === 1
                    text: Wrappers.i18n("Animate task icon when a window wants attention")
                    checked: signalsPage.cfg_animateAttentionStatus
                    onToggled: signalsPage.cfg_animateAttentionStatus = checked
                }
                ConfigHint {
                    target: animateAttentionStatus
                    reason: Wrappers.i18n("Only in the icons-only mode.")
                }
            }
            RowLayout {
                spacing: signalsPage.smallSpacing
                CheckBox {
                    id: attentionCustomColorEnabled
                    text: Wrappers.i18n("Colorize the task button when a window wants attention")
                    checked: signalsPage.cfg_attentionCustomColorEnabled
                    onToggled: signalsPage.cfg_attentionCustomColorEnabled = checked
                }
                KQuickAddons.ColorButton {
                    enabled: attentionCustomColorEnabled.checked
                    showAlphaChannel: true
                    Layout.maximumHeight: attentionCustomColorEnabled.height
                    color: signalsPage.cfg_attentionCustomColor
                    onColorChanged: {
                        if (!Qt.colorEqual(color, signalsPage.cfg_attentionCustomColor))
                            signalsPage.cfg_attentionCustomColor = color;
                    }
                }
            }
        }
    }
}
