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

            CheckBox {
                id: cfg_groupingStrategy
                text: Wrappers.i18n("Group windows by program name")
                checked: cfg_page.cfg_groupingStrategy === 1
                onToggled: cfg_page.cfg_groupingStrategy = checked ? 1 : 0
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Clicking group button:")
                visible: (!cfg_page.cfg_iconOnly) && cfg_groupingStrategy.checked
            }
            CheckBox {
                id: cfg_groupPopups
                visible: (!cfg_page.cfg_iconOnly) && cfg_groupingStrategy.checked
                text: Wrappers.i18n("Combine into single button")
                checked: cfg_page.cfg_groupPopups
                onToggled: cfg_page.cfg_groupPopups = checked
            }

            CheckBox {
                id: cfg_onlyGroupWhenFull
                visible: (!cfg_page.cfg_iconOnly) && cfg_groupingStrategy.checked && cfg_groupPopups.checked
                text: Wrappers.i18n("Group only when the Task Manager is full")
                Accessible.onPressAction: toggle()
                checked: cfg_page.cfg_onlyGroupWhenFull
                onToggled: cfg_page.cfg_onlyGroupWhenFull = checked
            }

            Item { height: Kirigami.Units.largeSpacing }

            CheckBox {
                id: cfg_sortingStrategy
                text: Wrappers.i18n("Allow manual task reordering")
                checked: cfg_page.cfg_sortingStrategy === 1
                onToggled: cfg_page.cfg_sortingStrategy = (checked ? 1 : 0)
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

            CheckBox {
                id: cfg_smokeExplosionOnClose
                visible: cfg_page.cfg_iconOnly === 1 && cfg_middleClickAction.currentIndex === 1
                text: Wrappers.i18n("Animation of closing/removing an icon from the panel")
                checked: cfg_page.cfg_smokeExplosionOnClose
                onToggled: cfg_page.cfg_smokeExplosionOnClose = checked
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Mouse wheel on task buttons:")
            }
            ComboBox {
                id: cfg_wheelAction
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                model: [
                    Wrappers.i18n("Does nothing"),
                    Wrappers.i18n("Cycles through all tasks"),
                    Wrappers.i18n("Cycles through all tasks (skip minimized)"),
                    Wrappers.i18n("Cycles through tasks of the current group"),
                    Wrappers.i18n("Cycles through tasks of the current group (skip minimized)"),
                    Wrappers.i18n("Adjusts volume of the window")
                ]
                currentIndex: cfg_page.cfg_wheelAction
                onActivated: (index) => cfg_page.cfg_wheelAction = index
            }

            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                Label {
                    text: Wrappers.i18n("With Ctrl held:")
                }
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                ComboBox {
                    id: cfg_wheelCtrlAction
                    Layout.fillWidth: true
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                    model: cfg_wheelAction.model
                    currentIndex: cfg_page.cfg_wheelCtrlAction
                    onActivated: (index) => cfg_page.cfg_wheelCtrlAction = index
                }
            }

            RowLayout {
                visible: (cfg_wheelAction.currentIndex === 5 || cfg_wheelCtrlAction.currentIndex === 5)
                Item { implicitWidth: Kirigami.Units.gridUnit }
                Label {
                    text: Wrappers.i18n("Shift + Mouse Wheel adjusts system volume")
                    font.italic: true
                    opacity: 0.6
                }
            }

            CheckBox {
                id: showToolTips
                text: Wrappers.i18n("Show window thumbnails when hovering over tasks")
                checked: cfg_page.cfg_showToolTips
                onToggled: cfg_page.cfg_showToolTips = checked
            }

            RowLayout {
                visible: showToolTips.checked
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    id: highlightWindows
                    text: Wrappers.i18n("Hide other windows when hovering over thumbnails")
                    checked: cfg_page.cfg_highlightWindows
                    onToggled: cfg_page.cfg_highlightWindows = checked
                }
            }

            RowLayout {
                visible: showToolTips.checked
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    id: showMediaControls
                    text: Wrappers.i18n("Media controls on thumbnails")
                    checked: cfg_page.cfg_showMediaControls
                    onToggled: cfg_page.cfg_showMediaControls = checked
                }
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