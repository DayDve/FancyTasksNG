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

// Task layout: what a button holds, how big it and its icon are and where
// the icon sits, and where the buttons go on the panel, in how many rows.
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
                    id: buttonWidthLabel
                    enabled: layoutPage.classicRow
                    text: Wrappers.i18n("Button width (px):")
                }
                ConfigHint {
                    target: buttonWidthLabel
                    reason: layoutPage.classicRowReason
                }
            }
            RowLayout {
                enabled: layoutPage.classicRow
                spacing: layoutPage.smallSpacing
                Label {
                    text: Wrappers.i18nc("Button width", "maximum:")
                }
                SpinBox {
                    from: 40
                    to: 1000
                    value: layoutPage.cfg_maxButtonLength
                    onValueModified: layoutPage.cfg_maxButtonLength = value
                }
                Item { implicitWidth: layoutPage.largeSpacing }
                Label {
                    enabled: fitButtonToText.checked
                    text: Wrappers.i18nc("Button width", "minimum:")
                }
                SpinBox {
                    enabled: fitButtonToText.checked
                    from: 40
                    to: 1000
                    value: layoutPage.cfg_minFitButtonLength
                    onValueModified: layoutPage.cfg_minFitButtonLength = value
                }
            }
            CheckBox {
                id: fitButtonToText
                enabled: layoutPage.classicRow
                text: Wrappers.i18n("Fit to the title")
                checked: layoutPage.cfg_fitButtonToText
                onToggled: layoutPage.cfg_fitButtonToText = checked
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
                text: Wrappers.i18n("Margins:")
            }
            RowLayout {
                spacing: layoutPage.smallSpacing
                Label {
                    text: Wrappers.i18nc("Margins", "outer (px):")
                }
                SpinBox {
                    from: 0
                    to: 99
                    value: layoutPage.cfg_taskSpacingSize
                    onValueModified: layoutPage.cfg_taskSpacingSize = value
                }
                Item { implicitWidth: layoutPage.largeSpacing }
                Label {
                    text: Wrappers.i18nc("Margins", "inner:")
                }
                ComboBox {
                    id: iconSpacing
                    enabled: !layoutPage.tabletMode
                    model: [Wrappers.i18n("Small"), Wrappers.i18n("Normal"), Wrappers.i18n("Large"), Wrappers.i18n("Huge")]
                    currentIndex: layoutPage.tabletMode ? 3 : layoutPage.cfg_iconSpacing
                    onActivated: (index) => layoutPage.cfg_iconSpacing = index
                }
                ConfigHint {
                    target: iconSpacing
                    info: Wrappers.i18n("Outer: the space between neighboring buttons. Inner: the padding inside a button around its icon and title, so it also sets the button size.")
                    reason: Wrappers.i18n("Automatically set to Large when in Touch mode")
                }
            }

            Item { height: layoutPage.largeSpacing }

            Label {
                text: Wrappers.i18n("Icon size:")
            }
            ComboBox {
                Layout.fillWidth: true
                model: [Wrappers.i18n("Relative"), Wrappers.i18n("Absolute")]
                currentIndex: layoutPage.cfg_iconSizeOverride ? 1 : 0
                onActivated: (index) => layoutPage.cfg_iconSizeOverride = (index === 1)
            }

            // One row for both units, so the form doesn't shift when they
            // change.
            RowLayout {
                Layout.fillWidth: true
                spacing: layoutPage.smallSpacing
                readonly property bool absolute: layoutPage.cfg_iconSizeOverride

                Slider {
                    id: iconSize
                    Layout.fillWidth: true
                    from: 0
                    to: parent.absolute ? 100 : 300
                    stepSize: 1
                    value: parent.absolute ? layoutPage.cfg_iconSizePx : layoutPage.cfg_iconScale
                    onMoved: {
                        if (parent.absolute)
                            layoutPage.cfg_iconSizePx = Math.round(value);
                        else
                            layoutPage.cfg_iconScale = Math.round(value);
                    }
                }
                SpinBox {
                    from: 0
                    to: parent.absolute ? 100 : 300
                    editable: true
                    value: Math.round(iconSize.value)
                    onValueModified: {
                        if (parent.absolute)
                            layoutPage.cfg_iconSizePx = value;
                        else
                            layoutPage.cfg_iconScale = value;
                    }
                }
                Label {
                    // Both units take the same room.
                    Layout.minimumWidth: unitMetrics.advanceWidth
                    text: parent.absolute ? "px" : "%"
                    TextMetrics {
                        id: unitMetrics
                        text: "px"
                    }
                }
                Button {
                    icon.name: "edit-reset"
                    flat: true
                    onClicked: {
                        if (parent.absolute)
                            layoutPage.cfg_iconSizePx = 32;
                        else
                            layoutPage.cfg_iconScale = 100;
                    }
                    ToolTip.text: Wrappers.i18n("Reset to default")
                    ToolTip.visible: hovered
                    ToolTip.delay: 1000
                }
            }

            RowLayout {
                CheckBox {
                    id: iconScaleFromEdge
                    text: Wrappers.i18n("Scale icons from panel edge")
                    checked: layoutPage.cfg_iconScaleFromEdge
                    onToggled: layoutPage.cfg_iconScaleFromEdge = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("When on, icons scale from the panel edge, not from their center. Automatic centering is then off; the icons are aligned with the \"Edge offset\" option.")
                }
            }
            RowLayout {
                spacing: layoutPage.smallSpacing
                Item { implicitWidth: layoutPage.gridUnit }
                RowLayout {
                    id: iconEdgeOffset
                    enabled: iconScaleFromEdge.checked
                    spacing: layoutPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Edge offset (px):")
                    }
                    SpinBox {
                        from: 0
                        to: 15
                        stepSize: 1
                        value: layoutPage.cfg_iconEdgeOffset
                        onValueModified: layoutPage.cfg_iconEdgeOffset = value
                    }
                }
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
                        : layoutPage.cfg_iconOnly !== 1 ? Wrappers.i18n("Only in the icons-only mode.") : ""
                }
            }

            Item { height: layoutPage.largeSpacing }

            // Like the stock task manager: on a thick panel the buttons can
            // stack in rows (columns on a vertical panel).
            RowLayout {
                spacing: layoutPage.smallSpacing
                Label {
                    text: layoutPage.plasmoidVertical ? Wrappers.i18n("Buttons in several columns:") : Wrappers.i18n("Buttons in several rows:")
                }
                ComboBox {
                    id: stripesMode
                    model: [Wrappers.i18n("Never"), Wrappers.i18n("When short of space"), Wrappers.i18n("Always")]
                    currentIndex: layoutPage.cfg_maxStripes <= 1 ? 0 : (layoutPage.cfg_forceStripes ? 2 : 1)
                    onActivated: (index) => {
                        layoutPage.cfg_maxStripes = index === 0 ? 1 : Math.max(2, layoutPage.cfg_maxStripes);
                        layoutPage.cfg_forceStripes = index === 2;
                    }
                }
                Label {
                    enabled: stripesMode.currentIndex > 0
                    text: Wrappers.i18nc("Rows or columns", "at most")
                }
                SpinBox {
                    enabled: stripesMode.currentIndex > 0
                    from: 2
                    value: Math.max(2, layoutPage.cfg_maxStripes)
                    onValueModified: layoutPage.cfg_maxStripes = value
                }
                ConfigHint {
                    info: layoutPage.plasmoidVertical
                        ? Wrappers.i18n("When on, task buttons on a wide vertical panel are placed in several columns. The number of columns is limited by the panel width and the \"at most\" value.")
                        : Wrappers.i18n("When on, task buttons on a thick panel are placed in several rows. The number of rows is limited by the panel thickness and the \"at most\" value.")
                }
            }

            Item { height: layoutPage.largeSpacing }

            Label {
                enabled: !layoutPage.onPanel
                text: Wrappers.i18n("On the desktop:")
            }
            // Off a panel the widget has no screen edge; this picks the one
            // it acts as if it were on (indicators, popups).
            RowLayout {
                CheckBox {
                    id: overridePlasmaButtonDirection
                    enabled: !layoutPage.onPanel
                    text: Wrappers.i18n("Behave as a panel:")
                    checked: layoutPage.cfg_overridePlasmaButtonDirection
                    onToggled: layoutPage.cfg_overridePlasmaButtonDirection = checked
                }
                ComboBox {
                    enabled: overridePlasmaButtonDirection.enabled && overridePlasmaButtonDirection.checked
                    model: [
                        Wrappers.i18n("Top"),
                        Wrappers.i18n("Bottom"),
                        Wrappers.i18n("Left"),
                        Wrappers.i18n("Right")
                    ]
                    currentIndex: layoutPage.cfg_plasmaButtonDirection
                    onActivated: (index) => layoutPage.cfg_plasmaButtonDirection = index
                }
                ConfigHint {
                    target: overridePlasmaButtonDirection
                    reason: Wrappers.i18n("Only when the widget is on the desktop, not on a panel.")
                }
            }
        }
    }
}
