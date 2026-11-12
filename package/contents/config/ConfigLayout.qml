/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

import "../ui/code/singletones"

// Task layout: what a button holds and how big it is, rows, and where the
// buttons go on the panel.
ConfigPage {
    id: layoutPage

    readonly property bool plasmoidVertical: layoutPage.plasmoidFormFactor === PlasmaCore.Types.Vertical
    readonly property bool onPanel: layoutPage.plasmoidLocation !== PlasmaCore.Types.Floating
    // Button width and title options apply to buttons with titles in a row.
    readonly property bool classicRow: layoutPage.cfg_iconOnly === 0 && !layoutPage.plasmoidVertical

    ConfigTabbedPage {
        cfg_page: layoutPage

        ConfigTab {
            title: Wrappers.i18n("Buttons")
            iconName: "view-list-text"

            Label {
                text: Wrappers.i18n("Display:")
            }
            ComboBox {
                Layout.fillWidth: true
                Layout.minimumWidth: layoutPage.gridUnit * 14
                model: [Wrappers.i18n("Classic panel"), Wrappers.i18n("Show icons only")]
                currentIndex: layoutPage.cfg_iconOnly
                onActivated: (index) => layoutPage.cfg_iconOnly = index
            }

            Item { height: layoutPage.largeSpacing }

            Label {
                enabled: layoutPage.classicRow
                text: Wrappers.i18n("Maximum button width (px):")
            }
            SpinBox {
                enabled: layoutPage.classicRow
                from: 40
                to: 1000
                value: layoutPage.cfg_maxButtonLength
                onValueModified: layoutPage.cfg_maxButtonLength = value
            }

            CheckBox {
                id: fitButtonToText
                enabled: layoutPage.classicRow
                text: Wrappers.i18n("Fit button width to its title")
                checked: layoutPage.cfg_fitButtonToText
                onToggled: layoutPage.cfg_fitButtonToText = checked
            }

            Label {
                enabled: fitButtonToText.enabled && fitButtonToText.checked
                text: Wrappers.i18n("Minimum button width (px):")
            }
            SpinBox {
                enabled: fitButtonToText.enabled && fitButtonToText.checked
                from: 40
                to: 1000
                value: layoutPage.cfg_minFitButtonLength
                onValueModified: layoutPage.cfg_minFitButtonLength = value
            }

            Label {
                enabled: layoutPage.cfg_iconOnly === 0
                text: Wrappers.i18n("Lines of title text:")
            }
            SpinBox {
                enabled: layoutPage.cfg_iconOnly === 0
                from: 0
                to: 10
                value: layoutPage.cfg_maxTextLines
                onValueModified: layoutPage.cfg_maxTextLines = value
                textFromValue: (value, locale) => value === 0 ? Wrappers.i18n("As many as fit") : Number(value).toLocaleString(locale, "f", 0)
                valueFromText: (text, locale) => text === Wrappers.i18n("As many as fit") ? 0 : Number.fromLocaleString(locale, text)
            }

            Item { height: layoutPage.largeSpacing }

            Label {
                text: Wrappers.i18n("Space between taskbar items (px):")
            }
            SpinBox {
                from: 0
                to: 99
                value: layoutPage.cfg_taskSpacingSize
                onValueModified: layoutPage.cfg_taskSpacingSize = value
            }

            Label {
                text: Wrappers.i18n("Inner padding:")
            }
            // The padding along the panel, around the icon and title.
            ComboBox {
                enabled: !layoutPage.tabletMode
                model: [Wrappers.i18n("Small"), Wrappers.i18n("Normal"), Wrappers.i18n("Large"), Wrappers.i18n("Huge")]
                currentIndex: layoutPage.tabletMode ? 3 : layoutPage.cfg_iconSpacing
                onActivated: (index) => layoutPage.cfg_iconSpacing = index
            }
            Label {
                visible: layoutPage.tabletMode
                text: Wrappers.i18n("Automatically set to Large when in Touch mode")
                font: layoutPage.themeSmallFont
            }
        }

        ConfigTab {
            title: Wrappers.i18n("Rows")
            iconName: "view-split-top-bottom"

            Label {
                text: layoutPage.plasmoidVertical ? Wrappers.i18n("Use multi-column view:") : Wrappers.i18n("Use multi-row view:")
            }
            RadioButton {
                text: Wrappers.i18n("Never")
                checked: layoutPage.cfg_maxStripes === 1
                onToggled: {
                    if (checked)
                        layoutPage.cfg_maxStripes = 1;
                }
            }
            RadioButton {
                text: Wrappers.i18n("When panel is low on space and thick enough")
                checked: layoutPage.cfg_maxStripes > 1 && !layoutPage.cfg_forceStripes
                onToggled: {
                    if (checked) {
                        layoutPage.cfg_maxStripes = Math.max(2, layoutPage.cfg_maxStripes);
                        layoutPage.cfg_forceStripes = false;
                    }
                }
            }
            RadioButton {
                text: Wrappers.i18n("Always when panel is thick enough")
                checked: layoutPage.cfg_maxStripes > 1 && layoutPage.cfg_forceStripes
                onToggled: {
                    if (checked) {
                        layoutPage.cfg_maxStripes = Math.max(2, layoutPage.cfg_maxStripes);
                        layoutPage.cfg_forceStripes = true;
                    }
                }
            }

            Item { height: layoutPage.largeSpacing }

            Label {
                enabled: layoutPage.cfg_maxStripes > 1
                text: layoutPage.plasmoidVertical ? Wrappers.i18n("Maximum columns:") : Wrappers.i18n("Maximum rows:")
            }
            SpinBox {
                enabled: layoutPage.cfg_maxStripes > 1
                from: 1
                value: layoutPage.cfg_maxStripes
                onValueModified: layoutPage.cfg_maxStripes = value
            }
        }

        ConfigTab {
            title: Wrappers.i18n("Placement")
            iconName: "align-horizontal-center"

            // Mirrors the whole row, so it starts from the other edge.
            Label {
                text: Wrappers.i18n("New tasks appear:")
            }
            ButtonGroup {
                id: reverseModeGroup
            }
            RadioButton {
                checked: !layoutPage.cfg_reverseMode
                text: layoutPage.plasmoidVertical ? Wrappers.i18n("On the bottom")
                    : (LayoutMirroring.enabled ? Wrappers.i18n("To the left") : Wrappers.i18n("To the right"))
                ButtonGroup.group: reverseModeGroup
                onToggled: if (checked) layoutPage.cfg_reverseMode = false
            }
            RadioButton {
                checked: layoutPage.cfg_reverseMode
                text: layoutPage.plasmoidVertical ? Wrappers.i18n("On the top")
                    : (LayoutMirroring.enabled ? Wrappers.i18n("To the right") : Wrappers.i18n("To the left"))
                ButtonGroup.group: reverseModeGroup
                onToggled: if (checked) layoutPage.cfg_reverseMode = true
            }

            Item { height: layoutPage.largeSpacing }


            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: !layoutPage.onPanel
                type: Kirigami.MessageType.Information
                text: Wrappers.i18n("These options are only available when the widget is on a panel.")
            }

            CheckBox {
                id: fill
                enabled: layoutPage.onPanel
                text: Wrappers.i18n("Fill free space on panel")
                checked: layoutPage.cfg_fill
                onToggled: layoutPage.cfg_fill = checked
            }

            RowLayout {
                enabled: fill.enabled && fill.checked && layoutPage.cfg_iconOnly === 1
                Item { implicitWidth: layoutPage.gridUnit }
                Label {
                    text: Wrappers.i18n("Alignment:")
                }
                ComboBox {
                    Layout.fillWidth: true
                    model: [Wrappers.i18n("Edge"), Wrappers.i18n("Center")]
                    currentIndex: layoutPage.cfg_fillAlignment
                    onActivated: (index) => layoutPage.cfg_fillAlignment = index
                }
            }

            Item { height: layoutPage.largeSpacing }

            Label {
                enabled: !layoutPage.onPanel
                text: Wrappers.i18n("Floating Mode Settings:")
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: layoutPage.onPanel
                type: Kirigami.MessageType.Information
                text: Wrappers.i18n("This option is disabled when the widget is on a panel.")
            }

            CheckBox {
                id: overridePlasmaButtonDirection
                enabled: !layoutPage.onPanel
                text: Wrappers.i18n("Override system direction")
                checked: layoutPage.cfg_overridePlasmaButtonDirection
                onToggled: layoutPage.cfg_overridePlasmaButtonDirection = checked
            }
            ComboBox {
                Layout.fillWidth: true
                enabled: overridePlasmaButtonDirection.enabled && overridePlasmaButtonDirection.checked
                model: [
                    Wrappers.i18n("As on top panel"),
                    Wrappers.i18n("As on bottom panel"),
                    Wrappers.i18n("As on left panel"),
                    Wrappers.i18n("As on right panel")
                ]
                currentIndex: layoutPage.cfg_plasmaButtonDirection
                onActivated: (index) => layoutPage.cfg_plasmaButtonDirection = index
            }
        }
    }
}
