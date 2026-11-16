/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

import "code/singletones"

// Whether Meta is held, from KWin's keystate protocol. Kept in its own file
// and loaded by path: the module is private to Plasma's keyboard indicator,
// and if it goes away only the task numbers stop showing.
KeyboardIndicator.KeyState {
    key: Qt.Key_Meta
    onPressedChanged: TaskEntryShortcuts.metaHeld = pressed
}
