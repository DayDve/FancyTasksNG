/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../ui/code/singletones"

ConfigPage {
    id: cfg_page

    ScrollView {
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Kirigami.FormLayout {
            width: parent.width - Kirigami.Units.gridUnit * 2
            
            Label {
                text: Wrappers.i18n("Button Direction:")
            }

            CheckBox {
                id: overridePlasmaButtonDirection
                text: Wrappers.i18n("Override system direction")
                checked: cfg_page.cfg_overridePlasmaButtonDirection
                onToggled: cfg_page.cfg_overridePlasmaButtonDirection = checked
            }

            ComboBox {
                id: plasmaButtonDirection
                Layout.fillWidth: true
                visible: overridePlasmaButtonDirection.checked
                model: [Wrappers.i18n("North"), Wrappers.i18n("South"), Wrappers.i18n("West"), Wrappers.i18n("East")]
                currentIndex: cfg_page.cfg_plasmaButtonDirection
                onActivated: (index) => cfg_page.cfg_plasmaButtonDirection = index
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Layout settings:")
            }

            CheckBox {
                id: fill
                text: Wrappers.i18n("Fill free space on panel")
                checked: cfg_page.cfg_fill
                onToggled: cfg_page.cfg_fill = checked
            }
        }
    }
}
