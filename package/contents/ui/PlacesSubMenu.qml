/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.extras as PlasmaExtras

PlasmaExtras.MenuItem {
    id: root
    text: qsTr("Places")
    icon: "folder"
    
    property alias subMenu: innerMenu

    readonly property PlasmaExtras.Menu _subMenu: PlasmaExtras.Menu {
        id: innerMenu
        visualParent: root.action
    }
}
