/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore

import "../ui/code/singletones"

// Task layout: what a button holds and how big it is, rows, and where the
// buttons go on the panel.
ConfigPage {
    id: layoutPage
    fullTitle: Wrappers.i18n("Task Layout")

    readonly property bool plasmoidVertical: layoutPage.plasmoidFormFactor === PlasmaCore.Types.Vertical
    readonly property bool onPanel: layoutPage.plasmoidLocation !== PlasmaCore.Types.Floating
    // Button width and title options apply to buttons with titles in a row.
    readonly property bool classicRow: layoutPage.cfg_iconOnly === 0 && !layoutPage.plasmoidVertical
    readonly property string classicRowReason: layoutPage.cfg_iconOnly === 1 ? Wrappers.i18n("Only in the classic panel mode.")
        : Wrappers.i18n("Not available on a vertical panel.")

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

            RowLayout {
                Label {
                    id: maxButtonLengthLabel
                    enabled: layoutPage.classicRow
                    text: Wrappers.i18n("Maximum button width (px):")
                }
                ConfigHint {
                    target: maxButtonLengthLabel
                    reason: layoutPage.classicRowReason
                }
            }
            SpinBox {
                enabled: layoutPage.classicRow
                from: 40
                to: 1000
                value: layoutPage.cfg_maxButtonLength
                onValueModified: layoutPage.cfg_maxButtonLength = value
            }

            RowLayout {
                CheckBox {
                    id: fitButtonToText
                    enabled: layoutPage.classicRow
                    text: Wrappers.i18n("Fit button width to its title")
                    checked: layoutPage.cfg_fitButtonToText
                    onToggled: layoutPage.cfg_fitButtonToText = checked
                }
                ConfigHint {
                    target: fitButtonToText
                    reason: layoutPage.classicRowReason
                }
            }

            RowLayout {
                Label {
                    id: minFitButtonLengthLabel
                    enabled: fitButtonToText.enabled && fitButtonToText.checked
                    text: Wrappers.i18n("Minimum button width (px):")
                }
                ConfigHint {
                    target: minFitButtonLengthLabel
                    reason: fitButtonToText.enabled ? Wrappers.i18n("Turn on \"%1\" first.", fitButtonToText.text) : layoutPage.classicRowReason
                }
            }
            SpinBox {
                enabled: fitButtonToText.enabled && fitButtonToText.checked
                from: 40
                to: 1000
                value: layoutPage.cfg_minFitButtonLength
                onValueModified: layoutPage.cfg_minFitButtonLength = value
            }

            RowLayout {
                Label {
                    id: maxTextLinesLabel
                    enabled: layoutPage.cfg_iconOnly === 0
                    text: Wrappers.i18n("Lines of title text:")
                }
                ConfigHint {
                    target: maxTextLinesLabel
                    reason: Wrappers.i18n("Only in the classic panel mode.")
                }
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
            RowLayout {
                ComboBox {
                    id: iconSpacing
                    enabled: !layoutPage.tabletMode
                    model: [Wrappers.i18n("Small"), Wrappers.i18n("Normal"), Wrappers.i18n("Large"), Wrappers.i18n("Huge")]
                    currentIndex: layoutPage.tabletMode ? 3 : layoutPage.cfg_iconSpacing
                    onActivated: (index) => layoutPage.cfg_iconSpacing = index
                }
                ConfigHint {
                    target: iconSpacing
                    reason: Wrappers.i18n("Automatically set to Large when in Touch mode")
                }
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

            RowLayout {
                Label {
                    id: maxStripesLabel
                    enabled: layoutPage.cfg_maxStripes > 1
                    text: layoutPage.plasmoidVertical ? Wrappers.i18n("Maximum columns:") : Wrappers.i18n("Maximum rows:")
                }
                ConfigHint {
                    target: maxStripesLabel
                    reason: Wrappers.i18n("Choose when to use the multi-row view first.")
                }
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

            RowLayout {
                CheckBox {
                    id: fill
                    enabled: layoutPage.onPanel
                    text: Wrappers.i18n("Fill free space on panel")
                    checked: layoutPage.cfg_fill
                    onToggled: layoutPage.cfg_fill = checked
                }
                ConfigHint {
                    target: fill
                    reason: Wrappers.i18n("Only when the widget is on a panel.")
                }
            }

            RowLayout {
                Item { implicitWidth: layoutPage.gridUnit }
                RowLayout {
                    id: fillAlignment
                    enabled: fill.enabled && fill.checked && layoutPage.cfg_iconOnly === 1
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
                ConfigHint {
                    target: fillAlignment
                    reason: !fill.enabled ? Wrappers.i18n("Only when the widget is on a panel.")
                        : layoutPage.cfg_iconOnly !== 1 ? Wrappers.i18n("Only in the icons-only mode.")
                        : Wrappers.i18n("Turn on \"%1\" first.", fill.text)
                }
            }

            Item { height: layoutPage.largeSpacing }

            Label {
                enabled: !layoutPage.onPanel
                text: Wrappers.i18n("Floating Mode Settings:")
            }
            RowLayout {
                CheckBox {
                    id: overridePlasmaButtonDirection
                    enabled: !layoutPage.onPanel
                    text: Wrappers.i18n("Override system direction")
                    checked: layoutPage.cfg_overridePlasmaButtonDirection
                    onToggled: layoutPage.cfg_overridePlasmaButtonDirection = checked
                }
                ConfigHint {
                    target: overridePlasmaButtonDirection
                    reason: Wrappers.i18n("Only when the widget is on the desktop, not on a panel.")
                }
            }
            RowLayout {
                ComboBox {
                    id: plasmaButtonDirection
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
                ConfigHint {
                    target: plasmaButtonDirection
                    reason: overridePlasmaButtonDirection.enabled ? Wrappers.i18n("Turn on \"%1\" first.", overridePlasmaButtonDirection.text)
                        : Wrappers.i18n("Only when the widget is on the desktop, not on a panel.")
                }
            }
        }
    }
}
