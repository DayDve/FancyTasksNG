/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import org.kde.plasma.workspace.dbus as DBus

Kirigami.ScrollablePage {
    property alias cfg_groupingStrategy: groupingStrategy.currentIndex
    property alias cfg_groupedTaskVisualization: groupedTaskVisualization.currentIndex
    property alias cfg_groupPopups: groupPopups.checked
    property alias cfg_onlyGroupWhenFull: onlyGroupWhenFull.checked
    property alias cfg_sortingStrategy: sortingStrategy.currentIndex
    property alias cfg_separateLaunchers: separateLaunchers.checked
    property alias cfg_hideLauncherOnStart: hideLauncherOnStart.checked
    property alias cfg_middleClickAction: middleClickAction.currentIndex
    property alias cfg_wheelEnabled: wheelEnabled.checked
    property alias cfg_wheelSkipMinimized: wheelSkipMinimized.checked
    property alias cfg_showOnlyCurrentScreen: showOnlyCurrentScreen.checked
    property alias cfg_showOnlyCurrentDesktop: showOnlyCurrentDesktop.checked
    property alias cfg_showOnlyCurrentActivity: showOnlyCurrentActivity.checked
    property alias cfg_showOnlyMinimized: showOnlyMinimized.checked
    property alias cfg_minimizeActiveTaskOnClick: minimizeActive.checked
    property alias cfg_unhideOnAttention: unhideOnAttention.checked
    property alias cfg_reverseMode: reverseMode.checked
    property alias cfg_iconOnly: iconOnly.currentIndex

    // --- Properties to silence KCM errors ---
    property var cfg_groupingStrategyDefault
    property var cfg_groupedTaskVisualizationDefault
    property var cfg_groupPopupsDefault
    property var cfg_onlyGroupWhenFullDefault
    property var cfg_sortingStrategyDefault
    property var cfg_separateLaunchersDefault
    property var cfg_hideLauncherOnStartDefault
    property var cfg_middleClickActionDefault
    property var cfg_wheelEnabledDefault
    property var cfg_wheelSkipMinimizedDefault
    property var cfg_showOnlyCurrentScreenDefault
    property var cfg_showOnlyCurrentDesktopDefault
    property var cfg_showOnlyCurrentActivityDefault
    property var cfg_showOnlyMinimizedDefault
    property var cfg_minimizeActiveTaskOnClickDefault
    property var cfg_unhideOnAttentionDefault
    property var cfg_reverseModeDefault
    property var cfg_iconOnlyDefault

    // Missing properties from main.xml not used in this tab
    property var cfg_groupingAppIdBlacklist
    property var cfg_groupingAppIdBlacklistDefault
    property var cfg_groupingLauncherUrlBlacklist
    property var cfg_groupingLauncherUrlBlacklistDefault
    property var cfg_maxStripes
    property var cfg_maxStripesDefault
    property var cfg_maxButtonLength
    property var cfg_maxButtonLengthDefault
    property var cfg_forceStripes
    property var cfg_forceStripesDefault
    property var cfg_showToolTips
    property var cfg_showToolTipsDefault
    property var cfg_taskMaxWidth
    property var cfg_taskMaxWidthDefault
    property var cfg_highlightWindows
    property var cfg_highlightWindowsDefault
    property var cfg_launchers
    property var cfg_launchersDefault
    property var cfg_indicateAudioStreams
    property var cfg_indicateAudioStreamsDefault
    property var cfg_iconScale
    property var cfg_iconScaleDefault
    property var cfg_iconSizePx
    property var cfg_iconSizePxDefault
    property var cfg_iconSizeOverride
    property var cfg_iconSizeOverrideDefault
    property var cfg_fill
    property var cfg_fillDefault
    property var cfg_taskHoverEffect
    property var cfg_taskHoverEffectDefault
    property var cfg_maxTextLines
    property var cfg_maxTextLinesDefault
    property var cfg_iconSpacing
    property var cfg_iconSpacingDefault
    property var cfg_indicatorsEnabled
    property var cfg_indicatorsEnabledDefault
    property var cfg_indicatorProgress
    property var cfg_indicatorProgressDefault
    property var cfg_indicatorProgressColor
    property var cfg_indicatorProgressColorDefault
    property var cfg_disableInactiveIndicators
    property var cfg_disableInactiveIndicatorsDefault
    property var cfg_indicatorsAnimated
    property var cfg_indicatorsAnimatedDefault
    property var cfg_groupIconEnabled
    property var cfg_groupIconEnabledDefault
    property var cfg_indicatorLocation
    property var cfg_indicatorLocationDefault
    property var cfg_indicatorStyle
    property var cfg_indicatorStyleDefault
    property var cfg_indicatorMinLimit
    property var cfg_indicatorMinLimitDefault
    property var cfg_indicatorMaxLimit
    property var cfg_indicatorMaxLimitDefault
    property var cfg_indicatorDesaturate
    property var cfg_indicatorDesaturateDefault
    property var cfg_indicatorGrow
    property var cfg_indicatorGrowDefault
    property var cfg_indicatorGrowFactor
    property var cfg_indicatorGrowFactorDefault
    property var cfg_indicatorEdgeOffset
    property var cfg_indicatorEdgeOffsetDefault
    property var cfg_indicatorSize
    property var cfg_indicatorSizeDefault
    property var cfg_indicatorLength
    property var cfg_indicatorLengthDefault
    property var cfg_indicatorRadius
    property var cfg_indicatorRadiusDefault
    property var cfg_indicatorShrink
    property var cfg_indicatorShrinkDefault
    property var cfg_indicatorDominantColor
    property var cfg_indicatorDominantColorDefault
    property var cfg_indicatorAccentColor
    property var cfg_indicatorAccentColorDefault
    property var cfg_indicatorCustomColor
    property var cfg_indicatorCustomColorDefault
    property var cfg_useBorders
    property var cfg_useBordersDefault
    property var cfg_taskSpacingSize
    property var cfg_taskSpacingSizeDefault
    property var cfg_buttonColorize
    property var cfg_buttonColorizeDefault
    property var cfg_buttonColorizeInactive
    property var cfg_buttonColorizeInactiveDefault
    property var cfg_buttonColorizeDominant
    property var cfg_buttonColorizeDominantDefault
    property var cfg_buttonColorizeCustom
    property var cfg_buttonColorizeCustomDefault
    property var cfg_disableButtonSvg
    property var cfg_disableButtonSvgDefault
    property var cfg_disableButtonInactiveSvg
    property var cfg_disableButtonInactiveSvgDefault
    property var cfg_overridePlasmaButtonDirection
    property var cfg_overridePlasmaButtonDirectionDefault
    property var cfg_plasmaButtonDirection
    property var cfg_plasmaButtonDirectionDefault
    property var cfg_indicatorReverse
    property var cfg_indicatorReverseDefault
    property var cfg_indicatorOverride
    property var cfg_indicatorOverrideDefault
    property var cfg_iconZoomFactor
    property var cfg_iconZoomFactorDefault
    property var cfg_iconZoomDuration
    property var cfg_iconZoomDurationDefault
    // -----------------------------------------------------------

    DBus.DBusServiceWatcher {
        id: effectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    Kirigami.FormLayout {
        ComboBox {
            id: iconOnly
            Kirigami.FormData.label: i18n("Display:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [i18n("Show task names"), i18n("Show icons only")]
        }

        ComboBox {
            id: groupingStrategy
            Kirigami.FormData.label: i18nc("@label:listbox how to group tasks", "Group:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                i18nc("@item:inlistbox how to group tasks", "Do not group"),
                i18nc("@item:inlistbox how to group tasks", "By program name")
            ]
        }

        ComboBox {
            id: groupedTaskVisualization
            Kirigami.FormData.label: i18nc("@label:listbox completes sentence like: … cycles through tasks", "Clicking grouped task:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14

            enabled: groupingStrategy.currentIndex !== 0

            model: [
                i18nc("@item:inlistbox Completes the sentence 'Clicking grouped task cycles through tasks' ", "Cycles through tasks"),
                i18nc("@item:inlistbox Completes the sentence 'Clicking grouped task shows small window previews' ", "Shows small window previews"),
                i18nc("@item:inlistbox Completes the sentence 'Clicking grouped task shows large window previews' ", "Shows large window previews"),
                i18nc("@item:inlistbox Completes the sentence 'Clicking grouped task shows textual list' ", "Shows textual list"),
            ]

            Accessible.name: currentText
            Accessible.onPressAction: currentIndex = currentIndex === count - 1 ? 0 : (currentIndex + 1)
        }
        // "You asked for Window View but Window View is not available" message
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: groupedTaskVisualization.currentIndex === 2 && !effectWatcher.registered
            type: Kirigami.MessageType.Warning
            text: i18nc("@info displayed as InlineMessage", "The compositor does not support displaying windows side by side, so a textual list will be displayed instead.")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: groupPopups
            visible: (!plasmoid.configuration.iconOnly)
            text: i18nc("@option:check grouped task", "Combine into single button")
            enabled: groupingStrategy.currentIndex > 0
        }

        CheckBox {
            id: onlyGroupWhenFull
            visible: (!plasmoid.configuration.iconOnly)
            text: i18nc("@option:check grouped task","Group only when the Task Manager is full")
            enabled: groupingStrategy.currentIndex > 0 && groupPopups.checked
            Accessible.onPressAction: toggle()
        }

        Item {
            Kirigami.FormData.isSection: true
            visible: (Plasmoid.pluginName !== "org.kde.plasma.icontasks")
        }

        ComboBox {
            id: sortingStrategy
            Kirigami.FormData.label: i18nc("@label:listbox sort tasks in grouped task", "Sort:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                i18nc("@item:inlistbox sort tasks in grouped task", "Do not sort"),
                i18nc("@item:inlistbox sort tasks in grouped task", "Manually"),
                i18nc("@item:inlistbox sort tasks in grouped task", "Alphabetically"),
                i18nc("@item:inlistbox sort tasks in grouped task", "By desktop"),
                i18nc("@item:inlistbox sort tasks in grouped task", "By activity")
            ]
        }

        CheckBox {
            id: separateLaunchers
            visible: (!plasmoid.configuration.iconOnly)
            text: i18nc("@option:check configure task sorting", "Keep launchers separate")
            enabled: sortingStrategy.currentIndex === 1
        }

        CheckBox {
            id: hideLauncherOnStart
            visible: (!plasmoid.configuration.iconOnly)
            text: i18nc("@option:check for icons-and-text task manager", "Hide launchers after application startup")
        }

        Item {
            Kirigami.FormData.isSection: true
            visible: (!plasmoid.configuration.iconOnly)
        }

        CheckBox {
            id: minimizeActive
            Kirigami.FormData.label: i18nc("@label for checkbox Part of a sentence: 'Clicking active task minimizes the task'", "Clicking active task:")
            text: i18nc("@option:check Part of a sentence: 'Clicking active task minimizes the task'", "Minimizes the task")
        }

        ComboBox {
            id: middleClickAction
            Kirigami.FormData.label: i18nc("@label:listbox completes sentence like: … does nothing", "Middle-clicking any task:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task does nothing'", "Does nothing"),
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task closes window or group'", "Closes window or group"),
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task opens a new window'", "Opens a new window"),
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task minimizes/restores window or group'", "Minimizes/Restores window or group"),
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task toggles grouping'", "Toggles grouping"),
                i18nc("@item:inlistbox Part of a sentence: 'Middle-clicking any task brings it to the current virtual desktop'", "Brings it to the current virtual desktop")
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: wheelEnabled
            Kirigami.FormData.label: i18nc("@label for checkbox Part of a sentence: 'Mouse wheel cycles through tasks'", "Mouse wheel:")
            text: i18nc("@option:check Part of a sentence: 'Mouse wheel cycles through tasks'", "Cycles through tasks")
        }

        RowLayout {
            // HACK: Workaround for Kirigami bug 434625
            // due to which a simple Layout.leftMargin on CheckBox doesn't work
            Item { implicitWidth: Kirigami.Units.gridUnit }
            CheckBox {
                id: wheelSkipMinimized
                text: i18nc("@option:check mouse wheel task cycling", "Skip minimized tasks")
                enabled: wheelEnabled.checked
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: showOnlyCurrentScreen
            Kirigami.FormData.label: i18nc("@label for checkbox group, completes sentence like: … from current screen", "Show only tasks:")
            text: i18nc("@option:check completes sentence: show only tasks", "From current screen")
        }

        CheckBox {
            id: showOnlyCurrentDesktop
            text: i18nc("@option:check completes sentence: show only tasks", "From current desktop")
        }

        CheckBox {
            id: showOnlyCurrentActivity
            text: i18nc("@option:check completes sentence: show only tasks", "From current activity")
        }

        CheckBox {
            id: showOnlyMinimized
            text: i18nc("@option:check completes sentence: show only tasks", "That are minimized")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: unhideOnAttention
            Kirigami.FormData.label: i18nc("@label for checkbox, completes sentence: … unhide if window wants attention", "When panel is hidden:")
            text: i18nc("@option:check completes sentence: When panel is hidden", "Unhide when a window wants attention")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ButtonGroup {
            id: reverseModeRadioButtonGroup
        }

        RadioButton {
            Kirigami.FormData.label: i18nc("@label for radiobutton group completes sentence like: … on the bottom", "New tasks appear:")
            checked: !reverseMode.checked
            text: {
                if (Plasmoid.formFactor === PlasmaCore.Types.Vertical) {
                    return i18nc("@option:check completes sentence: New tasks appear", "On the bottom")
                }
                // horizontal
                if (Qt.application.layoutDirection === Qt.LeftToRight) {
                    return i18nc("@option:check completes sentence: New tasks appear", "To the right");
                } else {
                    return i18nc("@option:check completes sentence: New tasks appear", "To the left")
                }
            }
            ButtonGroup.group: reverseModeRadioButtonGroup
        }

        RadioButton {
            id: reverseMode
            checked: Plasmoid.configuration.reverseMode === true
            text: {
                if (Plasmoid.formFactor === PlasmaCore.Types.Vertical) {
                    return i18nc("@option:check completes sentence: New tasks appear", "On the top")
                }
                // horizontal
                if (Qt.application.layoutDirection === Qt.LeftToRight) {
                    return i18nc("@option:check completes sentence: New tasks appear", "To the left");
                } else {
                    return i18nc("@option:check completes sentence: New tasks appear", "To the right");
                }
            }
            ButtonGroup.group: reverseModeRadioButtonGroup
        }
    }
}
