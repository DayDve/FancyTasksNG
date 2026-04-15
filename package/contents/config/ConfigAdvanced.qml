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
                opacity: fillEnabled ? 1.0 : 0.6

                readonly property bool fillEnabled: plasmoid.location !== PlasmaCore.Types.Floating && cfg_page.cfg_iconOnly
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: plasmoid.location === PlasmaCore.Types.Floating
                type: Kirigami.MessageType.Information
                text: Wrappers.i18n("These options are only available when the widget is on a panel.")
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: plasmoid.location !== PlasmaCore.Types.Floating && !cfg_page.cfg_iconOnly
                type: Kirigami.MessageType.Information
                text: Wrappers.i18n("These options are only available in icon-only mode.")
            }

            CheckBox {
                id: fill
                text: Wrappers.i18n("Fill free space on panel")
                enabled: plasmoid.location !== PlasmaCore.Types.Floating && cfg_page.cfg_iconOnly
                checked: cfg_page.cfg_fill
                onToggled: cfg_page.cfg_fill = checked
            }

            RowLayout {
                visible: fill.checked && fill.enabled
                Item { implicitWidth: Kirigami.Units.gridUnit }

                Label {
                    text: Wrappers.i18n("Alignment:")
                }
                ComboBox {
                    id: fillAlignment
                    Layout.fillWidth: true
                    model: [
                        Wrappers.i18n("Edge"),
                        Wrappers.i18n("Center")
                    ]
                    currentIndex: cfg_page.cfg_fillAlignment
                    onActivated: (index) => cfg_page.cfg_fillAlignment = index
                }
            }
        }
    }
}
