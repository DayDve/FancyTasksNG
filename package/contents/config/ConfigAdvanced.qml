/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

import "../ui/code/singletones"

ConfigPage {
    id: cfg_page

    ScrollView {
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Kirigami.FormLayout {
            width: parent.width - Kirigami.Units.gridUnit * 2
            
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: plasmoid.location !== PlasmaCore.Types.Floating
                type: Kirigami.MessageType.Information
                text: Wrappers.i18n("This option is disabled when the widget is on a panel.")
            }

            Label {
                text: Wrappers.i18n("Floating Mode Settings:")
                font.bold: true
                opacity: plasmoid.location === PlasmaCore.Types.Floating ? 1.0 : 0.6
            }

            CheckBox {
                id: overridePlasmaButtonDirection
                text: Wrappers.i18n("Override system direction")
                enabled: plasmoid.location === PlasmaCore.Types.Floating
                checked: cfg_page.cfg_overridePlasmaButtonDirection
                onToggled: cfg_page.cfg_overridePlasmaButtonDirection = checked
            }

            ComboBox {
                id: plasmaButtonDirection
                Layout.fillWidth: true
                enabled: overridePlasmaButtonDirection.enabled && overridePlasmaButtonDirection.checked
                visible: overridePlasmaButtonDirection.checked
                model: [
                    Wrappers.i18n("As on top panel"),
                    Wrappers.i18n("As on bottom panel"),
                    Wrappers.i18n("As on left panel"),
                    Wrappers.i18n("As on right panel")
                ]
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
