/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

// An (i) next to an option. With a target, it says why the target is
// greyed out and is shown only while it is. Put it next to the option, not
// inside it: a disabled parent would disable it too, and its tooltip
// wouldn't open.
Kirigami.ContextualHelpButton {
    property Item target: null
    // Hidden too when its own row is greyed out (a whole tab, say): its
    // tooltip couldn't open, and something above already says why.
    visible: enabled && toolTipText !== "" && (target === null || !target.enabled)
    // As tall as a line of text, so it doesn't push the rows apart.
    padding: 0
    icon.width: Kirigami.Units.iconSizes.small
    icon.height: Kirigami.Units.iconSizes.small
}
