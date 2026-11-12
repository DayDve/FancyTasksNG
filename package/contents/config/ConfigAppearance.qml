/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.kquickcontrols as KQuickAddons

import "../ui/code/singletones"

ConfigPage {
    id: appearancePage
    
    // Silence KCM errors for legacy/removed properties
    readonly property bool plasmaPaAvailable: true
    readonly property bool plasmoidVertical: appearancePage.plasmoidFormFactor === PlasmaCore.Types.Vertical
    readonly property bool iconOnly: appearancePage.plasmoidConfiguration.iconOnly

    ConfigFormPage {
        cfg_page: appearancePage

        CheckBox {
        id: useBorders
        text: Wrappers.i18n("Use plasma borders")
        checked: appearancePage.cfg_useBorders
        onToggled: appearancePage.cfg_useBorders = checked
                }
    
                Item { height: appearancePage.largeSpacing }
    
                RowLayout {
        spacing: appearancePage.smallSpacing
        Label {
            text: Wrappers.i18n("Icon size:")
        }
        ComboBox {
            id: iconSizeOverrideCombo
            Layout.fillWidth: true
            model: [Wrappers.i18n("Relative"), Wrappers.i18n("Absolute")]
            currentIndex: appearancePage.cfg_iconSizeOverride ? 1 : 0
            onActivated: (index) => appearancePage.cfg_iconSizeOverride = (index === 1)
        }
                }
    
                RowLayout {
        Layout.fillWidth: true
        visible: !appearancePage.cfg_iconSizeOverride
        spacing: appearancePage.smallSpacing
    
        Slider {
            id: iconScale
            Layout.fillWidth: true
            from: 0
            to: 300
            stepSize: 1.0
            value: appearancePage.cfg_iconScale
            onMoved: appearancePage.cfg_iconScale = value
        }
    
        SpinBox {
            id: iconScaleSpin
            from: 0
            to: 300
            editable: true
            value: Math.round(iconScale.value)
            onValueModified: appearancePage.cfg_iconScale = value
        }
    
        Label {
            text: "%"
        }
    
        Button {
            icon.name: "edit-reset"
            flat: true
            onClicked: appearancePage.cfg_iconScale = 100
            ToolTip.text: Wrappers.i18n("Reset to default")
            ToolTip.visible: hovered
            ToolTip.delay: 1000
        }
                }
    
                RowLayout {
        Layout.fillWidth: true
        visible: appearancePage.cfg_iconSizeOverride
        spacing: appearancePage.smallSpacing
    
        Slider {
            id: iconSizePx
            Layout.fillWidth: true
            from: 0
            to: 100
            stepSize: 1
            value: appearancePage.cfg_iconSizePx
            onMoved: appearancePage.cfg_iconSizePx = value
        }
    
        SpinBox {
            id: iconSizePxSpin
            from: 0
            to: 100
            editable: true
            value: iconSizePx.value
            onValueModified: appearancePage.cfg_iconSizePx = value
        }
    
        Label {
            text: "px"
        }
    
        Button {
            icon.name: "edit-reset"
            flat: true
            onClicked: appearancePage.cfg_iconSizePx = 32
            ToolTip.text: Wrappers.i18n("Reset to default")
            ToolTip.visible: hovered
            ToolTip.delay: 1000
        }
                }
    
                CheckBox {
        id: iconScaleFromEdge
        text: Wrappers.i18n("Scale icons from panel edge")
        checked: appearancePage.cfg_iconScaleFromEdge
        onToggled: appearancePage.cfg_iconScaleFromEdge = checked
                }
    
                RowLayout {
        visible: iconScaleFromEdge.checked
        spacing: appearancePage.smallSpacing
        Label {
            text: Wrappers.i18n("Edge offset (px):")
        }
        SpinBox {
            id: iconEdgeOffset
            from: 0
            to: 15
            stepSize: 1
            value: appearancePage.cfg_iconEdgeOffset
            onValueModified: appearancePage.cfg_iconEdgeOffset = value
        }
                }
    
                Item { 
        height: appearancePage.largeSpacing 
        visible: appearancePage.cfg_iconOnly === 1
                }
    
                CheckBox {
        id: cfg_taskHoverEffect
        text: Wrappers.i18n("Icon hover effects")
        visible: appearancePage.cfg_iconOnly === 1
        checked: appearancePage.cfg_taskHoverEffect
        onToggled: appearancePage.cfg_taskHoverEffect = checked
                }
    
                RowLayout {
        visible: appearancePage.cfg_iconOnly === 1 && cfg_taskHoverEffect.checked
        spacing: appearancePage.smallSpacing
        Label {
            text: Wrappers.i18n("Hover style:")
        }
        ComboBox {
            id: cfg_taskHoverEffectStyle
            Layout.fillWidth: true
            Layout.minimumWidth: appearancePage.gridUnit * 14
            model: [
                Wrappers.i18n("Simple"),
                Wrappers.i18n("Parabolic")
            ]
            currentIndex: appearancePage.cfg_taskHoverEffectStyle
            onActivated: (index) => appearancePage.cfg_taskHoverEffectStyle = index
        }
                }
    
                RowLayout {
        visible: appearancePage.cfg_iconOnly === 1 && cfg_taskHoverEffect.checked
        spacing: appearancePage.smallSpacing
        Label {
            text: Wrappers.i18n("Icon zoom factor (px):")
        }
        SpinBox {
            id: iconZoomFactor
            from: 0
            to: 50
            stepSize: 1
            value: appearancePage.cfg_iconZoomFactor
            onValueModified: appearancePage.cfg_iconZoomFactor = value
    
            ToolTip.delay: 1000
            ToolTip.visible: hovered
            ToolTip.text: Wrappers.i18n("How much the icon should grow when hovered (in pixels)")
        }
                }
    
                RowLayout {
        visible: appearancePage.cfg_iconOnly === 1 && cfg_taskHoverEffect.checked
        spacing: appearancePage.smallSpacing
        Label {
            text: Wrappers.i18n("Zoom animation duration (ms):")
        }
        SpinBox {
            id: iconZoomDuration
            from: 0
            to: 1000
            stepSize: 50
            value: appearancePage.cfg_iconZoomDuration
            onValueModified: appearancePage.cfg_iconZoomDuration = value
    
            ToolTip.delay: 1000
            ToolTip.visible: hovered
            ToolTip.text: Wrappers.i18n("Duration of the zoom animation in milliseconds")
        }
                }
    
                Item { height: appearancePage.largeSpacing }
    
                CheckBox {
        id: cfg_disableButtonSvg
        text: Wrappers.i18n("Disable plasma context decorations")
        checked: appearancePage.cfg_disableButtonSvg
        onToggled: appearancePage.cfg_disableButtonSvg = checked
                }
    
                Item { height: appearancePage.largeSpacing }
    
                Label {
        text: Wrappers.i18n("Button Colors:")
        enabled: !cfg_disableButtonSvg.checked
                }
    
                RowLayout {
        spacing: appearancePage.smallSpacing
        Layout.fillWidth: true
        
        ComboBox {
            id: buttonColorCombo
            Layout.fillWidth: true
            enabled: !cfg_disableButtonSvg.checked
            model: [
                Wrappers.i18n("Using Plasma Style/Accent"),
                Wrappers.i18n("Use dominant icon color"),
                Wrappers.i18n("Custom color")
            ]
            currentIndex: {
                if (!appearancePage.cfg_buttonColorize) return 0;
                if (appearancePage.cfg_buttonColorizeDominant) return 1;
                return 2;
            }
            onActivated: index => {
                if (index === 0) {
                    appearancePage.cfg_buttonColorize = false;
                    appearancePage.cfg_buttonColorizeDominant = false;
                } else if (index === 1) {
                    appearancePage.cfg_buttonColorize = true;
                    appearancePage.cfg_buttonColorizeDominant = true;
                } else if (index === 2) {
                    appearancePage.cfg_buttonColorize = true;
                    appearancePage.cfg_buttonColorizeDominant = false;
                }
            }
        }
    
        KQuickAddons.ColorButton {
            id: cfg_buttonColorizeCustom
            showAlphaChannel: true
            enabled: !cfg_disableButtonSvg.checked
            visible: appearancePage.cfg_buttonColorize && !appearancePage.cfg_buttonColorizeDominant
            Layout.maximumHeight: buttonColorCombo.height
            color: appearancePage.cfg_buttonColorizeCustom
            onColorChanged: {
                if (!Qt.colorEqual(color, appearancePage.cfg_buttonColorizeCustom)) {
                    appearancePage.cfg_buttonColorizeCustom = color
                }
            }
        }
                }
    
                Item { height: appearancePage.largeSpacing }
    
                Label {
        text: Wrappers.i18n("For inactive buttons:")
        enabled: !cfg_disableButtonSvg.checked
                }
    
                CheckBox {
        id: cfg_disableButtonInactiveSvg
        text: Wrappers.i18n("Hide backgrounds for inactive buttons")
        enabled: !cfg_disableButtonSvg.checked
        checked: appearancePage.cfg_disableButtonInactiveSvg
        onToggled: appearancePage.cfg_disableButtonInactiveSvg = checked
                }
    
                CheckBox {
        id: cfg_buttonColorizeInactive
        text: Wrappers.i18n("Colorize inactive buttons")
        enabled: !cfg_disableButtonSvg.checked && appearancePage.cfg_buttonColorize && !cfg_disableButtonInactiveSvg.checked
        checked: appearancePage.cfg_buttonColorizeInactive
        onToggled: appearancePage.cfg_buttonColorizeInactive = checked
                }
    
                Item { height: appearancePage.largeSpacing }
    
                Label {
        text: Wrappers.i18n("Icon Shape:")
                }
    
                CheckBox {
        id: clipIconToShape
        text: Wrappers.i18n("Clip icons to a custom shape")
        checked: appearancePage.cfg_clipIconToShape
        onToggled: appearancePage.cfg_clipIconToShape = checked
                }
    
                RowLayout {
        visible: appearancePage.cfg_clipIconToShape
        spacing: appearancePage.smallSpacing
        Label {
            text: Wrappers.i18n("Icon corner radius:")
        }
        Slider {
            id: iconClipRadiusSlider
            Layout.fillWidth: true
            from: 0
            to: 100
            stepSize: 1
            value: appearancePage.cfg_iconClipRadius
            onMoved: appearancePage.cfg_iconClipRadius = value
        }
        SpinBox {
            id: iconClipRadiusSpin
            from: 0
            to: 100
            editable: true
            value: iconClipRadiusSlider.value
            onValueModified: appearancePage.cfg_iconClipRadius = value
            textFromValue: function(value, locale) { return value + "%" }
            valueFromText: function(text, locale) { return parseInt(text) }
        }
                }
    
                CheckBox {
        id: clipIconBackgroundEnabled
        visible: appearancePage.cfg_clipIconToShape
        text: Wrappers.i18n("Show background under clipped icons")
        checked: appearancePage.cfg_clipIconBackgroundEnabled
        onToggled: appearancePage.cfg_clipIconBackgroundEnabled = checked
                }
    
                Label {
        visible: appearancePage.cfg_clipIconToShape && appearancePage.cfg_clipIconBackgroundEnabled
        text: Wrappers.i18n("Background color source:")
                }
    
                RowLayout {
        visible: appearancePage.cfg_clipIconToShape && appearancePage.cfg_clipIconBackgroundEnabled
        spacing: appearancePage.smallSpacing
        Layout.fillWidth: true
        ComboBox {
            id: cfg_clipIconBackgroundColorMode
            Layout.fillWidth: true
            model: [
                Wrappers.i18n("Custom color"),
                Wrappers.i18n("Dominant icon color"),
                Wrappers.i18n("Average icon color"),
                Wrappers.i18n("Plasma accent color")
            ]
            currentIndex: appearancePage.cfg_clipIconBackgroundColorMode
            onActivated: (index) => appearancePage.cfg_clipIconBackgroundColorMode = index
        }
    
        KQuickAddons.ColorButton {
            id: clipIconBackgroundColorBtn
            visible: appearancePage.cfg_clipIconBackgroundColorMode === 0
            showAlphaChannel: true
            Layout.maximumHeight: cfg_clipIconBackgroundColorMode.height
            color: appearancePage.cfg_clipIconBackgroundColor
            onColorChanged: {
                if (!Qt.colorEqual(color, appearancePage.cfg_clipIconBackgroundColor)) {
                    appearancePage.cfg_clipIconBackgroundColor = color
                }
            }
        }
                }
    
                RowLayout {
        visible: appearancePage.cfg_clipIconToShape && appearancePage.cfg_clipIconBackgroundEnabled
        spacing: appearancePage.smallSpacing
        Label {
            text: Wrappers.i18n("Background opacity:")
        }
        Slider {
            id: clipIconBackgroundOpacitySlider
            Layout.fillWidth: true
            from: 0
            to: 100
            stepSize: 5
            value: appearancePage.cfg_clipIconBackgroundOpacity
            onMoved: appearancePage.cfg_clipIconBackgroundOpacity = value
        }
        SpinBox {
            id: clipIconBackgroundOpacitySpin
            from: 0
            to: 100
            editable: true
            value: clipIconBackgroundOpacitySlider.value
            onValueModified: appearancePage.cfg_clipIconBackgroundOpacity = value
            textFromValue: function(value, locale) { return value + "%" }
            valueFromText: function(text, locale) { return parseInt(text) }
        }
                }
    }
}
