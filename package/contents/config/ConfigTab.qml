/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

// One tab of a ConfigTabbedPage; its content becomes rows of the form.
Kirigami.FormLayout {
    property string title
    property string iconName
    // A tab whose options all depend on a switch above the tabs is greyed
    // out while it's off, and the page says why.
    property bool available: true
    property string unavailableReason
    // Off: the tab has panels of its own instead of the page's frame (as
    // an unframed ConfigTabbedPage, for this tab only).
    property bool framed: true
    // Set by ConfigTabbedPage.
    property bool current: false

    enabled: current && available
    opacity: current ? 1 : 0
    z: current ? 1 : 0
}
