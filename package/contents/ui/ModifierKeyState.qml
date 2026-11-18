/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

import "code/singletones"

// Which modifier keys are held, from KWin's keystate protocol, as Qt's
// modifier bits. Kept in its own file and loaded by path: the module is
// private to Plasma's keyboard indicator, and if it goes away only the task
// numbers stop showing.
Item {
    KeyboardIndicator.KeyState {
        id: shift
        key: Qt.Key_Shift
    }
    KeyboardIndicator.KeyState {
        id: control
        key: Qt.Key_Control
    }
    KeyboardIndicator.KeyState {
        id: alt
        key: Qt.Key_Alt
    }
    KeyboardIndicator.KeyState {
        id: meta
        key: Qt.Key_Meta
    }

    readonly property int held: (shift.pressed ? Qt.ShiftModifier : 0)
        | (control.pressed ? Qt.ControlModifier : 0)
        | (alt.pressed ? Qt.AltModifier : 0)
        | (meta.pressed ? Qt.MetaModifier : 0)
    onHeldChanged: TaskEntryShortcuts.heldModifiers = held
    Component.onCompleted: TaskEntryShortcuts.heldModifiers = held
}
