/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

// Whether Shift is held, from KWin's keystate protocol: a click on a panel
// doesn't carry the modifiers on Wayland, the panel has no keyboard focus.
// Loaded by path like MetaKeyState.qml, so a missing private module only
// hides Force Quit.
KeyboardIndicator.KeyState {
    key: Qt.Key_Shift
}
