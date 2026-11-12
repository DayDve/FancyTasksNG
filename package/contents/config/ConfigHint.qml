/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

// Says why an option is greyed out; shown only while it is. Put it next to
// the option, not inside it: a disabled parent would disable it too, and
// its tooltip wouldn't open.
Kirigami.ContextualHelpButton {
    property Item target
    visible: target !== null && !target.enabled && toolTipText !== ""
    // As tall as a line of text, so it doesn't push the rows apart.
    padding: 0
    icon.width: Kirigami.Units.iconSizes.small
    icon.height: Kirigami.Units.iconSizes.small
}
