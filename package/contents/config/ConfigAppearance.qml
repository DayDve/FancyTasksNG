/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kquickcontrols as KQuickAddons

import "../ui/code/singletones"

ConfigPage {
    id: cfg_page
    readonly property bool plasmaPaAvailable: Qt.createComponent("../ui/PulseAudio.qml").status === Component.Ready
    readonly property bool plasmoidVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconOnly: Plasmoid.configuration.iconOnly

        ScrollView {
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Kirigami.FormLayout {
            width: parent.width - Kirigami.Units.gridUnit * 2
            CheckBox {
                id: useBorders
                text: Wrappers.i18n("Use plasma borders")
                checked: cfg_page.cfg_useBorders
                onToggled: cfg_page.cfg_useBorders = checked
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Display:")
            }
            ComboBox {
                id: cfg_iconOnly
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                model: [Wrappers.i18n("Classic panel"), Wrappers.i18n("Show icons only")]
                currentIndex: cfg_page.cfg_iconOnly
                onActivated: (index) => cfg_page.cfg_iconOnly = index
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Icon size:")
            }

            ComboBox {
                id: iconSizeOverrideCombo
                Layout.fillWidth: true
                model: [Wrappers.i18n("Relative"), Wrappers.i18n("Absolute")]
                currentIndex: cfg_page.cfg_iconSizeOverride ? 1 : 0
                onActivated: (index) => cfg_page.cfg_iconSizeOverride = (index === 1)
            }

            Label {
                text: !cfg_page.cfg_iconSizeOverride ? Wrappers.i18n("Icon Scale:") : Wrappers.i18n("Icon Size:")
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !cfg_page.cfg_iconSizeOverride
                spacing: Kirigami.Units.smallSpacing

                Slider {
                    id: iconScale
                    Layout.fillWidth: true
                    from: 0
                    to: 300
                    stepSize: 1.0
                    value: cfg_page.cfg_iconScale
                    onMoved: cfg_page.cfg_iconScale = value
                }

                SpinBox {
                    id: iconScaleSpin
                    from: 0
                    to: 300
                    editable: true
                    value: Math.round(iconScale.value)
                    onValueModified: cfg_page.cfg_iconScale = value
                }

                Label {
                    text: "%"
                }

                Button {
                    icon.name: "edit-reset"
                    flat: true
                    onClicked: cfg_page.cfg_iconScale = 100
                    ToolTip.text: Wrappers.i18n("Reset to default")
                    ToolTip.visible: hovered
                    ToolTip.delay: 1000
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: cfg_page.cfg_iconSizeOverride
                spacing: Kirigami.Units.smallSpacing

                Slider {
                    id: iconSizePx
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    stepSize: 1
                    value: cfg_page.cfg_iconSizePx
                    onMoved: cfg_page.cfg_iconSizePx = value
                }

                SpinBox {
                    id: iconSizePxSpin
                    from: 0
                    to: 100
                    editable: true
                    value: iconSizePx.value
                    onValueModified: cfg_page.cfg_iconSizePx = value
                }

                Label {
                    text: "px"
                }

                Button {
                    icon.name: "edit-reset"
                    flat: true
                    onClicked: cfg_page.cfg_iconSizePx = 32
                    ToolTip.text: Wrappers.i18n("Reset to default")
                    ToolTip.visible: hovered
                    ToolTip.delay: 1000
                }
            }

            CheckBox {
                id: iconScaleFromEdge
                text: Wrappers.i18n("Scale icons from panel edge")
                checked: cfg_page.cfg_iconScaleFromEdge
                onToggled: cfg_page.cfg_iconScaleFromEdge = checked
            }

            RowLayout {
                visible: iconScaleFromEdge.checked
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Edge offset (px):")
                }
                SpinBox {
                    id: iconEdgeOffset
                    from: 0
                    to: 15
                    stepSize: 1
                    value: cfg_page.cfg_iconEdgeOffset
                    onValueModified: cfg_page.cfg_iconEdgeOffset = value
                }
            }

            Item { 
                height: Kirigami.Units.largeSpacing 
                visible: cfg_page.cfg_iconOnly == 1
            }

            CheckBox {
                id: cfg_taskHoverEffect
                text: Wrappers.i18n("Icon hover effects")
                visible: cfg_page.cfg_iconOnly == 1
                checked: cfg_page.cfg_taskHoverEffect
                onToggled: cfg_page.cfg_taskHoverEffect = checked
            }

            RowLayout {
                visible: cfg_page.cfg_iconOnly == 1 && cfg_taskHoverEffect.checked
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Icon zoom factor (px):")
                }
                SpinBox {
                    id: iconZoomFactor
                    from: 0
                    to: 50
                    stepSize: 1
                    value: cfg_page.cfg_iconZoomFactor
                    onValueModified: cfg_page.cfg_iconZoomFactor = value

                    ToolTip.delay: 1000
                    ToolTip.visible: hovered
                    ToolTip.text: Wrappers.i18n("How much the icon should grow when hovered (in pixels)")
                }
            }

            RowLayout {
                visible: cfg_page.cfg_iconOnly == 1 && cfg_taskHoverEffect.checked
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Zoom animation duration (ms):")
                }
                SpinBox {
                    id: iconZoomDuration
                    from: 0
                    to: 1000
                    stepSize: 50
                    value: cfg_page.cfg_iconZoomDuration
                    onValueModified: cfg_page.cfg_iconZoomDuration = value

                    ToolTip.delay: 1000
                    ToolTip.visible: hovered
                    ToolTip.text: Wrappers.i18n("Duration of the zoom animation in milliseconds")
                }
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: Wrappers.i18n("Button Colors:")
            }

            ButtonGroup {
                id: colorizeButtonGroup
            }

            RadioButton {
                checked: !cfg_page.cfg_buttonColorize
                text: Wrappers.i18n("Using Plasma Style/Accent")
                ButtonGroup.group: colorizeButtonGroup
                onToggled: if (checked) cfg_page.cfg_buttonColorize = false
            }

            RadioButton {
                id: cfg_buttonColorize
                checked: cfg_page.cfg_buttonColorize
                onToggled: if (checked) cfg_page.cfg_buttonColorize = true
                text: Wrappers.i18n("Using Color Overlay")
                ButtonGroup.group: colorizeButtonGroup
            }

            CheckBox {
                id: cfg_buttonColorizeDominant
                text: Wrappers.i18n("Use dominant icon color")
                visible: cfg_page.cfg_buttonColorize
                checked: cfg_page.cfg_buttonColorizeDominant
                onToggled: cfg_page.cfg_buttonColorizeDominant = checked
            }

            Label {
                visible: cfg_page.cfg_buttonColorize && !cfg_page.cfg_buttonColorizeDominant
                text: Wrappers.i18n("Custom Color:")
            }
            KQuickAddons.ColorButton {
                id: cfg_buttonColorizeCustom
                Layout.leftMargin: Kirigami.Units.gridUnit
                showAlphaChannel: true
                visible: cfg_page.cfg_buttonColorize && !cfg_page.cfg_buttonColorizeDominant
                color: cfg_page.cfg_buttonColorizeCustom
                onColorChanged: {
                    if (!Qt.colorEqual(color, cfg_page.cfg_buttonColorizeCustom)) {
                        cfg_page.cfg_buttonColorizeCustom = color
                    }
                }
            }

            CheckBox {
                id: cfg_buttonColorizeInactive
                text: Wrappers.i18n("Colorize inactive buttons")
                visible: cfg_page.cfg_buttonColorize && !cfg_disableButtonInactiveSvg.checked
                checked: cfg_page.cfg_buttonColorizeInactive
                onToggled: cfg_page.cfg_buttonColorizeInactive = checked
            }

            Item { height: Kirigami.Units.largeSpacing }

            CheckBox {
                id: cfg_disableButtonSvg
                text: Wrappers.i18n("Disable plasma context decorations")
                checked: cfg_page.cfg_disableButtonSvg
                onToggled: cfg_page.cfg_disableButtonSvg = checked
            }

            CheckBox {
                id: cfg_disableButtonInactiveSvg
                text: Wrappers.i18n("Hide backgrounds for inactive buttons")
                visible: !cfg_disableButtonSvg.checked
                checked: cfg_page.cfg_disableButtonInactiveSvg
                onToggled: cfg_page.cfg_disableButtonInactiveSvg = checked
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                visible: !cfg_page.plasmoidVertical && !cfg_page.iconOnly
                text: Wrappers.i18n("Maximum button length (px):")
            }
            SpinBox {
                id: maxButtonLength
                visible: !cfg_page.plasmoidVertical && !cfg_page.iconOnly
                from: 1
                to: 9999
                value: cfg_page.cfg_maxButtonLength
                onValueModified: cfg_page.cfg_maxButtonLength = value
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Space between taskbar items (px):")
                }
                SpinBox {
                    id: taskSpacingSize
                    from: 0
                    to: 99
                    value: cfg_page.cfg_taskSpacingSize
                    onValueModified: cfg_page.cfg_taskSpacingSize = value
                }
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                visible: !cfg_page.iconOnly && !cfg_page.plasmoidVertical
                text: Wrappers.i18n("Maximum task width:")
            }
            ComboBox {
                id: taskMaxWidth
                visible: !cfg_page.iconOnly && !cfg_page.plasmoidVertical
                model: [Wrappers.i18n("Narrow"), Wrappers.i18n("Medium"), Wrappers.i18n("Wide")]
                currentIndex: cfg_page.cfg_taskMaxWidth
                onActivated: (index) => cfg_page.cfg_taskMaxWidth = index
            }

            Item { height: Kirigami.Units.largeSpacing }

            Label {
                text: cfg_page.plasmoidVertical ? Wrappers.i18n("Use multi-column view:") : Wrappers.i18n("Use multi-row view:")
            }

            RadioButton {
                id: forbidStripes
                text: Wrappers.i18n("Never")
                checked: cfg_page.cfg_maxStripes === 1
                onToggled: {
                    if (checked) {
                        cfg_page.cfg_maxStripes = 1;
                    }
                }
            }

            RadioButton {
                id: allowStripes
                text: Wrappers.i18n("When panel is low on space and thick enough")
                checked: cfg_page.cfg_maxStripes > 1 && !cfg_page.cfg_forceStripes
                onToggled: {
                    if (checked) {
                        cfg_page.cfg_maxStripes = Math.max(2, cfg_page.cfg_maxStripes);
                        cfg_page.cfg_forceStripes = false;
                    }
                }
            }

            RadioButton {
                id: forceStripes
                text: Wrappers.i18n("Always when panel is thick enough")
                checked: cfg_page.cfg_maxStripes > 1 && cfg_page.cfg_forceStripes
                onToggled: {
                    if (checked) {
                        cfg_page.cfg_maxStripes = Math.max(2, cfg_page.cfg_maxStripes);
                        cfg_page.cfg_forceStripes = true;
                    }
                }
            }

            Label {
                visible: cfg_page.cfg_maxStripes > 1
                text: cfg_page.plasmoidVertical ? Wrappers.i18n("Maximum columns:") : Wrappers.i18n("Maximum rows:")
            }
            SpinBox {
                id: maxStripes
                visible: cfg_page.cfg_maxStripes > 1
                from: 1
                value: cfg_page.cfg_maxStripes
                onValueModified: cfg_page.cfg_maxStripes = value
            }

            Item { height: Kirigami.Units.largeSpacing }

            RowLayout {
                visible: cfg_page.cfg_iconOnly == 1
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Inner padding:")
                }
                ComboBox {
                    model: [
                        {
                            "label": Wrappers.i18n("Small"),
                            "spacing": 0
                        },
                        {
                            "label": Wrappers.i18n("Normal"),
                            "spacing": 1
                        },
                        {
                            "label": Wrappers.i18n("Large"),
                            "spacing": 2
                        },
                        {
                            "label": Wrappers.i18n("Huge"),
                            "spacing": 3
                        },
                    ]

                    textRole: "label"
                    visible: !Kirigami.Settings.tabletMode

                    currentIndex: {
                        if (Kirigami.Settings.tabletMode) {
                            return 3; // Large
                        }

                        switch (cfg_page.cfg_iconSpacing) {
                        case 0:
                            return 0; // Small
                        case 1:
                            return 1; // Normal
                        case 2:
                            return 2; // Medium
                        case 3:
                            return 3; // Large
                        }
                    }
                    onActivated: index => {
                        cfg_page.cfg_iconSpacing = model[currentIndex]["spacing"];
                    }
                }
            }

            Label {
                visible: Kirigami.Settings.tabletMode
                text: Wrappers.i18n("Automatically set to Large when in Touch mode")
                font: Kirigami.Theme.smallFont
            }
        }
    }
}
