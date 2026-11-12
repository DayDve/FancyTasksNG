/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kquickcontrols as KQuickAddons

import "../ui/code/singletones"

// Task styling: the icon, the button background, and what happens under
// the cursor.
ConfigPage {
    id: stylePage

    readonly property bool iconsOnly: stylePage.cfg_iconOnly === 1
    // 0 = on all buttons, 1 = only on the active and hovered ones, 2 = none.
    readonly property int backgroundMode: stylePage.cfg_disableButtonSvg ? 2 : (stylePage.cfg_disableButtonInactiveSvg ? 1 : 0)

    function turnOnFirst(option: string): string {
        return Wrappers.i18n("Turn on \"%1\" first.", option);
    }

    ConfigTabbedPage {
        cfg_page: stylePage

        ConfigTab {
            id: iconTab
            title: Wrappers.i18n("Icons")
            iconName: "preferences-desktop-icons"

            Label {
                text: Wrappers.i18n("Icon size:")
            }
            ComboBox {
                Layout.fillWidth: true
                model: [Wrappers.i18n("Relative"), Wrappers.i18n("Absolute")]
                currentIndex: stylePage.cfg_iconSizeOverride ? 1 : 0
                onActivated: (index) => stylePage.cfg_iconSizeOverride = (index === 1)
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !stylePage.cfg_iconSizeOverride
                spacing: stylePage.smallSpacing

                Slider {
                    id: iconScale
                    Layout.fillWidth: true
                    from: 0
                    to: 300
                    stepSize: 1.0
                    value: stylePage.cfg_iconScale
                    onMoved: stylePage.cfg_iconScale = value
                }
                SpinBox {
                    from: 0
                    to: 300
                    editable: true
                    value: Math.round(iconScale.value)
                    onValueModified: stylePage.cfg_iconScale = value
                }
                Label {
                    text: "%"
                }
                Button {
                    icon.name: "edit-reset"
                    flat: true
                    onClicked: stylePage.cfg_iconScale = 100
                    ToolTip.text: Wrappers.i18n("Reset to default")
                    ToolTip.visible: hovered
                    ToolTip.delay: 1000
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: stylePage.cfg_iconSizeOverride
                spacing: stylePage.smallSpacing

                Slider {
                    id: iconSizePx
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    stepSize: 1
                    value: stylePage.cfg_iconSizePx
                    onMoved: stylePage.cfg_iconSizePx = value
                }
                SpinBox {
                    from: 0
                    to: 100
                    editable: true
                    value: iconSizePx.value
                    onValueModified: stylePage.cfg_iconSizePx = value
                }
                Label {
                    text: "px"
                }
                Button {
                    icon.name: "edit-reset"
                    flat: true
                    onClicked: stylePage.cfg_iconSizePx = 32
                    ToolTip.text: Wrappers.i18n("Reset to default")
                    ToolTip.visible: hovered
                    ToolTip.delay: 1000
                }
            }

            CheckBox {
                id: iconScaleFromEdge
                text: Wrappers.i18n("Scale icons from panel edge")
                checked: stylePage.cfg_iconScaleFromEdge
                onToggled: stylePage.cfg_iconScaleFromEdge = checked
            }
            RowLayout {
                spacing: stylePage.smallSpacing
                Item { implicitWidth: stylePage.gridUnit }
                RowLayout {
                    id: iconEdgeOffset
                    enabled: iconScaleFromEdge.checked
                    spacing: stylePage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Edge offset (px):")
                    }
                    SpinBox {
                        from: 0
                        to: 15
                        stepSize: 1
                        value: stylePage.cfg_iconEdgeOffset
                        onValueModified: stylePage.cfg_iconEdgeOffset = value
                    }
                }
                ConfigHint {
                    target: iconEdgeOffset
                    toolTipText: stylePage.turnOnFirst(iconScaleFromEdge.text)
                }
            }

            Item { height: stylePage.largeSpacing }

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
                spacing: stylePage.smallSpacing
                RowLayout {
                    id: iconClipRadius
                    enabled: clipIconToShape.checked
                    spacing: stylePage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Icon corner radius:")
                    }
                    Slider {
                        id: iconClipRadiusSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        stepSize: 1
                        value: stylePage.cfg_iconClipRadius
                        onMoved: stylePage.cfg_iconClipRadius = value
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
                ConfigHint {
                    target: iconClipRadius
                    toolTipText: stylePage.turnOnFirst(clipIconToShape.text)
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
                ConfigHint {
                    target: clipIconBackgroundEnabled
                    toolTipText: stylePage.turnOnFirst(clipIconToShape.text)
                }
            }

            // Why the background options below are greyed out.
            readonly property string clipBackgroundReason: stylePage.turnOnFirst(clipIconToShape.checked ? clipIconBackgroundEnabled.text : clipIconToShape.text)
            readonly property bool clipBackgroundOn: clipIconBackgroundEnabled.enabled && clipIconBackgroundEnabled.checked

            RowLayout {
                Label {
                    id: clipBackgroundColorLabel
                    enabled: iconTab.clipBackgroundOn
                    text: Wrappers.i18n("Background color source:")
                }
                ConfigHint {
                    target: clipBackgroundColorLabel
                    toolTipText: iconTab.clipBackgroundReason
                }
            }
            RowLayout {
                enabled: iconTab.clipBackgroundOn
                spacing: stylePage.smallSpacing
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
                KQuickAddons.ColorButton {
                    visible: stylePage.cfg_clipIconBackgroundColorMode === 0
                    showAlphaChannel: true
                    Layout.maximumHeight: clipIconBackgroundColorMode.height
                    color: stylePage.cfg_clipIconBackgroundColor
                    onColorChanged: {
                        if (!Qt.colorEqual(color, stylePage.cfg_clipIconBackgroundColor))
                            stylePage.cfg_clipIconBackgroundColor = color;
                    }
                }
            }
            RowLayout {
                spacing: stylePage.smallSpacing
                RowLayout {
                    id: clipBackgroundOpacity
                    enabled: iconTab.clipBackgroundOn
                    spacing: stylePage.smallSpacing
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
                ConfigHint {
                    target: clipBackgroundOpacity
                    toolTipText: iconTab.clipBackgroundReason
                }
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
                Layout.minimumWidth: stylePage.gridUnit * 14
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

            Item { height: stylePage.largeSpacing }

            RowLayout {
                Label {
                    id: buttonColorsLabel
                    enabled: stylePage.backgroundMode !== 2
                    text: Wrappers.i18n("Button Colors:")
                }
                ConfigHint {
                    target: buttonColorsLabel
                    toolTipText: Wrappers.i18n("Buttons have no background.")
                }
            }
            RowLayout {
                enabled: stylePage.backgroundMode !== 2
                spacing: stylePage.smallSpacing
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
                KQuickAddons.ColorButton {
                    showAlphaChannel: true
                    visible: stylePage.cfg_buttonColorize && !stylePage.cfg_buttonColorizeDominant
                    Layout.maximumHeight: buttonColorCombo.height
                    color: stylePage.cfg_buttonColorizeCustom
                    onColorChanged: {
                        if (!Qt.colorEqual(color, stylePage.cfg_buttonColorizeCustom))
                            stylePage.cfg_buttonColorizeCustom = color;
                    }
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
                    toolTipText: stylePage.backgroundMode !== 0 ? Wrappers.i18n("Only when all buttons have a background.")
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
                    toolTipText: Wrappers.i18n("Only in the icons-only mode.")
                }
            }

            readonly property bool zoomOn: stylePage.iconsOnly && taskHoverEffect.checked
            readonly property string zoomReason: stylePage.iconsOnly ? stylePage.turnOnFirst(taskHoverEffect.text)
                : Wrappers.i18n("Only in the icons-only mode.")

            RowLayout {
                spacing: stylePage.smallSpacing
                RowLayout {
                    id: hoverStyle
                    enabled: hoverTab.zoomOn
                    spacing: stylePage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Hover style:")
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        Layout.minimumWidth: stylePage.gridUnit * 14
                        model: [Wrappers.i18n("Simple"), Wrappers.i18n("Parabolic")]
                        currentIndex: stylePage.cfg_taskHoverEffectStyle
                        onActivated: (index) => stylePage.cfg_taskHoverEffectStyle = index
                    }
                }
                ConfigHint {
                    target: hoverStyle
                    toolTipText: hoverTab.zoomReason
                }
            }
            RowLayout {
                spacing: stylePage.smallSpacing
                RowLayout {
                    id: iconZoomFactor
                    enabled: hoverTab.zoomOn
                    spacing: stylePage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Icon zoom factor (px):")
                    }
                    SpinBox {
                        from: 0
                        to: 50
                        stepSize: 1
                        value: stylePage.cfg_iconZoomFactor
                        onValueModified: stylePage.cfg_iconZoomFactor = value
                        ToolTip.delay: 1000
                        ToolTip.visible: hovered
                        ToolTip.text: Wrappers.i18n("How much the icon should grow when hovered (in pixels)")
                    }
                }
                ConfigHint {
                    target: iconZoomFactor
                    toolTipText: hoverTab.zoomReason
                }
            }
            RowLayout {
                spacing: stylePage.smallSpacing
                RowLayout {
                    id: iconZoomDuration
                    enabled: hoverTab.zoomOn
                    spacing: stylePage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Zoom animation duration (ms):")
                    }
                    SpinBox {
                        from: 0
                        to: 1000
                        stepSize: 50
                        value: stylePage.cfg_iconZoomDuration
                        onValueModified: stylePage.cfg_iconZoomDuration = value
                        ToolTip.delay: 1000
                        ToolTip.visible: hovered
                        ToolTip.text: Wrappers.i18n("Duration of the zoom animation in milliseconds")
                    }
                }
                ConfigHint {
                    target: iconZoomDuration
                    toolTipText: hoverTab.zoomReason
                }
            }

            Item { height: stylePage.largeSpacing }

            CheckBox {
                text: Wrappers.i18n("Glow following the cursor over task buttons")
                checked: stylePage.cfg_cursorGlow
                onToggled: stylePage.cfg_cursorGlow = checked
            }
        }
    }
}
