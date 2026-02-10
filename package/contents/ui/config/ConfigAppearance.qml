/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kquickcontrols as KQuickAddons

import "../code/singletones"

ConfigPage {
    id: cfg_page
    readonly property bool plasmaPaAvailable: Qt.createComponent("../PulseAudio.qml").status === Component.Ready
    readonly property bool plasmoidVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconOnly: Plasmoid.configuration.iconOnly







    Kirigami.FormLayout {
        CheckBox {
            id: useBorders
            text: Wrappers.i18n("Use plasma borders")
            checked: cfg_page.cfg_useBorders
            onToggled: cfg_page.cfg_useBorders = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        Slider {
            id: iconScale
            Layout.fillWidth: true
            from: 0
            to: 300
            stepSize: 1.0
            Kirigami.FormData.label: Wrappers.i18n("Icon Scale") + " " + iconScale.valueAt(iconScale.position) + "%"
            visible: !iconSizeOverride.checked
            value: cfg_page.cfg_iconScale
            onMoved: cfg_page.cfg_iconScale = value
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Wrappers.i18n("Icon Hover Effects")
        }

        SpinBox {
            id: iconZoomFactor
            Kirigami.FormData.label: Wrappers.i18n("Icon zoom factor (px):")
            from: 0
            to: 50
            stepSize: 1
            value: cfg_page.cfg_iconZoomFactor
            onValueModified: cfg_page.cfg_iconZoomFactor = value

            ToolTip.delay: 1000
            ToolTip.visible: hovered
            ToolTip.text: Wrappers.i18n("How much the icon should grow when hovered (in pixels)")
        }

        SpinBox {
            id: iconZoomDuration
            Kirigami.FormData.label: Wrappers.i18n("Zoom animation duration (ms):")
            from: 0
            to: 1000
            stepSize: 50
            value: cfg_page.cfg_iconZoomDuration
            onValueModified: cfg_page.cfg_iconZoomDuration = value

            ToolTip.delay: 1000
            ToolTip.visible: hovered
            ToolTip.text: Wrappers.i18n("Duration of the zoom animation in milliseconds")
        }

        SpinBox {
            id: iconSizePx
            Kirigami.FormData.label: Wrappers.i18n("Icon Size (px):")
            from: 0
            to: 999
            visible: iconSizeOverride.checked
            value: cfg_page.cfg_iconSizePx
            onValueModified: cfg_page.cfg_iconSizePx = value
        }

        CheckBox {
            id: iconSizeOverride
            text: Wrappers.i18n("Set icon size instead of scaling")
            checked: cfg_page.cfg_iconSizeOverride
            onToggled: cfg_page.cfg_iconSizeOverride = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ButtonGroup {
            id: colorizeButtonGroup
        }

        RadioButton {
            Kirigami.FormData.label: Wrappers.i18n("Button Colors:")
            checked: !buttonColorize.checked
            text: Wrappers.i18n("Using Plasma Style/Accent")
            ButtonGroup.group: colorizeButtonGroup
            onToggled: if (checked) cfg_page.cfg_buttonColorize = false
        }

        RadioButton {
            id: buttonColorize
            checked: cfg_page.cfg_buttonColorize
            onToggled: cfg_page.cfg_buttonColorize = checked
            text: Wrappers.i18n("Using Color Overlay")
            ButtonGroup.group: colorizeButtonGroup
        }

        CheckBox {
            id: buttonColorizeDominant
            enabled: buttonColorize.checked
            text: Wrappers.i18n("Use dominant icon color")
            visible: buttonColorize.checked
            checked: cfg_page.cfg_buttonColorizeDominant
            onToggled: cfg_page.cfg_buttonColorizeDominant = checked
        }

        KQuickAddons.ColorButton {
            id: buttonColorizeCustom
            Layout.leftMargin: Kirigami.Units.gridUnit
            enabled: buttonColorize.checked & !buttonColorizeDominant.checked
            Kirigami.FormData.label: Wrappers.i18n("Custom Color:")
            showAlphaChannel: true
            visible: buttonColorize.checked && !buttonColorizeDominant.checked
            color: cfg_page.cfg_buttonColorizeCustom
            onColorChanged: cfg_page.cfg_buttonColorizeCustom = color
        }

        CheckBox {
            id: buttonColorizeInactive
            text: Wrappers.i18n("Colorize inactive buttons")
            visible: buttonColorize.checked
            enabled: !disableButtonInactiveSvg.checked
            checked: cfg_page.cfg_buttonColorizeInactive
            onToggled: cfg_page.cfg_buttonColorizeInactive = checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: disableButtonSvg
            Kirigami.FormData.label: Wrappers.i18n("Plasma Button Decorations:")
            text: Wrappers.i18n("Disable All")
            checked: cfg_page.cfg_disableButtonSvg
            onToggled: cfg_page.cfg_disableButtonSvg = checked
        }
        CheckBox {
            id: disableButtonInactiveSvg
            text: Wrappers.i18n("Disable Inactive Buttons")
            enabled: !disableButtonSvg.checked
            checked: cfg_page.cfg_disableButtonInactiveSvg
            onToggled: cfg_page.cfg_disableButtonInactiveSvg = checked
        }

        CheckBox {
            id: overridePlasmaButtonDirection
            Kirigami.FormData.label: Wrappers.i18n("Plasma Button Direction:")
            text: Wrappers.i18n("Override")
            checked: cfg_page.cfg_overridePlasmaButtonDirection
            onToggled: cfg_page.cfg_overridePlasmaButtonDirection = checked
        }

        Label {
            text: Wrappers.i18n("Be sure to use this when using as a floating widget")
            font: Kirigami.Theme.smallFont
        }

        ComboBox {
            id: plasmaButtonDirection
            visible: overridePlasmaButtonDirection.checked
            model: [Wrappers.i18n("North"), Wrappers.i18n("South"), Wrappers.i18n("West"), Wrappers.i18n("East")]
            currentIndex: cfg_page.cfg_plasmaButtonDirection
            onActivated: (index) => cfg_page.cfg_plasmaButtonDirection = index
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        SpinBox {
            id: maxButtonLength
            visible: !cfg_page.plasmoidVertical && !cfg_page.iconOnly
            Kirigami.FormData.label: Wrappers.i18n("Maximum button length (px):")
            from: 1
            to: 9999
            value: cfg_page.cfg_maxButtonLength
            onValueModified: cfg_page.cfg_maxButtonLength = value
        }

        SpinBox {
            id: taskSpacingSize
            Kirigami.FormData.label: Wrappers.i18n("Space between taskbar items (px):")
            from: 0
            to: 99
            value: cfg_page.cfg_taskSpacingSize
            onValueModified: cfg_page.cfg_taskSpacingSize = value
        }

        CheckBox {
            id: showToolTips
            Kirigami.FormData.label: Wrappers.i18n("General:")
            text: Wrappers.i18n("Show small window previews when hovering over tasks")
            checked: cfg_page.cfg_showToolTips
            onToggled: cfg_page.cfg_showToolTips = checked
        }

        CheckBox {
            id: highlightWindows
            text: Wrappers.i18n("Hide other windows when hovering over previews")
            checked: cfg_page.cfg_highlightWindows
            onToggled: cfg_page.cfg_highlightWindows = checked
        }

        CheckBox {
            id: indicateAudioStreams
            text: Wrappers.i18n("Mark applications that play audio")
            checked: cfg_page.cfg_indicateAudioStreams && cfg_page.plasmaPaAvailable
            onToggled: cfg_page.cfg_indicateAudioStreams = checked
            enabled: cfg_page.plasmaPaAvailable
        }

        CheckBox {
            id: fill
            text: Wrappers.i18n("Fill free space on panel")
            checked: cfg_page.cfg_fill
            onToggled: cfg_page.cfg_fill = checked
        }

        Item {
            Kirigami.FormData.isSection: true
            visible: !cfg_page.iconOnly
        }

        ComboBox {
            id: taskMaxWidth
            visible: !cfg_page.iconOnly && !cfg_page.plasmoidVertical
            Kirigami.FormData.label: Wrappers.i18n("Maximum task width:")
            model: [Wrappers.i18n("Narrow"), Wrappers.i18n("Medium"), Wrappers.i18n("Wide")]
            currentIndex: cfg_page.cfg_taskMaxWidth
            onActivated: (index) => cfg_page.cfg_taskMaxWidth = index
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        RadioButton {
            id: forbidStripes
            Kirigami.FormData.label: cfg_page.plasmoidVertical ? Wrappers.i18n("Use multi-column view:") : Wrappers.i18n("Use multi-row view:")
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

        SpinBox {
            id: maxStripes
            enabled: maxStripes.value > 1
            Kirigami.FormData.label: cfg_page.plasmoidVertical ? Wrappers.i18n("Maximum columns:") : Wrappers.i18n("Maximum rows:")
            from: 1
            value: cfg_page.cfg_maxStripes
            onValueModified: cfg_page.cfg_maxStripes = value
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ComboBox {
            visible: cfg_page.iconOnly
            Kirigami.FormData.label: Wrappers.i18n("Spacing between icons:")

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
            enabled: !Kirigami.Settings.tabletMode

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

        Label {
            visible: Kirigami.Settings.tabletMode
            text: Wrappers.i18n("Automatically set to Large when in Touch mode")
            font: Kirigami.Theme.smallFont
        }
    }
}
