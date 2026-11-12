/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../ui/code/singletones"
import "../ui/code/tools.js" as TaskTools

// Task actions: what clicks and the mouse wheel do on a task.
ConfigPage {
    id: actionsPage
    fullTitle: Wrappers.i18n("Task Actions")

    readonly property bool groupsCombined: actionsPage.cfg_groupingStrategy === 1 && actionsPage.cfg_groupPopups

    // Wheel action values (see wheelActionFor in tools.js) and their names.
    readonly property var elsewhereWheelValues: [0, 1, 2, 5]
    readonly property var elsewhereWheelModel: [
        Wrappers.i18n("Does nothing"),
        Wrappers.i18n("Cycles through all tasks"),
        Wrappers.i18n("Cycles through all tasks (skip minimized)"),
        Wrappers.i18n("Adjusts volume of the window")
    ]
    // 0 is "same as elsewhere".
    readonly property var groupWheelValues: [0, 3, 4, 5]
    readonly property var groupWheelModel: [
        Wrappers.i18n("Same as elsewhere"),
        Wrappers.i18n("Cycles through the group's windows"),
        Wrappers.i18n("Cycles through the group's windows (skip minimized)"),
        Wrappers.i18n("Adjusts the group's volume")
    ]

    readonly property bool wheelAdjustsVolume: {
        const volume = 5;
        const plain = TaskTools.wheelElsewhereAction(actionsPage.cfg_wheelAction) === volume
            || TaskTools.wheelGroupChoice(actionsPage.cfg_wheelGroupAction, actionsPage.cfg_wheelAction) === volume;
        const ctrl = TaskTools.wheelElsewhereAction(actionsPage.cfg_wheelCtrlAction) === volume
            || TaskTools.wheelGroupChoice(actionsPage.cfg_wheelCtrlGroupAction, actionsPage.cfg_wheelCtrlAction) === volume;
        return plain || (actionsPage.cfg_wheelCtrlActionEnabled && ctrl);
    }

    function setElsewhereWheel(ctrl: bool, index: int): void {
        const elsewhereKey = ctrl ? "cfg_wheelCtrlAction" : "cfg_wheelAction";
        const groupKey = ctrl ? "cfg_wheelCtrlGroupAction" : "cfg_wheelGroupAction";
        // An old group-only action applies over groups while the group
        // setting is unset; keep it there before it's replaced.
        if (actionsPage[groupKey] === -1)
            actionsPage[groupKey] = TaskTools.wheelGroupChoice(-1, actionsPage[elsewhereKey]);
        actionsPage[elsewhereKey] = actionsPage.elsewhereWheelValues[index];
    }

    function setGroupWheel(ctrl: bool, index: int): void {
        const elsewhereKey = ctrl ? "cfg_wheelCtrlAction" : "cfg_wheelAction";
        const groupKey = ctrl ? "cfg_wheelCtrlGroupAction" : "cfg_wheelGroupAction";
        actionsPage[groupKey] = actionsPage.groupWheelValues[index];
        // An old group-only action does nothing elsewhere; say so.
        if (TaskTools.isGroupWheelAction(actionsPage[elsewhereKey]))
            actionsPage[elsewhereKey] = 0;
    }

    ConfigTabbedPage {
        cfg_page: actionsPage

        ConfigTab {
            // Turned off, a click activates the window again: nothing happens.
            Label {
                text: Wrappers.i18n("Clicking the active window's button:")
            }
            ComboBox {
                Layout.fillWidth: true
                Layout.minimumWidth: actionsPage.gridUnit * 14
                model: [Wrappers.i18n("Minimizes the window"), Wrappers.i18n("Does nothing")]
                currentIndex: actionsPage.cfg_minimizeActiveTaskOnClick ? 0 : 1
                onActivated: (index) => actionsPage.cfg_minimizeActiveTaskOnClick = index === 0
            }

            Item { height: actionsPage.largeSpacing }


            Label {
                text: Wrappers.i18n("Clicking group button:")
            }
            ComboBox {
                Layout.fillWidth: true
                Layout.minimumWidth: actionsPage.gridUnit * 14
                model: [Wrappers.i18n("Cycles through tasks"), Wrappers.i18n("Shows small window previews"), Wrappers.i18n("Shows large window previews"), Wrappers.i18n("Shows textual list")]
                currentIndex: actionsPage.cfg_groupedTaskVisualization
                onActivated: (index) => actionsPage.cfg_groupedTaskVisualization = index
            }

            Item { height: actionsPage.largeSpacing }

            Label {
                text: Wrappers.i18n("Middle-clicking any task:")
            }
            ComboBox {
                id: middleClickAction
                Layout.fillWidth: true
                Layout.minimumWidth: actionsPage.gridUnit * 14
                model: [Wrappers.i18n("Does nothing"), Wrappers.i18n("Closes window or group"), Wrappers.i18n("Opens a new window"), Wrappers.i18n("Minimizes/Restores window or group"), Wrappers.i18n("Toggles grouping"), Wrappers.i18n("Brings it to the current virtual desktop")]
                currentIndex: actionsPage.cfg_middleClickAction
                onActivated: (index) => actionsPage.cfg_middleClickAction = index
            }
            RowLayout {
                CheckBox {
                    id: smokeExplosionOnClose
                    enabled: actionsPage.cfg_iconOnly === 1 && middleClickAction.currentIndex === 1
                    text: Wrappers.i18n("Animation of closing/removing an icon from the panel")
                    checked: actionsPage.cfg_smokeExplosionOnClose
                    onToggled: actionsPage.cfg_smokeExplosionOnClose = checked
                }
                ConfigHint {
                    target: smokeExplosionOnClose
                    reason: actionsPage.cfg_iconOnly !== 1 ? Wrappers.i18n("Only in the icons-only mode.")
                        : Wrappers.i18n("Only when middle-clicking closes the window.")
                }
            }

            Item { height: actionsPage.largeSpacing }

            Label {
                text: Wrappers.i18n("Mouse wheel:")
            }
            // Rows: over a group button, elsewhere. Columns: plain wheel,
            // Ctrl+wheel.
            GridLayout {
                columns: 4
                columnSpacing: actionsPage.smallSpacing
                rowSpacing: actionsPage.smallSpacing

                Item { implicitWidth: 1 }
                Item { implicitWidth: 1 }
                KeyCheckBox {
                    id: wheelCtrlActionEnabled
                    key: "Ctrl"
                    checked: actionsPage.cfg_wheelCtrlActionEnabled
                    onToggled: actionsPage.cfg_wheelCtrlActionEnabled = checked
                }
                Item { implicitWidth: 1 }

                Label {
                    id: groupWheelLabel
                    enabled: actionsPage.groupsCombined
                    text: Wrappers.i18n("Over a group button")
                }
                ComboBox {
                    Layout.fillWidth: true
                    Layout.preferredWidth: actionsPage.gridUnit * 11
                    enabled: actionsPage.groupsCombined
                    model: actionsPage.groupWheelModel
                    currentIndex: actionsPage.groupWheelValues.indexOf(TaskTools.wheelGroupChoice(actionsPage.cfg_wheelGroupAction, actionsPage.cfg_wheelAction))
                    onActivated: (index) => actionsPage.setGroupWheel(false, index)
                }
                ComboBox {
                    Layout.fillWidth: true
                    Layout.preferredWidth: actionsPage.gridUnit * 11
                    enabled: actionsPage.groupsCombined && wheelCtrlActionEnabled.checked
                    model: actionsPage.groupWheelModel
                    currentIndex: actionsPage.groupWheelValues.indexOf(TaskTools.wheelGroupChoice(actionsPage.cfg_wheelCtrlGroupAction, actionsPage.cfg_wheelCtrlAction))
                    onActivated: (index) => actionsPage.setGroupWheel(true, index)
                }
                ConfigHint {
                    target: groupWheelLabel
                    reason: Wrappers.i18n("Only when the windows of an application are combined into one button.")
                }

                Label {
                    text: Wrappers.i18n("Elsewhere")
                }
                ComboBox {
                    Layout.fillWidth: true
                    Layout.preferredWidth: actionsPage.gridUnit * 11
                    model: actionsPage.elsewhereWheelModel
                    currentIndex: actionsPage.elsewhereWheelValues.indexOf(TaskTools.wheelElsewhereAction(actionsPage.cfg_wheelAction))
                    onActivated: (index) => actionsPage.setElsewhereWheel(false, index)
                }
                ComboBox {
                    Layout.fillWidth: true
                    Layout.preferredWidth: actionsPage.gridUnit * 11
                    enabled: wheelCtrlActionEnabled.checked
                    model: actionsPage.elsewhereWheelModel
                    currentIndex: actionsPage.elsewhereWheelValues.indexOf(TaskTools.wheelElsewhereAction(actionsPage.cfg_wheelCtrlAction))
                    onActivated: (index) => actionsPage.setElsewhereWheel(true, index)
                }
                Item { implicitWidth: 1 }
            }

            // One setting for every place the wheel adjusts the volume.
            RowLayout {
                KeyCheckBox {
                    id: wheelShiftSystemVolume
                    enabled: actionsPage.wheelAdjustsVolume
                    key: "Shift"
                    text: Wrappers.i18n("+ wheel: the system volume instead of the window's")
                    checked: actionsPage.cfg_wheelShiftSystemVolumeEnabled
                    onToggled: actionsPage.cfg_wheelShiftSystemVolumeEnabled = checked
                }
                ConfigHint {
                    target: wheelShiftSystemVolume
                    info: Wrappers.i18n("Wherever the wheel adjusts the volume of a window or a group, it adjusts the system volume while Shift is held.")
                    reason: Wrappers.i18n("Only when the wheel or Ctrl+wheel adjusts the volume.")
                }
            }
        }
    }
}
