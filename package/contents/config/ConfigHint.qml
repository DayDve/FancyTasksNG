/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

// An (i) next to an option: why it's greyed out (reason, while the target
// is disabled), or else what it does (info). Put it next to the option, not
// inside it: a disabled parent would disable it too, and its tooltip
// wouldn't open.
Kirigami.ContextualHelpButton {
    id: hint

    property Item target: null
    property string reason
    property string info

    readonly property bool targetDisabled: hint.target !== null && !hint.target.enabled
    readonly property string message: hint.targetDisabled ? hint.reason : hint.info
    // Disabled with its whole row (a greyed-out tab, say): its tooltip
    // couldn't open, and something above already says why.
    readonly property bool shown: hint.enabled && hint.message !== ""

    toolTipText: hint.message
    // It keeps its place when it has nothing to say, so the row doesn't
    // change width and a centered form doesn't shift.
    opacity: hint.shown ? 1 : 0
    hoverEnabled: hint.shown
    focusPolicy: hint.shown ? Qt.TabFocus : Qt.NoFocus

    // As tall as a line of text, so it doesn't push the rows apart.
    padding: 0
    icon.width: Kirigami.Units.iconSizes.small
    icon.height: Kirigami.Units.iconSizes.small
}
