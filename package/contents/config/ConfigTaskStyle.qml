/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import QtQuick.Layouts

import "../ui/code/singletones"

// Task styling: how the icon and the button look, and what happens under
// the cursor. Where the icon sits and how big it is is under Task Layout.
ConfigPage {
    id: stylePage
    fullTitle: Wrappers.i18n("Task Styling")

    readonly property bool iconsOnly: stylePage.cfg_iconOnly === 1
    // 0 = on all buttons, 1 = only on the active and hovered ones, 2 = none.
    readonly property int backgroundMode: stylePage.cfg_disableButtonSvg ? 2 : (stylePage.cfg_disableButtonInactiveSvg ? 1 : 0)


    ConfigTabbedPage {
        cfg_page: stylePage

        ConfigTab {
            id: iconTab
            title: Wrappers.i18n("Icons")
            iconName: "preferences-desktop-icons"

            Label {
                text: Wrappers.i18n("Icon Shape:")
            }
            CheckBox {
                id: clipIconToShape
                text: Wrappers.i18n("Clip icons to a custom shape")
                checked: stylePage.cfg_clipIconToShape
                onToggled: stylePage.cfg_clipIconToShape = checked
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    id: iconClipRadius
                    enabled: clipIconToShape.checked
                    spacing: Kirigami.Units.smallSpacing
                    Label {
                        text: Wrappers.i18n("Icon corner radius:")
                    }
                    Slider {
                        id: iconClipRadiusSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        // No stepSize: with it the style draws a tick per step.
                        value: stylePage.cfg_iconClipRadius
                        onMoved: stylePage.cfg_iconClipRadius = Math.round(value)
                    }
                    SpinBox {
                        from: 0
                        to: 100
                        editable: true
                        value: iconClipRadiusSlider.value
                        onValueModified: stylePage.cfg_iconClipRadius = value
                        textFromValue: (value, locale) => value + "%"
                        valueFromText: (text, locale) => parseInt(text)
                    }
                }
            }
            RowLayout {
                CheckBox {
                    id: clipIconBackgroundEnabled
                    enabled: clipIconToShape.checked
                    text: Wrappers.i18n("Show background under clipped icons")
                    checked: stylePage.cfg_clipIconBackgroundEnabled
                    onToggled: stylePage.cfg_clipIconBackgroundEnabled = checked
                }
            }

            // Why the background options below are greyed out.
            readonly property bool clipBackgroundOn: clipIconBackgroundEnabled.enabled && clipIconBackgroundEnabled.checked

            RowLayout {
                Label {
                    id: clipBackgroundColorLabel
                    enabled: iconTab.clipBackgroundOn
                    text: Wrappers.i18n("Background color source:")
                }
            }
            RowLayout {
                enabled: iconTab.clipBackgroundOn
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                ComboBox {
                    id: clipIconBackgroundColorMode
                    Layout.fillWidth: true
                    model: [
                        Wrappers.i18n("Custom color"),
                        Wrappers.i18n("Dominant icon color"),
                        Wrappers.i18n("Average icon color"),
                        Wrappers.i18n("Plasma accent color")
                    ]
                    currentIndex: stylePage.cfg_clipIconBackgroundColorMode
                    onActivated: (index) => stylePage.cfg_clipIconBackgroundColorMode = index
                }
                ConfigColorButton {
                    enabled: stylePage.cfg_clipIconBackgroundColorMode === 0
                    Layout.maximumHeight: clipIconBackgroundColorMode.height
                    value: stylePage.cfg_clipIconBackgroundColor
                    onEdited: (picked) => stylePage.cfg_clipIconBackgroundColor = picked
                }
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    id: clipBackgroundOpacity
                    enabled: iconTab.clipBackgroundOn
                    spacing: Kirigami.Units.smallSpacing
                    Label {
                        text: Wrappers.i18n("Background opacity:")
                    }
                    Slider {
                        id: clipIconBackgroundOpacitySlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        stepSize: 5
                        value: stylePage.cfg_clipIconBackgroundOpacity
                        onMoved: stylePage.cfg_clipIconBackgroundOpacity = value
                    }
                    SpinBox {
                        from: 0
                        to: 100
                        editable: true
                        value: clipIconBackgroundOpacitySlider.value
                        onValueModified: stylePage.cfg_clipIconBackgroundOpacity = value
                        textFromValue: (value, locale) => value + "%"
                        valueFromText: (text, locale) => parseInt(text)
                    }
                }
            }
        }

        // Every icon drawn in one style (IconStylizer), so that the panel
        // looks as one set without another icon theme.
        ConfigTab {
            id: stylizationTab
            title: Wrappers.i18n("Stylization")
            iconName: "draw-brush"

            readonly property var stylizations: [0, 1, 2, 3]
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Style:")
                }
                ComboBox {
                    model: [
                        Wrappers.i18nc("No icon stylization", "None"),
                        Wrappers.i18nc("Icon stylization", "Outline"),
                        Wrappers.i18nc("Icon stylization", "Lines"),
                        Wrappers.i18nc("Icon stylization", "Monochrome")
                    ]
                    currentIndex: Math.max(0, stylizationTab.stylizations.indexOf(stylePage.cfg_iconStylization))
                    onActivated: (index) => stylePage.cfg_iconStylization = stylizationTab.stylizations[index]
                }
            }
            RowLayout {
                visible: stylePage.cfg_iconStylization === 1
                spacing: Kirigami.Units.smallSpacing
                Item { implicitWidth: Kirigami.Units.gridUnit }
                Label {
                    text: Wrappers.i18n("Sensitivity:")
                }
                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    // No stepSize: with it the style draws a tick per step.
                    value: stylePage.cfg_iconOutlineSensitivity
                    onMoved: stylePage.cfg_iconOutlineSensitivity = Math.round(value)
                }
                Button {
                    icon.name: "edit-reset"
                    flat: true
                    enabled: stylePage.cfg_iconOutlineSensitivity !== stylePage.cfg_iconOutlineSensitivityDefault
                    onClicked: stylePage.cfg_iconOutlineSensitivity = stylePage.cfg_iconOutlineSensitivityDefault
                    ToolTip.text: Wrappers.i18n("Reset to default")
                    ToolTip.visible: hovered
                    ToolTip.delay: 1000
                }
            }
            RowLayout {
                visible: stylePage.cfg_iconStylization === 2
                spacing: Kirigami.Units.smallSpacing
                Item { implicitWidth: Kirigami.Units.gridUnit }
                Label {
                    text: Wrappers.i18nc("Line thickness", "Thickness:")
                }
                Slider {
                    Layout.fillWidth: true
                    from: 30
                    to: 80
                    // No stepSize: with it the style draws a tick per step.
                    value: stylePage.cfg_iconLinesThickness
                    onMoved: stylePage.cfg_iconLinesThickness = Math.round(value)
                }
                Button {
                    icon.name: "edit-reset"
                    flat: true
                    enabled: stylePage.cfg_iconLinesThickness !== stylePage.cfg_iconLinesThicknessDefault
                    onClicked: stylePage.cfg_iconLinesThickness = stylePage.cfg_iconLinesThicknessDefault
                    ToolTip.text: Wrappers.i18n("Reset to default")
                    ToolTip.visible: hovered
                    ToolTip.delay: 1000
                }
            }
            RowLayout {
                visible: stylePage.cfg_iconStylization === 3
                spacing: Kirigami.Units.smallSpacing
                Item { implicitWidth: Kirigami.Units.gridUnit }
                Label {
                    text: Wrappers.i18n("Contrast:")
                }
                Slider {
                    Layout.fillWidth: true
                    from: 50
                    to: 200
                    // No stepSize: with it the style draws a tick per step.
                    value: stylePage.cfg_iconMonochromeContrast
                    onMoved: stylePage.cfg_iconMonochromeContrast = Math.round(value)
                }
                Button {
                    icon.name: "edit-reset"
                    flat: true
                    enabled: stylePage.cfg_iconMonochromeContrast !== stylePage.cfg_iconMonochromeContrastDefault
                    onClicked: stylePage.cfg_iconMonochromeContrast = stylePage.cfg_iconMonochromeContrastDefault
                    ToolTip.text: Wrappers.i18n("Reset to default")
                    ToolTip.visible: hovered
                    ToolTip.delay: 1000
                }
            }
            RowLayout {
                enabled: stylePage.cfg_iconStylization > 0
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Colorization:")
                }
                ComboBox {
                    id: iconColorization
                    model: [
                        Wrappers.i18n("Theme text color"),
                        Wrappers.i18n("Plasma accent color"),
                        Wrappers.i18n("Custom color"),
                        Wrappers.i18n("Dominant icon color"),
                        Wrappers.i18n("Average icon color")
                    ]
                    currentIndex: stylePage.cfg_iconColorization
                    onActivated: (index) => stylePage.cfg_iconColorization = index
                }
                ConfigColorButton {
                    enabled: stylePage.cfg_iconColorization === 2
                    Layout.maximumHeight: iconColorization.height
                    value: stylePage.cfg_iconColorizationColor
                    onEdited: (picked) => stylePage.cfg_iconColorizationColor = picked
                }
            }
            RowLayout {
                enabled: stylePage.cfg_iconStylization > 0
                spacing: Kirigami.Units.smallSpacing
                Label {
                    text: Wrappers.i18n("Hover highlight:")
                }
                ComboBox {
                    id: iconHoverHighlight
                    model: [
                        Wrappers.i18nc("No hover highlight", "None"),
                        Wrappers.i18n("Original icon colors"),
                        Wrappers.i18n("Plasma accent color"),
                        Wrappers.i18n("Custom color"),
                        Wrappers.i18n("Dominant icon color"),
                        Wrappers.i18n("Average icon color")
                    ]
                    currentIndex: stylePage.cfg_iconHoverHighlight
                    onActivated: (index) => stylePage.cfg_iconHoverHighlight = index
                }
                ConfigColorButton {
                    enabled: stylePage.cfg_iconHoverHighlight === 3
                    Layout.maximumHeight: iconHoverHighlight.height
                    value: stylePage.cfg_iconHoverHighlightColor
                    onEdited: (picked) => stylePage.cfg_iconHoverHighlightColor = picked
                }
            }
            // Outline and Lines color the active task's drawing with the
            // icon's average color: nothing to do when every icon already
            // has its own color.
            readonly property bool ownColors: (stylePage.cfg_iconStylization === 1 || stylePage.cfg_iconStylization === 2)
                && stylePage.cfg_iconColorization >= 3
            RowLayout {
                CheckBox {
                    id: activeInColor
                    enabled: stylePage.cfg_iconStylization > 0 && !stylizationTab.ownColors
                    text: Wrappers.i18n("Active task in color")
                    checked: stylePage.cfg_iconActiveInColor
                    onToggled: stylePage.cfg_iconActiveInColor = checked
                }
                ConfigHint {
                    target: activeInColor
                    reason: stylizationTab.ownColors ? Wrappers.i18n("Icons are already in their own colors.") : ""
                }
            }
        }

        // A custom icon per app, on this widget only.
        ConfigTab {
            title: Wrappers.i18n("Icon Replacements")
            iconName: "document-replace"
            framed: false
            // Otherwise the form takes itself for narrow, squeezes its grid
            // to 32 grid units in the middle and the panels stick out on
            // the right.
            wideMode: true

            IconReplacementList {
                page: stylePage
                Layout.fillWidth: true
                // Across the whole form, not in its field column.
                Kirigami.FormData.isSection: true
            }
        }

        ConfigTab {
            title: Wrappers.i18n("Background")
            iconName: "fill-color"

            Label {
                text: Wrappers.i18n("Button background:")
            }
            ComboBox {
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                model: [
                    Wrappers.i18n("On all buttons"),
                    Wrappers.i18n("Only on the active and hovered buttons"),
                    Wrappers.i18n("None")
                ]
                currentIndex: stylePage.backgroundMode
                onActivated: (index) => {
                    stylePage.cfg_disableButtonSvg = index === 2;
                    stylePage.cfg_disableButtonInactiveSvg = index === 1;
                }
            }

            Item { height: Kirigami.Units.largeSpacing }

            RowLayout {
                Label {
                    id: buttonColorsLabel
                    enabled: stylePage.backgroundMode !== 2
                    text: Wrappers.i18n("Button Colors:")
                }
                ConfigHint {
                    target: buttonColorsLabel
                    reason: Wrappers.i18n("Buttons have no background.")
                }
            }
            RowLayout {
                enabled: stylePage.backgroundMode !== 2
                spacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                ComboBox {
                    id: buttonColorCombo
                    Layout.fillWidth: true
                    model: [
                        Wrappers.i18n("Using Plasma Style/Accent"),
                        Wrappers.i18n("Use dominant icon color"),
                        Wrappers.i18n("Custom color")
                    ]
                    currentIndex: {
                        if (!stylePage.cfg_buttonColorize)
                            return 0;
                        return stylePage.cfg_buttonColorizeDominant ? 1 : 2;
                    }
                    onActivated: (index) => {
                        stylePage.cfg_buttonColorize = index !== 0;
                        stylePage.cfg_buttonColorizeDominant = index === 1;
                    }
                }
                ConfigColorButton {
                    enabled: stylePage.cfg_buttonColorize && !stylePage.cfg_buttonColorizeDominant
                    Layout.maximumHeight: buttonColorCombo.height
                    value: stylePage.cfg_buttonColorizeCustom
                    onEdited: (picked) => stylePage.cfg_buttonColorizeCustom = picked
                }
            }
            RowLayout {
                CheckBox {
                    id: buttonColorizeInactive
                    enabled: stylePage.backgroundMode === 0 && stylePage.cfg_buttonColorize
                    text: Wrappers.i18n("Colorize inactive buttons")
                    checked: stylePage.cfg_buttonColorizeInactive
                    onToggled: stylePage.cfg_buttonColorizeInactive = checked
                }
                ConfigHint {
                    target: buttonColorizeInactive
                    reason: stylePage.backgroundMode !== 0 ? Wrappers.i18n("Only when all buttons have a background.")
                        : Wrappers.i18n("Choose a button color other than the Plasma style first.")
                }
            }
        }

        ConfigTab {
            id: hoverTab
            title: Wrappers.i18n("Hover")
            iconName: "followmouse"

            // A classic panel ignores it (see Task.qml).
            RowLayout {
                CheckBox {
                    id: taskHoverEffect
                    enabled: stylePage.iconsOnly
                    text: Wrappers.i18n("Icon hover effects")
                    checked: stylePage.cfg_taskHoverEffect
                    onToggled: stylePage.cfg_taskHoverEffect = checked
                }
                ConfigHint {
                    target: taskHoverEffect
                    reason: Wrappers.i18n("Only in the icons-only mode.")
                }
            }

            readonly property bool zoomOn: stylePage.iconsOnly && taskHoverEffect.checked
            readonly property string zoomReason: stylePage.iconsOnly ? ""
                : Wrappers.i18n("Only in the icons-only mode.")

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    id: hoverStyle
                    enabled: hoverTab.zoomOn
                    spacing: Kirigami.Units.smallSpacing
                    Label {
                        text: Wrappers.i18n("Hover style:")
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
                        model: [Wrappers.i18n("Simple"), Wrappers.i18n("Parabolic")]
                        currentIndex: stylePage.cfg_taskHoverEffectStyle
                        onActivated: (index) => stylePage.cfg_taskHoverEffectStyle = index
                    }
                }
                ConfigHint {
                    target: hoverStyle
                    reason: hoverTab.zoomReason
                }
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    id: iconZoomFactor
                    enabled: hoverTab.zoomOn
                    spacing: Kirigami.Units.smallSpacing
                    Label {
                        text: Wrappers.i18n("Icon zoom factor (px):")
                    }
                    SpinBox {
                        from: 0
                        to: 50
                        stepSize: 1
                        value: stylePage.cfg_iconZoomFactor
                        onValueModified: stylePage.cfg_iconZoomFactor = value
                    }
                }
                ConfigHint {
                    target: iconZoomFactor
                    reason: hoverTab.zoomReason
                }
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    id: iconZoomDuration
                    enabled: hoverTab.zoomOn
                    spacing: Kirigami.Units.smallSpacing
                    Label {
                        text: Wrappers.i18n("Zoom animation duration (ms):")
                    }
                    SpinBox {
                        from: 0
                        to: 1000
                        stepSize: 50
                        value: stylePage.cfg_iconZoomDuration
                        onValueModified: stylePage.cfg_iconZoomDuration = value
                    }
                }
                ConfigHint {
                    target: iconZoomDuration
                    reason: hoverTab.zoomReason
                }
            }

            Item { height: Kirigami.Units.largeSpacing }

            RowLayout {
                CheckBox {
                    id: cursorGlow
                    enabled: stylePage.iconsOnly
                    text: Wrappers.i18n("Glow following the cursor over task buttons")
                    checked: stylePage.cfg_cursorGlow
                    onToggled: stylePage.cfg_cursorGlow = checked
                }
                ConfigHint {
                    target: cursorGlow
                    reason: Wrappers.i18n("Only in the icons-only mode.")
                }
            }

            RowLayout {
                CheckBox {
                    text: Wrappers.i18n("Click feedback")
                    checked: stylePage.cfg_clickFeedback
                    onToggled: stylePage.cfg_clickFeedback = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("On a click, the icon shrinks a little; on a classic panel, the button darkens.")
                }
            }
        }
    }
}
