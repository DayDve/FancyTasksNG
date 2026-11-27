/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.plasmoid

import "../ui/code/singletones"
import "../ui/code/tools.js" as TaskTools

// Task actions: what clicks, the mouse wheel and the keyboard do on a task.
ConfigPage {
    id: actionsPage

    // The widget's shortcut isn't a cfg_ value: the dialog learns of a new
    // one through unsavedChanges, and it's written in onAboutToSave.
    readonly property bool unsavedChanges: String(hintShortcut.keySequence) !== String(Plasmoid.globalShortcut)
    onAboutToSave: {
        if (unsavedChanges)
            Plasmoid.globalShortcut = hintShortcut.keySequence;
        if (actionsPage.cfg_keyboardHints && !hintShortcut.isSet) {
            actionsPage.cfg_keyboardHints = false;
            keyboardHintsCheck.checked = false;
        }
    }
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
    readonly property var groupWheelValues: [6, 1, 2, 3, 4, 5]
    readonly property var groupWheelModel: [
        Wrappers.i18n("Does nothing"),
        Wrappers.i18n("Cycles through all tasks"),
        Wrappers.i18n("Cycles through all tasks (skip minimized)"),
        Wrappers.i18n("Cycles through the group's windows"),
        Wrappers.i18n("Cycles through the group's windows (skip minimized)"),
        Wrappers.i18n("Adjusts the group's volume")
    ]

    readonly property var emptyWheelValues: [0, 1, 2, 5]
    readonly property var emptyWheelModel: [
        Wrappers.i18n("Does nothing"),
        Wrappers.i18n("Cycles through all tasks"),
        Wrappers.i18n("Cycles through all tasks (skip minimized)"),
        Wrappers.i18n("Adjusts volume of the active window")
    ]

    // Whether the wheel adjusts a volume in one of the lists, with or
    // without Ctrl.
    function wheelVolumeIn(ctrl: bool): bool {
        const elsewhere = ctrl ? actionsPage.cfg_wheelCtrlAction : actionsPage.cfg_wheelAction;
        return TaskTools.wheelElsewhereAction(elsewhere) === 5
            || TaskTools.wheelGroupResolved(ctrl ? actionsPage.cfg_wheelCtrlGroupAction : actionsPage.cfg_wheelGroupAction, elsewhere) === 5
            || TaskTools.wheelEmptyResolved(ctrl ? actionsPage.cfg_wheelCtrlEmptyAction : actionsPage.cfg_wheelEmptyAction, elsewhere) === 5;
    }

    function setElsewhereWheel(ctrl: bool, index: int): void {
        const elsewhereKey = ctrl ? "cfg_wheelCtrlAction" : "cfg_wheelAction";
        const groupKey = ctrl ? "cfg_wheelCtrlGroupAction" : "cfg_wheelGroupAction";
        const emptyKey = ctrl ? "cfg_wheelCtrlEmptyAction" : "cfg_wheelEmptyAction";
        // The group and off-the-buttons lists show what the wheel does there
        // now, also when that follows this list; keep it there.
        actionsPage[groupKey] = TaskTools.wheelGroupResolved(actionsPage[groupKey], actionsPage[elsewhereKey]);
        actionsPage[emptyKey] = TaskTools.wheelEmptyResolved(actionsPage[emptyKey], actionsPage[elsewhereKey]);
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
        // Nothing here changes the task buttons.
        showPreview: false
        // The mouse tab has the wheel on a panel of its own.
        framed: false

        ConfigTab {
            title: Wrappers.i18n("Mouse")
            iconName: "input-mouse"

            ConfigPanel {
                Kirigami.Heading {
                    level: 4
                    text: Wrappers.i18nc("Mouse button clicks on tasks", "Mouse click")
                }
                // Rows: the left button on the active window's button and on
                // a group button, then the middle button. Cells are placed by
                // hand: a grid skips hidden items and would shift the rest.
                GridLayout {
                    columnSpacing: Kirigami.Units.smallSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    Label {
                        Layout.row: 0
                        Layout.column: 0
                        text: Wrappers.i18nc("A click, under the Mouse click heading", "On the active window's button")
                    }
                    // Turned off, a click activates the window again: nothing happens.
                    ComboBox {
                        Layout.row: 0
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                        model: [Wrappers.i18n("Minimizes the window"), Wrappers.i18n("Does nothing")]
                        currentIndex: actionsPage.cfg_minimizeActiveTaskOnClick ? 0 : 1
                        onActivated: (index) => actionsPage.cfg_minimizeActiveTaskOnClick = index === 0
                    }

                    Label {
                        Layout.row: 1
                        Layout.column: 0
                        text: Wrappers.i18nc("A click, under the Mouse click heading", "On a group button")
                    }
                    ComboBox {
                        Layout.row: 1
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                        model: [Wrappers.i18n("Cycles through tasks"), Wrappers.i18n("Shows small window previews"), Wrappers.i18n("Shows large window previews"), Wrappers.i18n("Shows textual list")]
                        currentIndex: actionsPage.cfg_groupedTaskVisualization
                        onActivated: (index) => actionsPage.cfg_groupedTaskVisualization = index
                    }

                    Label {
                        Layout.row: 2
                        Layout.column: 0
                        text: Wrappers.i18nc("A click, under the Mouse click heading", "With the middle button")
                    }
                    ComboBox {
                        id: middleClickAction
                        Layout.row: 2
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                        model: [Wrappers.i18n("Does nothing"), Wrappers.i18n("Closes window or group"), Wrappers.i18n("Opens a new window"), Wrappers.i18n("Minimizes/Restores window or group"), Wrappers.i18n("Toggles grouping"), Wrappers.i18n("Brings it to the current virtual desktop")]
                        currentIndex: actionsPage.cfg_middleClickAction
                        onActivated: (index) => actionsPage.cfg_middleClickAction = index
                    }

                    // Only for "Closes window or group": nothing else closes
                    // with it. The animations are played in the icons-only mode.
                    Label {
                        Layout.row: 3
                        Layout.column: 0
                        Layout.leftMargin: Kirigami.Units.gridUnit
                        visible: closeAnimation.visible
                        text: Wrappers.i18n("Closing animation")
                    }
                    AnimationCards {
                        id: closeAnimation
                        Layout.row: 3
                        Layout.column: 1
                        visible: middleClickAction.currentIndex === 1 && actionsPage.cfg_iconOnly === 1
                        choices: [
                            { text: Wrappers.i18nc("No animation", "None"), effect: "" },
                            { text: Wrappers.i18nc("Animation", "Smoke"), effect: "smoke" },
                            { text: Wrappers.i18nc("Animation", "Shatter"), effect: "shatter" }
                        ]
                        currentIndex: actionsPage.cfg_closeAnimation
                        onActivated: (index) => actionsPage.cfg_closeAnimation = index
                    }
                }
                RowLayout {
                    CheckBox {
                        text: Wrappers.i18n("Click feedback")
                        checked: actionsPage.cfg_clickFeedback
                        onToggled: actionsPage.cfg_clickFeedback = checked
                    }
                    ConfigHint {
                        info: Wrappers.i18n("On a click, the icon shrinks a little; on a classic panel, the button darkens.")
                    }
                }
            }

            // The wheel options on a panel of their own.
            ConfigPanel {
                Kirigami.Heading {
                    level: 4
                    text: Wrappers.i18n("Mouse wheel")
                }
                // Rows: over a task button, over a group button, off the
                // buttons.
                // Columns: plain wheel, Ctrl+wheel. Cells are placed by hand: a
                // grid skips hidden items and would shift the rest.
                GridLayout {
                    columnSpacing: Kirigami.Units.smallSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    KeyCheckBox {
                        id: wheelCtrlActionEnabled
                        Layout.row: 0
                        Layout.column: 2
                        keys: ["Ctrl"]
                        text: Wrappers.i18nc("Mouse wheel with a key held, %1 is the Ctrl key", "With %1")
                        checked: actionsPage.cfg_wheelCtrlActionEnabled
                        onToggled: actionsPage.cfg_wheelCtrlActionEnabled = checked
                    }

                    Label {
                        Layout.row: 1
                        Layout.column: 0
                        text: Wrappers.i18nc("Mouse wheel", "Over a task button")
                    }
                    ComboBox {
                        Layout.row: 1
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                        model: actionsPage.elsewhereWheelModel
                        currentIndex: actionsPage.elsewhereWheelValues.indexOf(TaskTools.wheelElsewhereAction(actionsPage.cfg_wheelAction))
                        onActivated: (index) => actionsPage.setElsewhereWheel(false, index)
                    }
                    ComboBox {
                        Layout.row: 1
                        Layout.column: 2
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                        enabled: wheelCtrlActionEnabled.checked
                        model: actionsPage.elsewhereWheelModel
                        currentIndex: actionsPage.elsewhereWheelValues.indexOf(TaskTools.wheelElsewhereAction(actionsPage.cfg_wheelCtrlAction))
                        onActivated: (index) => actionsPage.setElsewhereWheel(true, index)
                    }

                    Label {
                        id: groupWheelLabel
                        Layout.row: 2
                        Layout.column: 0
                        enabled: actionsPage.groupsCombined
                        text: Wrappers.i18nc("Mouse wheel", "Over a group button")
                    }
                    ComboBox {
                        Layout.row: 2
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                        enabled: actionsPage.groupsCombined
                        model: actionsPage.groupWheelModel
                        currentIndex: actionsPage.groupWheelValues.indexOf(TaskTools.wheelGroupResolved(actionsPage.cfg_wheelGroupAction, actionsPage.cfg_wheelAction))
                        onActivated: (index) => actionsPage.setGroupWheel(false, index)
                    }
                    ComboBox {
                        Layout.row: 2
                        Layout.column: 2
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                        enabled: actionsPage.groupsCombined && wheelCtrlActionEnabled.checked
                        model: actionsPage.groupWheelModel
                        currentIndex: actionsPage.groupWheelValues.indexOf(TaskTools.wheelGroupResolved(actionsPage.cfg_wheelCtrlGroupAction, actionsPage.cfg_wheelCtrlAction))
                        onActivated: (index) => actionsPage.setGroupWheel(true, index)
                    }
                    ConfigHint {
                        Layout.row: 2
                        Layout.column: 3
                        target: groupWheelLabel
                        reason: Wrappers.i18n("Only when the windows of an application are combined into one button.")
                    }

                    Label {
                        Layout.row: 3
                        Layout.column: 0
                        text: Wrappers.i18nc("Mouse wheel", "Off the buttons")
                    }
                    ComboBox {
                        Layout.row: 3
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                        model: actionsPage.emptyWheelModel
                        currentIndex: actionsPage.emptyWheelValues.indexOf(TaskTools.wheelEmptyResolved(actionsPage.cfg_wheelEmptyAction, actionsPage.cfg_wheelAction))
                        onActivated: (index) => actionsPage.cfg_wheelEmptyAction = actionsPage.emptyWheelValues[index]
                    }
                    ComboBox {
                        Layout.row: 3
                        Layout.column: 2
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                        enabled: wheelCtrlActionEnabled.checked
                        model: actionsPage.emptyWheelModel
                        currentIndex: actionsPage.emptyWheelValues.indexOf(TaskTools.wheelEmptyResolved(actionsPage.cfg_wheelCtrlEmptyAction, actionsPage.cfg_wheelCtrlAction))
                        onActivated: (index) => actionsPage.cfg_wheelCtrlEmptyAction = actionsPage.emptyWheelValues[index]
                    }
                }

                // Shift changes whose volume the wheel adjusts, wherever it
                // does: shown while one of the lists above is set to it.
                KeyCheckBox {
                    visible: actionsPage.wheelVolumeIn(false) || (wheelCtrlActionEnabled.checked && actionsPage.wheelVolumeIn(true))
                    keys: ["Shift"]
                    text: Wrappers.i18nc("%1 is the Shift key", "With %1 ‒ the system volume instead of a window's or group's")
                    checked: actionsPage.cfg_wheelShiftSystemVolumeEnabled
                    onToggled: actionsPage.cfg_wheelShiftSystemVolumeEnabled = checked
                }
            }
        }

        ConfigTab {
            title: Wrappers.i18n("Keyboard")
            iconName: "input-keyboard"

            ConfigPanel {
                RowLayout {
                    CheckBox {
                        id: taskEntryShortcuts
                        text: Wrappers.i18n("Task activation")
                        checked: actionsPage.cfg_taskEntryShortcuts
                        onToggled: actionsPage.cfg_taskEntryShortcuts = checked
                    }
                    // The keys are set there, one shortcut per task.
                    Button {
                        icon.name: "configure-shortcuts"
                        text: Wrappers.i18nc("@action:button opens the global shortcuts in System Settings", "Shortcuts…")
                        onClicked: KCM.KCMLauncher.openSystemSettings("kcm_keys", TaskEntryShortcuts.componentName)
                    }
                }
                RowLayout {
                    Item { implicitWidth: Kirigami.Units.gridUnit }
                    CheckBox {
                        enabled: taskEntryShortcuts.checked
                        text: Wrappers.i18nc("Shortcut keys shown on tasks", "Show hints")
                        checked: actionsPage.cfg_showTaskNumbers
                        onToggled: actionsPage.cfg_showTaskNumbers = checked
                    }
                    ConfigHint {
                        info: Wrappers.i18nc("%1 is the held keys, such as Meta or Ctrl+Alt", "While %1 is held, tasks show the keys that switch to them.", TaskEntryShortcuts.heldModifiersName)
                    }
                }
                // Keyboard hints, on the widget's own shortcut (the same one
                // as on the dialog's standard Keyboard Shortcuts page). Turned
                // on with no shortcut, it starts recording one; with none set
                // by Apply, it's turned off again.
                RowLayout {
                    CheckBox {
                        id: keyboardHintsCheck
                        text: Wrappers.i18nc("Name of the mode: a letter shown on every task switches to it", "Letter Jump")
                        checked: actionsPage.cfg_keyboardHints
                        onToggled: {
                            actionsPage.cfg_keyboardHints = checked;
                            if (checked && !hintShortcut.isSet)
                                hintShortcut.startCapturing();
                        }
                    }
                    ConfigHint {
                        info: Wrappers.i18n("The shortcut shows a letter on every task; pressing that letter activates the task.")
                    }
                    KQuickControls.KeySequenceItem {
                        id: hintShortcut
                        readonly property bool isSet: String(keySequence) !== ""
                        keySequence: Plasmoid.globalShortcut
                        // With a modifier: a bare key would be taken from every app.
                        // The recorder still takes one (Esc too), so it's dropped:
                        // Esc then cancels recording.
                        patterns: KQuickControls.ShortcutPattern.ModifierAndKey
                        onKeySequenceModified: {
                            if (isSet && !String(keySequence).includes("+"))
                                keySequence = "";
                        }
                    }
                }
            }
        }
    }
}
