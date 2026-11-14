/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kquickcontrols as KQuickAddons

// A color setting: shows `value` and reports a picked color through edited().
KQuickAddons.ColorButton {
    required property color value
    signal edited(color picked)

    showAlphaChannel: true
    color: value
    onColorChanged: {
        if (!Qt.colorEqual(color, value))
            edited(color);
    }
}
