/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kquickcontrols as KQuickAddons

KCMUtils.SimpleKCM {
    readonly property bool plasmaPaAvailable: Qt.createComponent("PulseAudio.qml").status === Component.Ready
    readonly property bool plasmoidVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconOnly: plasmoid.configuration.iconOnly

    property alias cfg_iconZoomFactor: iconZoomFactor.value
    property alias cfg_iconZoomDuration: iconZoomDuration.value
    property alias cfg_showToolTips: showToolTips.checked
    property alias cfg_highlightWindows: highlightWindows.checked
    property bool cfg_indicateAudioStreams
    property alias cfg_iconScale: iconScale.value
    property alias cfg_iconSizePx: iconSizePx.value
    property alias cfg_iconSizeOverride: iconSizeOverride.checked
    property alias cfg_forceStripes: forceStripes.checked
    property alias cfg_taskMaxWidth: taskMaxWidth.currentIndex
    property alias cfg_maxButtonLength: maxButtonLength.value
    property int cfg_iconSpacing: 0
    property alias cfg_fill: fill.checked

    property alias cfg_useBorders: useBorders.checked
    property alias cfg_taskSpacingSize: taskSpacingSize.value

    property alias cfg_buttonColorize: buttonColorize.checked
    property alias cfg_buttonColorizeInactive: buttonColorizeInactive.checked
    property alias cfg_buttonColorizeDominant: buttonColorizeDominant.checked
    property alias cfg_buttonColorizeCustom: buttonColorizeCustom.color

    property alias cfg_disableButtonSvg: disableButtonSvg.checked
    property alias cfg_disableButtonInactiveSvg: disableButtonInactiveSvg.checked
    property alias cfg_overridePlasmaButtonDirection: overridePlasmaButtonDirection.checked
    property alias cfg_plasmaButtonDirection: plasmaButtonDirection.currentIndex

    Component.onCompleted: {
        /* Don't rely on bindings for checking the radiobuttons
           When checking forceStripes, the condition for the checked value for the allow stripes button
           became true and that one got checked instead, stealing the checked state for the just clicked checkbox
        */
        if (maxStripes.value === 1) {
            forbidStripes.checked = true;
        } else if (!Plasmoid.configuration.forceStripes && maxStripes.value > 1) {
            allowStripes.checked = true;
        } else if (Plasmoid.configuration.forceStripes && maxStripes.value > 1) {
            forceStripes.checked = true;
        }
    }
    Kirigami.FormLayout {
        CheckBox {
            id: useBorders
            text: i18n("Use plasma borders")
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
            Kirigami.FormData.label: i18n("Icon Scale") + " " + iconScale.valueAt(iconScale.position) + "%"
            visible: !iconSizeOverride.checked
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Icon Hover Effects")
        }

        SpinBox {
            id: iconZoomFactor
            Kirigami.FormData.label: i18n("Icon zoom factor (px):")
            from: 0
            to: 50
            stepSize: 1
            value: plasmoid.configuration.iconZoomFactor

            ToolTip.delay: 1000
            ToolTip.visible: hovered
            ToolTip.text: i18n("How much the icon should grow when hovered (in pixels)")
        }

        SpinBox {
            id: iconZoomDuration
            Kirigami.FormData.label: i18n("Zoom animation duration (ms):")
            from: 0
            to: 1000
            stepSize: 50
            value: plasmoid.configuration.iconZoomDuration

            ToolTip.delay: 1000
            ToolTip.visible: hovered
            ToolTip.text: i18n("Duration of the zoom animation in milliseconds")
        }

        SpinBox {
            id: iconSizePx
            Kirigami.FormData.label: i18n("Icon Size (px):")
            from: 0
            to: 999
            visible: iconSizeOverride.checked
        }

        CheckBox {
            id: iconSizeOverride
            text: i18n("Set icon size instead of scaling")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ButtonGroup {
            id: colorizeButtonGroup
        }

        RadioButton {
            Kirigami.FormData.label: i18n("Button Colors:")
            checked: !buttonColorize.checked
            text: i18n("Using Plasma Style/Accent")
            ButtonGroup.group: colorizeButtonGroup
        }

        RadioButton {
            id: buttonColorize
            checked: plasmoid.configuration.buttonColorize === true
            text: i18n("Using Color Overlay")
            ButtonGroup.group: colorizeButtonGroup
        }

        CheckBox {
            id: buttonColorizeDominant
            enabled: buttonColorize.checked
            text: i18n("Use dominant icon color")
            visible: buttonColorize.checked
        }

        KQuickAddons.ColorButton {
            id: buttonColorizeCustom
            Layout.leftMargin: Kirigami.Units.GridUnit
            enabled: buttonColorize.checked & !buttonColorizeDominant.checked
            Kirigami.FormData.label: i18n("Custom Color:")
            showAlphaChannel: true
            visible: buttonColorize.checked && !buttonColorizeDominant.checked
        }

        CheckBox {
            id: buttonColorizeInactive
            text: i18n("Colorize inactive buttons")
            visible: buttonColorize.checked
            enabled: !disableButtonInactiveSvg.checked
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: disableButtonSvg
            Kirigami.FormData.label: i18n("Plasma Button Decorations:")
            text: i18n("Disable All")
        }
        CheckBox {
            id: disableButtonInactiveSvg
            text: i18n("Disable Inactive Buttons")
            enabled: !disableButtonSvg.checked
        }

        CheckBox {
            id: overridePlasmaButtonDirection
            Kirigami.FormData.label: i18n("Plasma Button Direction:")
            text: i18n("Override")
        }

        Label {
            text: i18n("Be sure to use this when using as a floating widget")
            font: Kirigami.Theme.smallFont
        }

        ComboBox {
            id: plasmaButtonDirection
            visible: overridePlasmaButtonDirection.checked
            model: [i18n("North"), i18n("South"), i18n("West"), i18n("East")]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        SpinBox {
            id: maxButtonLength
            visible: !plasmoidVertical && !iconOnly
            Kirigami.FormData.label: i18n("Maximum button length (px):")
            from: 1
            to: 9999
        }

        SpinBox {
            id: taskSpacingSize
            Kirigami.FormData.label: i18n("Space between taskbar items (px):")
            from: 0
            to: 99
        }

        CheckBox {
            id: showToolTips
            Kirigami.FormData.label: i18nc("@label for several checkboxes", "General:")
            text: i18nc("@option:check section General", "Show small window previews when hovering over tasks")
        }

        CheckBox {
            id: highlightWindows
            text: i18nc("@option:check section General", "Hide other windows when hovering over previews")
        }

        CheckBox {
            id: indicateAudioStreams
            text: i18nc("@option:check section General", "Mark applications that play audio")
            checked: cfg_indicateAudioStreams && plasmaPaAvailable
            onToggled: cfg_indicateAudioStreams = checked
            enabled: plasmaPaAvailable
        }

        CheckBox {
            id: fill
            text: i18nc("@option:check section General", "Fill free space on panel")
        }

        Item {
            Kirigami.FormData.isSection: true
            visible: !iconOnly
        }

        ComboBox {
            id: taskMaxWidth
            visible: !iconOnly && !plasmoidVertical

            Kirigami.FormData.label: i18nc("@label:listbox", "Maximum task width:")

            model: [i18nc("@item:inlistbox how wide a task item should be", "Narrow"), i18nc("@item:inlistbox how wide a task item should be", "Medium"), i18nc("@item:inlistbox how wide a task item should be", "Wide")]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        RadioButton {
            id: forbidStripes
            Kirigami.FormData.label: plasmoidVertical ? i18nc("@label for radio button group, completes sentence: … when panel is low on space etc.", "Use multi-column view:") : i18nc("@label for radio button group, completes sentence: … when panel is low on space etc.", "Use multi-row view:")
            onToggled: {
                if (checked) {
                    maxStripes.value = 1;
                }
            }
            text: i18nc("@option:radio Never use multi-column view for Task Manager", "Never")
        }

        RadioButton {
            id: allowStripes
            onToggled: {
                if (checked) {
                    maxStripes.value = Math.max(2, maxStripes.value);
                }
            }
            text: i18nc("@option:radio completes sentence: Use multi-column/row view", "When panel is low on space and thick enough")
        }

        RadioButton {
            id: forceStripes
            onToggled: {
                if (checked) {
                    maxStripes.value = Math.max(2, maxStripes.value);
                }
            }
            text: i18nc("@option:radio completes sentence: Use multi-column/row view", "Always when panel is thick enough")
        }

        SpinBox {
            id: maxStripes
            enabled: maxStripes.value > 1
            Kirigami.FormData.label: plasmoidVertical ? i18nc("@label:spinbox maximum number of columns for tasks", "Maximum columns:") : i18nc("@label:spinbox maximum number of rows for tasks", "Maximum rows:")
            from: 1
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ComboBox {
            visible: iconOnly
            Kirigami.FormData.label: i18nc("@label:listbox", "Spacing between icons:")

            model: [
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Small"),
                    "spacing": 0
                },
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Normal"),
                    "spacing": 1
                },
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Large"),
                    "spacing": 3
                },
            ]

            textRole: "label"
            enabled: !Kirigami.Settings.tabletMode

            currentIndex: {
                if (Kirigami.Settings.tabletMode) {
                    return 2; // Large
                }

                switch (cfg_iconSpacing) {
                case 0:
                    return 0; // Small
                case 1:
                    return 1; // Normal
                case 3:
                    return 2; // Large
                }
            }
            onActivated: index => {
                cfg_iconSpacing = model[currentIndex]["spacing"];
            }
        }

        Label {
            visible: Kirigami.Settings.tabletMode
            text: i18nc("@info:usagetip under a set of radio buttons when Touch Mode is on", "Automatically set to Large when in Touch mode")
            font: Kirigami.Theme.smallFont
        }
    }
}
