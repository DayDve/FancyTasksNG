/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

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
    id: behaviorPage
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
                text: Wrappers.i18n("Grouping of tasks:")
            }

            ColumnLayout {
                Layout.leftMargin: Kirigami.Units.gridUnit

                RadioButton {
                    id: groupDisabled
                    text: Wrappers.i18nc("State", "Disabled")
                    checked: behaviorPage.cfg_groupingStrategy === 0
                    onToggled: if (checked) behaviorPage.cfg_groupingStrategy = 0
                }

                RadioButton {
                    id: groupSideBySide
                    text: Wrappers.i18n("Place windows of one application side-by-side")
                    checked: behaviorPage.cfg_groupingStrategy === 1 && !behaviorPage.cfg_groupPopups
                    onToggled: if (checked) {
                        behaviorPage.cfg_groupingStrategy = 1;
                        behaviorPage.cfg_groupPopups = false;
                    }
                }

                RadioButton {
                    id: groupCollapsed
                    text: Wrappers.i18n("Combine into one button by application name")
                    checked: behaviorPage.cfg_groupingStrategy === 1 && behaviorPage.cfg_groupPopups
                    onToggled: if (checked) {
                        behaviorPage.cfg_groupingStrategy = 1;
                        behaviorPage.cfg_groupPopups = true;
                    }
                }


                CheckBox {
                    id: groupIconEnabled
                    Layout.leftMargin: Kirigami.Units.gridUnit * 2
                    visible: groupCollapsed.checked
                    text: Wrappers.i18n("Standard group overlay")
                    checked: behaviorPage.cfg_groupIconEnabled
                    onToggled: behaviorPage.cfg_groupIconEnabled = checked
                }
            }

            Item { height: Kirigami.Units.largeSpacing }



            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Sort tasks:")
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
                    Wrappers.i18n("By activity"),
                    Wrappers.i18n("By horizontal window position")
                ]
                currentIndex: behaviorPage.cfg_sortingStrategy
                onActivated: (index) => behaviorPage.cfg_sortingStrategy = index
            }



            Item { height: Kirigami.Units.largeSpacing }

            CheckBox {
                id: cfg_minimizeActiveTaskOnClick
                text: Wrappers.i18n("Clicking active task minimizes the task")
                checked: behaviorPage.cfg_minimizeActiveTaskOnClick
                onToggled: behaviorPage.cfg_minimizeActiveTaskOnClick = checked
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
                currentIndex: behaviorPage.cfg_middleClickAction
                onActivated: (index) => behaviorPage.cfg_middleClickAction = index
            }

            CheckBox {
                id: cfg_smokeExplosionOnClose
                visible: behaviorPage.cfg_iconOnly === 1 && cfg_middleClickAction.currentIndex === 1
                text: Wrappers.i18n("Animation of closing/removing an icon from the panel")
                checked: behaviorPage.cfg_smokeExplosionOnClose
                onToggled: behaviorPage.cfg_smokeExplosionOnClose = checked
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Mouse wheel:")
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
                currentIndex: behaviorPage.cfg_wheelAction
                onActivated: (index) => {
                    behaviorPage.cfg_wheelAction = index
                    if (index === 5 && behaviorPage.cfg_wheelCtrlAction === 5) {
                        behaviorPage.cfg_wheelCtrlAction = 0
                    }
                }
            }

            // Опция Shift для основного действия
            RowLayout {
                visible: cfg_wheelAction.currentIndex === 5
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    text: Wrappers.i18n("Adjust system volume with Shift key")
                    checked: behaviorPage.cfg_wheelShiftSystemVolumeEnabled
                    onToggled: behaviorPage.cfg_wheelShiftSystemVolumeEnabled = checked
                }
            }

            // Галочка Ctrl
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    id: cfg_wheelCtrlActionEnabled
                    text: Wrappers.i18n("Additional action with Ctrl key")
                    checked: behaviorPage.cfg_wheelCtrlActionEnabled
                    onToggled: behaviorPage.cfg_wheelCtrlActionEnabled = checked
                }
            }

            // Сабопции Ctrl
            RowLayout {
                visible: cfg_wheelCtrlActionEnabled.checked
                Item { implicitWidth: Kirigami.Units.gridUnit * 2 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    ComboBox {
                        id: cfg_wheelCtrlAction
                        Layout.fillWidth: true
                        model: {
                            const fullModel = cfg_wheelAction.model;
                            const filtered = [];
                            for (let i = 0; i < fullModel.length; i++) {
                                if (i !== cfg_wheelAction.currentIndex) {
                                    filtered.push({text: fullModel[i], originalIndex: i});
                                }
                            }
                            return filtered;
                        }
                        textRole: "text"
                        currentIndex: {
                            for (let i = 0; i < model.length; i++) {
                                if (model[i].originalIndex === behaviorPage.cfg_wheelCtrlAction) return i;
                            }
                            return 0;
                        }
                        onActivated: (index) => behaviorPage.cfg_wheelCtrlAction = model[index].originalIndex
                    }

                    CheckBox {
                        visible: cfg_wheelCtrlAction.model[cfg_wheelCtrlAction.currentIndex]?.originalIndex === 5
                        text: Wrappers.i18n("Adjust system volume with Shift key")
                        checked: behaviorPage.cfg_wheelShiftSystemVolumeEnabled
                        onToggled: behaviorPage.cfg_wheelShiftSystemVolumeEnabled = checked
                    }
                }
            }

            CheckBox {
                id: enableToolTips
                text: Wrappers.i18n("Show tooltips when hovering over task buttons")
                checked: behaviorPage.cfg_enableToolTips
                onToggled: behaviorPage.cfg_enableToolTips = checked
            }

            RowLayout {
                visible: enableToolTips.checked
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    id: showToolTips
                    text: Wrappers.i18n("Show window thumbnails in tooltips")
                    checked: behaviorPage.cfg_showToolTips
                    onToggled: behaviorPage.cfg_showToolTips = checked
                }
            }

            RowLayout {
                visible: enableToolTips.checked
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    id: highlightWindows
                    text: Wrappers.i18n("Hide other windows when hovering over a window in the tooltip")
                    checked: behaviorPage.cfg_highlightWindows
                    onToggled: behaviorPage.cfg_highlightWindows = checked
                }
            }

            RowLayout {
                visible: enableToolTips.checked
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    id: showMediaControls
                    text: Wrappers.i18n("Show media controls")
                    checked: behaviorPage.cfg_showMediaControls
                    onToggled: behaviorPage.cfg_showMediaControls = checked
                }
            }

            RowLayout {
                visible: enableToolTips.checked && showToolTips.checked && showMediaControls.checked
                Item { implicitWidth: Kirigami.Units.gridUnit * 2 }
                Label {
                    text: Wrappers.i18n("Media controls location:")
                }
                ComboBox {
                    id: cfg_mediaControlsLocation
                    Layout.fillWidth: true
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 12
                    model: [
                        Wrappers.i18n("On thumbnails (Overlay)"),
                        Wrappers.i18n("Under thumbnails")
                    ]
                    currentIndex: behaviorPage.cfg_mediaControlsLocation
                    onActivated: (index) => behaviorPage.cfg_mediaControlsLocation = index
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
                currentIndex: behaviorPage.cfg_groupedTaskVisualization
                onActivated: (index) => behaviorPage.cfg_groupedTaskVisualization = index
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Show only tasks:")
            }
            CheckBox {
                id: cfg_showOnlyCurrentScreen
                text: Wrappers.i18n("From current screen")
                checked: behaviorPage.cfg_showOnlyCurrentScreen
                onToggled: behaviorPage.cfg_showOnlyCurrentScreen = checked
            }

            CheckBox {
                id: cfg_showOnlyCurrentDesktop
                text: Wrappers.i18n("From current desktop")
                checked: behaviorPage.cfg_showOnlyCurrentDesktop
                onToggled: behaviorPage.cfg_showOnlyCurrentDesktop = checked
            }

            CheckBox {
                id: cfg_showOnlyCurrentActivity
                text: Wrappers.i18n("From current activity")
                checked: behaviorPage.cfg_showOnlyCurrentActivity
                onToggled: behaviorPage.cfg_showOnlyCurrentActivity = checked
            }


            ButtonGroup {
                id: minimizedFilterButtonGroup
            }

            RadioButton {
                checked: behaviorPage.cfg_minimizedFilter === 0
                text: Wrappers.i18n("In any state")
                ButtonGroup.group: minimizedFilterButtonGroup
                onToggled: if (checked) behaviorPage.cfg_minimizedFilter = 0
            }

            RadioButton {
                checked: behaviorPage.cfg_minimizedFilter === 1
                text: Wrappers.i18n("Only minimized")
                ButtonGroup.group: minimizedFilterButtonGroup
                onToggled: if (checked) behaviorPage.cfg_minimizedFilter = 1
            }

            RadioButton {
                checked: behaviorPage.cfg_minimizedFilter === 2
                text: Wrappers.i18n("Only not minimized")
                ButtonGroup.group: minimizedFilterButtonGroup
                onToggled: if (checked) behaviorPage.cfg_minimizedFilter = 2
            }

            Item { height: Kirigami.Units.largeSpacing }
            Label {
                text: Wrappers.i18n("New tasks appear:")
            }

            ButtonGroup {
                id: reverseModeRadioButtonGroup
            }

            RadioButton {
                checked: !behaviorPage.cfg_reverseMode
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
                checked: behaviorPage.cfg_reverseMode
                onToggled: behaviorPage.cfg_reverseMode = checked
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