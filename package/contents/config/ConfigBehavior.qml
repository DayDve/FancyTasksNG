/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import org.kde.plasma.workspace.dbus as DBus

import "../ui/code/singletones"

ConfigPage {
    id: cfg_page




    resources: [
        DBus.DBusServiceWatcher {
            id: effectWatcher
            busType: DBus.BusType.Session
            watchedService: "org.kde.KWin.Effect.WindowView1"
        }
    ]

    Kirigami.FormLayout {
        ComboBox {
            id: cfg_iconOnly
            Kirigami.FormData.label: Wrappers.i18n ("Display:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [Wrappers.i18n("Show task names"), Wrappers.i18n("Show icons only")]
            currentIndex: cfg_page.cfg_iconOnly
            onActivated: (index) => cfg_page.cfg_iconOnly = index
        }

        ComboBox {
            id: cfg_groupingStrategy
            Kirigami.FormData.label: Wrappers.i18n("Group:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                Wrappers.i18n("Do not group"),
                Wrappers.i18n("By program name")
            ]
            currentIndex: cfg_page.cfg_groupingStrategy
            onActivated: (index) => cfg_page.cfg_groupingStrategy = index
        }

        ComboBox {
            id: cfg_groupedTaskVisualization
            Kirigami.FormData.label: Wrappers.i18n("Clicking grouped task:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            
            enabled: cfg_groupingStrategy.currentIndex !== 0

            model: [
                Wrappers.i18n("Cycles through tasks"),
                Wrappers.i18n("Shows small window previews"),
                Wrappers.i18n("Shows large window previews"),
                Wrappers.i18n("Shows textual list"),
            ]
            currentIndex: cfg_page.cfg_groupedTaskVisualization
            onActivated: (index) => cfg_page.cfg_groupedTaskVisualization = index

            Accessible.name: currentText
            Accessible.onPressAction: currentIndex = currentIndex === count - 1 ? 0 : (currentIndex + 1)
        }
        // "You asked for Window View but Window View is not available" message
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: cfg_groupedTaskVisualization.currentIndex === 2 && !effectWatcher.registered
            type: Kirigami.MessageType.Warning
            text: Wrappers.i18n("The compositor does not support displaying windows side by side, so a textual list will be displayed instead.")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: cfg_groupPopups
            visible: (!cfg_page.cfg_iconOnly)
            text: Wrappers.i18n("Combine into single button")
            enabled: cfg_groupingStrategy.currentIndex > 0
            checked: cfg_page.cfg_groupPopups
            onToggled: cfg_page.cfg_groupPopups = checked
        }

        CheckBox {
            id: cfg_onlyGroupWhenFull
            visible: (!cfg_page.cfg_iconOnly)
            text: Wrappers.i18n("Group only when the Task Manager is full")
            enabled: cfg_groupingStrategy.currentIndex > 0 && cfg_groupPopups.checked
            Accessible.onPressAction: toggle()
            checked: cfg_page.cfg_onlyGroupWhenFull
            onToggled: cfg_page.cfg_onlyGroupWhenFull = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }



        ComboBox {
            id: cfg_sortingStrategy
            Kirigami.FormData.label: Wrappers.i18n("Sort:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                Wrappers.i18n("Do not sort"),
                Wrappers.i18n("Manually"),
                Wrappers.i18n("Alphabetically"),
                Wrappers.i18n("By desktop"),
                Wrappers.i18n("By activity")
            ]
            currentIndex: cfg_page.cfg_sortingStrategy
            onActivated: (index) => cfg_page.cfg_sortingStrategy = index
        }

        CheckBox {
            id: cfg_separateLaunchers
            visible: (!cfg_page.cfg_iconOnly)
            text: Wrappers.i18n("Keep launchers separate")
            enabled: cfg_sortingStrategy.currentIndex === 1
            checked: cfg_page.cfg_separateLaunchers
            onToggled: cfg_page.cfg_separateLaunchers = checked
        }

        CheckBox {
            id: cfg_hideLauncherOnStart
            visible: (!cfg_page.cfg_iconOnly)
            text: Wrappers.i18n("Hide launchers after application startup")
            checked: cfg_page.cfg_hideLauncherOnStart
            onToggled: cfg_page.cfg_hideLauncherOnStart = checked
        }

        Item {
            Kirigami.FormData.isSection: true
            visible: (!cfg_page.cfg_iconOnly)
        }

        CheckBox {
            id: cfg_minimizeActiveTaskOnClick
            Kirigami.FormData.label: Wrappers.i18n("Clicking active task:")
            text: Wrappers.i18n("Minimizes the task")
            checked: cfg_page.cfg_minimizeActiveTaskOnClick
            onToggled: cfg_page.cfg_minimizeActiveTaskOnClick = checked
        }

        ComboBox {
            id: cfg_middleClickAction
            Kirigami.FormData.label: Wrappers.i18n("Middle-clicking any task:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                Wrappers.i18n("Does nothing"),
                Wrappers.i18n("Closes window or group"),
                Wrappers.i18n("Opens a new window"),
                Wrappers.i18n("Minimizes/Restores window or group"),
                Wrappers.i18n("Toggles grouping"),
                Wrappers.i18n("Brings it to the current virtual desktop")
            ]
            currentIndex: cfg_page.cfg_middleClickAction
            onActivated: (index) => cfg_page.cfg_middleClickAction = index
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: cfg_wheelEnabled
            Kirigami.FormData.label: Wrappers.i18n("Mouse wheel:")
            text: Wrappers.i18n("Cycles through tasks")
            checked: cfg_page.cfg_wheelEnabled
            onToggled: cfg_page.cfg_wheelEnabled = checked
        }

        RowLayout {
            // HACK: Workaround for Kirigami bug 434625
            // due to which a simple Layout.leftMargin on CheckBox doesn't work
            Item { implicitWidth: Kirigami.Units.gridUnit }
            CheckBox {
                id: cfg_wheelSkipMinimized
                text: Wrappers.i18n("Skip minimized tasks")
                enabled: cfg_wheelEnabled.checked
                checked: cfg_page.cfg_wheelSkipMinimized
                onToggled: cfg_page.cfg_wheelSkipMinimized = checked
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: cfg_showOnlyCurrentScreen
            Kirigami.FormData.label: Wrappers.i18n("Show only tasks:")
            text: Wrappers.i18n("From current screen")
            checked: cfg_page.cfg_showOnlyCurrentScreen
            onToggled: cfg_page.cfg_showOnlyCurrentScreen = checked
        }

        CheckBox {
            id: cfg_showOnlyCurrentDesktop
            text: Wrappers.i18n("From current desktop")
            checked: cfg_page.cfg_showOnlyCurrentDesktop
            onToggled: cfg_page.cfg_showOnlyCurrentDesktop = checked
        }

        CheckBox {
            id: cfg_showOnlyCurrentActivity
            text: Wrappers.i18n("From current activity")
            checked: cfg_page.cfg_showOnlyCurrentActivity
            onToggled: cfg_page.cfg_showOnlyCurrentActivity = checked
        }

        CheckBox {
            id: cfg_showOnlyMinimized
            text: Wrappers.i18n("That are minimized")
            checked: cfg_page.cfg_showOnlyMinimized
            onToggled: cfg_page.cfg_showOnlyMinimized = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: cfg_unhideOnAttention
            Kirigami.FormData.label: Wrappers.i18n("When panel is hidden:")
            text: Wrappers.i18n("Unhide when a window wants attention")
            checked: cfg_page.cfg_unhideOnAttention
            onToggled: cfg_page.cfg_unhideOnAttention = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ButtonGroup {
            id: reverseModeRadioButtonGroup
        }

        RadioButton {
            Kirigami.FormData.label: Wrappers.i18n("New tasks appear:")
            checked: !cfg_page.cfg_reverseMode
            text: {
                if (Plasmoid.formFactor === PlasmaCore.Types.Vertical) {
                    return Wrappers.i18n("On the bottom")
                }
                // horizontal
                if (!LayoutMirroring.enabled) {
                    return Wrappers.i18n("To the right");
                } else {
                    return Wrappers.i18n("To the left")
                }
            }
            ButtonGroup.group: reverseModeRadioButtonGroup
        }

        RadioButton {
            id: cfg_reverseMode
            checked: cfg_page.cfg_reverseMode
            onToggled: cfg_page.cfg_reverseMode = checked
            text: {
                if (Plasmoid.formFactor === PlasmaCore.Types.Vertical) {
                    return Wrappers.i18n("On the top")
                }
                // horizontal
                if (!LayoutMirroring.enabled) {
                    return Wrappers.i18n("To the left");
                } else {
                    return Wrappers.i18n("To the right");
                }
            }
            ButtonGroup.group: reverseModeRadioButtonGroup
        }
    }
}
