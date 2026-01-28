import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kquickcontrols as KQControls

import "../code/singletones"

ConfigPage {
    id: cfg_page




    Kirigami.FormLayout {

        ComboBox {
            id: indicatorsEnabled
            Kirigami.FormData.label: Wrappers.i18n("Indicators:")
            model: [Wrappers.i18n("Disabled"), Wrappers.i18n("Enabled")]
            currentIndex: cfg_page.cfg_indicatorsEnabled
            onActivated: (index) => cfg_page.cfg_indicatorsEnabled = index
        }

        CheckBox {
            id: indicatorProgress
            enabled: indicatorsEnabled.currentIndex
            visible: indicatorsEnabled.currentIndex
            text: Wrappers.i18n("Display Progress on Indicator")
            checked: cfg_page.cfg_indicatorProgress
            onToggled: cfg_page.cfg_indicatorProgress = checked
        }

        KQControls.ColorButton {
            enabled: indicatorsEnabled.currentIndex
            visible: indicatorProgress.checked
            id: indicatorProgressColor
            Kirigami.FormData.label: Wrappers.i18n("Progress Color:")
            showAlphaChannel: true
            color: cfg_page.cfg_indicatorProgressColor
            onColorChanged: cfg_page.cfg_indicatorProgressColor = color
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex
            visible: indicatorsEnabled.currentIndex
            id: disableInactiveIndicators
            text: Wrappers.i18n("Disable for Inactive Windows")
            checked: cfg_page.cfg_disableInactiveIndicators
            onToggled: cfg_page.cfg_disableInactiveIndicators = checked
        }

        ComboBox {
            id: groupIconEnabled
            Kirigami.FormData.label: Wrappers.i18n("Group Overlay:")
            model: [Wrappers.i18n("Disabled"), Wrappers.i18n("Enabled")]
            currentIndex: cfg_page.cfg_groupIconEnabled
            onActivated: (index) => cfg_page.cfg_groupIconEnabled = index
        }
        Label {
            text: Wrappers.i18n("Takes effect on next time plasma groups tasks.")
            font: Kirigami.Theme.smallFont
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorsAnimated
            Kirigami.FormData.label: Wrappers.i18n("Animate Indicators:")
            text: Wrappers.i18n("Enabled")
            checked: cfg_page.cfg_indicatorsAnimated
            onToggled: cfg_page.cfg_indicatorsAnimated = checked
        }


        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex && !indicatorOverride.checked
            id: indicatorReverse
            Kirigami.FormData.label: Wrappers.i18n("Indicator Location:")
            text: Wrappers.i18n("Reverse shown side")
            checked: cfg_page.cfg_indicatorReverse
            onToggled: cfg_page.cfg_indicatorReverse = checked
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorOverride
            text: Wrappers.i18n("Override location")
            checked: cfg_page.cfg_indicatorOverride
            onToggled: cfg_page.cfg_indicatorOverride = checked
        }

        ComboBox {
            enabled: indicatorsEnabled.currentIndex
            visible: indicatorOverride.checked
            id: indicatorLocation
            model: [
                Wrappers.i18n("Bottom"),
                Wrappers.i18n("Left"),
                Wrappers.i18n("Right"),
                Wrappers.i18n("Top")
            ]
            currentIndex: cfg_page.cfg_indicatorLocation
            onActivated: (index) => cfg_page.cfg_indicatorLocation = index
        }

        Label {
            text: Wrappers.i18n("Be sure to use this when using as a floating widget")
            font: Kirigami.Theme.smallFont
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorEdgeOffset
            Kirigami.FormData.label: Wrappers.i18n("Indicator Edge Offset (px):")
            from: 0
            to: 999
            value: cfg_page.cfg_indicatorEdgeOffset
            onValueModified: cfg_page.cfg_indicatorEdgeOffset = value
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ComboBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorStyle
            Kirigami.FormData.label: Wrappers.i18n("Indicator Style:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                Wrappers.i18n("Metro"),
                Wrappers.i18n("Ciliora"),
                Wrappers.i18n("Dashes")
                ]
            currentIndex: cfg_page.cfg_indicatorStyle
            onActivated: (index) => cfg_page.cfg_indicatorStyle = index
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorMinLimit
            Kirigami.FormData.label: Wrappers.i18n("Indicator Min Limit:")
            from: 0
            to: 10
            value: cfg_page.cfg_indicatorMinLimit
            onValueModified: cfg_page.cfg_indicatorMinLimit = value
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorMaxLimit
            Kirigami.FormData.label: Wrappers.i18n("Indicator Max Limit:")
            from: 1
            to: 10
            value: cfg_page.cfg_indicatorMaxLimit
            onValueModified: cfg_page.cfg_indicatorMaxLimit = value
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorDesaturate
            Kirigami.FormData.label: Wrappers.i18n("Minimize Options:")
            text: Wrappers.i18n("Desaturate")
            checked: cfg_page.cfg_indicatorDesaturate
            onToggled: cfg_page.cfg_indicatorDesaturate = checked
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorGrow
            text: Wrappers.i18n("Shrink when minimized")
            checked: cfg_page.cfg_indicatorGrow
            onToggled: cfg_page.cfg_indicatorGrow = checked
        }

        SpinBox {
            id: indicatorGrowFactor
            enabled: indicatorsEnabled.currentIndex
            visible: indicatorGrow.checked
            from: 100
            to: 10 * 100
            stepSize: 25
            Kirigami.FormData.label: Wrappers.i18n("Growth/Shrink factor:")
            value: cfg_page.cfg_indicatorGrowFactor
            onValueModified: cfg_page.cfg_indicatorGrowFactor = value

            property int decimals: 2
            property real realValue: value / 100

            validator: DoubleValidator {
                bottom: Math.min(indicatorGrowFactor.from, indicatorGrowFactor.to)
                top:  Math.max(indicatorGrowFactor.from, indicatorGrowFactor.to)
            }

            textFromValue: function(value, locale) {
                return Number(value / 100).toLocaleString(locale, 'f', indicatorGrowFactor.decimals)
            }

            valueFromText: function(text, locale) {
                return Number.fromLocaleString(locale, text) * 100
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorSize
            Kirigami.FormData.label: Wrappers.i18n("Indicator size (px):")
            from: 1
            to: 999
            value: cfg_page.cfg_indicatorSize
            onValueModified: cfg_page.cfg_indicatorSize = value
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorLength
            Kirigami.FormData.label: Wrappers.i18n("Indicator length (px):")
            from: 1
            to: 999
            value: cfg_page.cfg_indicatorLength
            onValueModified: cfg_page.cfg_indicatorLength = value
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorRadius
            Kirigami.FormData.label: Wrappers.i18n("Indicator Radius (%):")
            from: 0
            to: 100
            value: cfg_page.cfg_indicatorRadius
            onValueModified: cfg_page.cfg_indicatorRadius = value
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorShrink
            Kirigami.FormData.label: Wrappers.i18n("Indicator margin (px):")
            from: 0
            to: 999
            value: cfg_page.cfg_indicatorShrink
            onValueModified: cfg_page.cfg_indicatorShrink = value
        }


        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex & !indicatorAccentColor.checked
            id: indicatorDominantColor
            Kirigami.FormData.label: Wrappers.i18n("Indicator Color:")
            text: Wrappers.i18n("Use dominant icon color")
            checked: cfg_page.cfg_indicatorDominantColor
            onToggled: cfg_page.cfg_indicatorDominantColor = checked
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex & !indicatorDominantColor.checked
            id: indicatorAccentColor
            text: Wrappers.i18n("Use plasma accent color")
            checked: cfg_page.cfg_indicatorAccentColor
            onToggled: cfg_page.cfg_indicatorAccentColor = checked
        }

        KQControls.ColorButton {
            enabled: indicatorsEnabled.currentIndex & !indicatorDominantColor.checked & !indicatorAccentColor.checked
            id: indicatorCustomColor
            Kirigami.FormData.label: Wrappers.i18n("Custom Color:")
            showAlphaChannel: true
            color: cfg_page.cfg_indicatorCustomColor
            onColorChanged: cfg_page.cfg_indicatorCustomColor = color
        }

        Item {
            Kirigami.FormData.isSection: true
        }
    }
}
