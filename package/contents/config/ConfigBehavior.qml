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

import "../ui/code/singletones"

ConfigPage {
    id: cfg_page
    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        LivePreview {
            cfg_page: cfg_page
            location: Plasmoid.location
            Layout.fillWidth: true
            visible: Plasmoid.location !== PlasmaCore.Types.Floating
        }

        ConfigScrollView {

        Kirigami.FormLayout {
            width: parent.width - Kirigami.Units.gridUnit * 2

            Label {
                text: Wrappers.i18n("Group:")
            }
            ComboBox {
                id: cfg_groupingStrategy
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                model: [
                    Wrappers.i18n("Do not group"),
                    Wrappers.i18n("By program name")
                ]
                currentIndex: cfg_page.cfg_groupingStrategy
                onActivated: (index) => cfg_page.cfg_groupingStrategy = index
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Clicking group button:")
                visible: (!cfg_page.cfg_iconOnly) && cfg_groupingStrategy.currentIndex > 0
            }
            CheckBox {
                id: cfg_groupPopups
                visible: (!cfg_page.cfg_iconOnly) && cfg_groupingStrategy.currentIndex > 0
                text: Wrappers.i18n("Combine into single button")
                checked: cfg_page.cfg_groupPopups
                onToggled: cfg_page.cfg_groupPopups = checked
            }

            CheckBox {
                id: cfg_onlyGroupWhenFull
                visible: (!cfg_page.cfg_iconOnly) && cfg_groupingStrategy.currentIndex > 0 && cfg_groupPopups.checked
                text: Wrappers.i18n("Group only when the Task Manager is full")
                Accessible.onPressAction: toggle()
                checked: cfg_page.cfg_onlyGroupWhenFull
                onToggled: cfg_page.cfg_onlyGroupWhenFull = checked
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Sort:")
            }
            ComboBox {
                id: cfg_sortingStrategy
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
                visible: (!cfg_page.cfg_iconOnly) && cfg_sortingStrategy.currentIndex === 1
                text: Wrappers.i18n("Keep launchers separate")
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

            Item { height: Kirigami.Units.largeSpacing }

            CheckBox {
                id: cfg_minimizeActiveTaskOnClick
                text: Wrappers.i18n("Clicking active task minimizes the task")
                checked: cfg_page.cfg_minimizeActiveTaskOnClick
                onToggled: cfg_page.cfg_minimizeActiveTaskOnClick = checked
            }

            Label {
                text: Wrappers.i18n("Middle-clicking any task:")
            }
            ComboBox {
                id: cfg_middleClickAction
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

            Item { height: Kirigami.Units.largeSpacing }

            CheckBox {
                id: cfg_wheelEnabled
                text: Wrappers.i18n("Mouse wheel cycles through tasks")
                checked: cfg_page.cfg_wheelEnabled
                onToggled: cfg_page.cfg_wheelEnabled = checked
            }

            RowLayout {
                visible: cfg_wheelEnabled.checked
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    id: cfg_wheelSkipMinimized
                    text: Wrappers.i18n("Skip minimized tasks")
                    checked: cfg_page.cfg_wheelSkipMinimized
                    onToggled: cfg_page.cfg_wheelSkipMinimized = checked
                }
            }

            CheckBox {
                id: showToolTips
                text: Wrappers.i18n("Show window previews when hovering over tasks")
                checked: cfg_page.cfg_showToolTips
                onToggled: cfg_page.cfg_showToolTips = checked
            }

            CheckBox {
                id: highlightWindows
                text: Wrappers.i18n("Hide other windows when hovering over previews")
                visible: showToolTips.checked
                checked: cfg_page.cfg_highlightWindows
                onToggled: cfg_page.cfg_highlightWindows = checked
            }

            Label {
                text: Wrappers.i18n("Clicking group button:")
            }
            ComboBox {
                id: cfg_groupedTaskVisualization
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                
                model: [
                    Wrappers.i18n("Cycles through tasks"),
                    Wrappers.i18n("Shows small window previews"),
                    Wrappers.i18n("Shows large window previews"),
                    Wrappers.i18n("Shows textual list"),
                ]
                currentIndex: cfg_page.cfg_groupedTaskVisualization
                onActivated: (index) => cfg_page.cfg_groupedTaskVisualization = index
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Show only tasks:")
            }
            CheckBox {
                id: cfg_showOnlyCurrentScreen
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


            ButtonGroup {
                id: minimizedFilterButtonGroup
            }

            RadioButton {
                checked: cfg_page.cfg_minimizedFilter === 0
                text: Wrappers.i18n("In any state")
                ButtonGroup.group: minimizedFilterButtonGroup
                onToggled: if (checked) cfg_page.cfg_minimizedFilter = 0
            }

            RadioButton {
                checked: cfg_page.cfg_minimizedFilter === 1
                text: Wrappers.i18n("Only minimized")
                ButtonGroup.group: minimizedFilterButtonGroup
                onToggled: if (checked) cfg_page.cfg_minimizedFilter = 1
            }

            RadioButton {
                checked: cfg_page.cfg_minimizedFilter === 2
                text: Wrappers.i18n("Only not minimized")
                ButtonGroup.group: minimizedFilterButtonGroup
                onToggled: if (checked) cfg_page.cfg_minimizedFilter = 2
            }

            Item { height: Kirigami.Units.largeSpacing }

            CheckBox {
                id: cfg_unhideOnAttention
                text: Wrappers.i18n("Unhide when a window wants attention")
                checked: cfg_page.cfg_unhideOnAttention
                onToggled: cfg_page.cfg_unhideOnAttention = checked
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Context menu:")
            }

            CheckBox {
                id: cfg_hideMoveToDesktopMenuWithOneDesktop
                text: Wrappers.i18n("Hide 'Move to Desktop' if only one virtual desktop is used")
                checked: cfg_page.cfg_hideMoveToDesktopMenuWithOneDesktop
                onToggled: cfg_page.cfg_hideMoveToDesktopMenuWithOneDesktop = checked

                Layout.fillWidth: true

                contentItem: Text {
                    text: cfg_hideMoveToDesktopMenuWithOneDesktop.text
                    font: cfg_hideMoveToDesktopMenuWithOneDesktop.font
                    color: Kirigami.Theme.textColor
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: cfg_hideMoveToDesktopMenuWithOneDesktop.indicator.width + cfg_hideMoveToDesktopMenuWithOneDesktop.spacing
                }
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("New tasks appear:")
            }

            ButtonGroup {
                id: reverseModeRadioButtonGroup
            }

            RadioButton {
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
            } // FormLayout
        } // ConfigScrollView
    } // ColumnLayout
}