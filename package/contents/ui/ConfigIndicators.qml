import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kquickcontrols as KQControls

Kirigami.ScrollablePage {
    property alias cfg_indicatorsEnabled: indicatorsEnabled.currentIndex
    property alias cfg_groupIconEnabled: groupIconEnabled.currentIndex
    property alias cfg_indicatorProgress: indicatorProgress.checked
    property alias cfg_indicatorProgressColor: indicatorProgressColor.color
    property alias cfg_disableInactiveIndicators: disableInactiveIndicators.checked
    property alias cfg_indicatorsAnimated: indicatorsAnimated.checked
    property alias cfg_indicatorLocation: indicatorLocation.currentIndex
    property alias cfg_indicatorReverse: indicatorReverse.checked
    property alias cfg_indicatorOverride: indicatorOverride.checked
    property alias cfg_indicatorEdgeOffset: indicatorEdgeOffset.value
    property alias cfg_indicatorStyle: indicatorStyle.currentIndex
    property alias cfg_indicatorMinLimit: indicatorMinLimit.value
    property alias cfg_indicatorMaxLimit: indicatorMaxLimit.value
    property alias cfg_indicatorDesaturate: indicatorDesaturate.checked
    property alias cfg_indicatorGrow: indicatorGrow.checked
    property alias cfg_indicatorGrowFactor: indicatorGrowFactor.value
    property alias cfg_indicatorSize: indicatorSize.value
    property alias cfg_indicatorLength: indicatorLength.value
    property alias cfg_indicatorRadius: indicatorRadius.value
    property alias cfg_indicatorShrink: indicatorShrink.value
    property alias cfg_indicatorDominantColor: indicatorDominantColor.checked
    property alias cfg_indicatorAccentColor:  indicatorAccentColor.checked
    property alias cfg_indicatorCustomColor: indicatorCustomColor.color

    // --- Properties to silence KCM errors ---
    // Defaults for existing aliases
    property var cfg_indicatorsEnabledDefault
    property var cfg_groupIconEnabledDefault
    property var cfg_indicatorProgressDefault
    property var cfg_indicatorProgressColorDefault
    property var cfg_disableInactiveIndicatorsDefault
    property var cfg_indicatorsAnimatedDefault
    property var cfg_indicatorLocationDefault
    property var cfg_indicatorReverseDefault
    property var cfg_indicatorOverrideDefault
    property var cfg_indicatorEdgeOffsetDefault
    property var cfg_indicatorStyleDefault
    property var cfg_indicatorMinLimitDefault
    property var cfg_indicatorMaxLimitDefault
    property var cfg_indicatorDesaturateDefault
    property var cfg_indicatorGrowDefault
    property var cfg_indicatorGrowFactorDefault
    property var cfg_indicatorSizeDefault
    property var cfg_indicatorLengthDefault
    property var cfg_indicatorRadiusDefault
    property var cfg_indicatorShrinkDefault
    property var cfg_indicatorDominantColorDefault
    property var cfg_indicatorAccentColorDefault
    property var cfg_indicatorCustomColorDefault

    // Missing properties from main.xml not used in this tab
    property var cfg_showOnlyCurrentScreen
    property var cfg_showOnlyCurrentScreenDefault
    property var cfg_showOnlyCurrentDesktop
    property var cfg_showOnlyCurrentDesktopDefault
    property var cfg_showOnlyCurrentActivity
    property var cfg_showOnlyCurrentActivityDefault
    property var cfg_showOnlyMinimized
    property var cfg_showOnlyMinimizedDefault
    property var cfg_unhideOnAttention
    property var cfg_unhideOnAttentionDefault
    property var cfg_groupingStrategy
    property var cfg_groupingStrategyDefault
    property var cfg_iconOnly
    property var cfg_iconOnlyDefault
    property var cfg_groupedTaskVisualization
    property var cfg_groupedTaskVisualizationDefault
    property var cfg_groupPopups
    property var cfg_groupPopupsDefault
    property var cfg_onlyGroupWhenFull
    property var cfg_onlyGroupWhenFullDefault
    property var cfg_groupingAppIdBlacklist
    property var cfg_groupingAppIdBlacklistDefault
    property var cfg_groupingLauncherUrlBlacklist
    property var cfg_groupingLauncherUrlBlacklistDefault
    property var cfg_sortingStrategy
    property var cfg_sortingStrategyDefault
    property var cfg_separateLaunchers
    property var cfg_separateLaunchersDefault
    property var cfg_hideLauncherOnStart
    property var cfg_hideLauncherOnStartDefault
    property var cfg_maxStripes
    property var cfg_maxStripesDefault
    property var cfg_maxButtonLength
    property var cfg_maxButtonLengthDefault
    property var cfg_forceStripes
    property var cfg_forceStripesDefault
    property var cfg_showToolTips
    property var cfg_showToolTipsDefault
    property var cfg_taskMaxWidth
    property var cfg_taskMaxWidthDefault
    property var cfg_wheelEnabled
    property var cfg_wheelEnabledDefault
    property var cfg_wheelSkipMinimized
    property var cfg_wheelSkipMinimizedDefault
    property var cfg_highlightWindows
    property var cfg_highlightWindowsDefault
    property var cfg_launchers
    property var cfg_launchersDefault
    property var cfg_middleClickAction
    property var cfg_middleClickActionDefault
    property var cfg_indicateAudioStreams
    property var cfg_indicateAudioStreamsDefault
    property var cfg_iconScale
    property var cfg_iconScaleDefault
    property var cfg_iconSizePx
    property var cfg_iconSizePxDefault
    property var cfg_iconSizeOverride
    property var cfg_iconSizeOverrideDefault
    property var cfg_fill
    property var cfg_fillDefault
    property var cfg_taskHoverEffect
    property var cfg_taskHoverEffectDefault
    property var cfg_maxTextLines
    property var cfg_maxTextLinesDefault
    property var cfg_minimizeActiveTaskOnClick
    property var cfg_minimizeActiveTaskOnClickDefault
    property var cfg_reverseMode
    property var cfg_reverseModeDefault
    property var cfg_iconSpacing
    property var cfg_iconSpacingDefault
    property var cfg_useBorders
    property var cfg_useBordersDefault
    property var cfg_taskSpacingSize
    property var cfg_taskSpacingSizeDefault
    property var cfg_buttonColorize
    property var cfg_buttonColorizeDefault
    property var cfg_buttonColorizeInactive
    property var cfg_buttonColorizeInactiveDefault
    property var cfg_buttonColorizeDominant
    property var cfg_buttonColorizeDominantDefault
    property var cfg_buttonColorizeCustom
    property var cfg_buttonColorizeCustomDefault
    property var cfg_disableButtonSvg
    property var cfg_disableButtonSvgDefault
    property var cfg_disableButtonInactiveSvg
    property var cfg_disableButtonInactiveSvgDefault
    property var cfg_overridePlasmaButtonDirection
    property var cfg_overridePlasmaButtonDirectionDefault
    property var cfg_plasmaButtonDirection
    property var cfg_plasmaButtonDirectionDefault
    property var cfg_iconZoomFactor
    property var cfg_iconZoomFactorDefault
    property var cfg_iconZoomDuration
    property var cfg_iconZoomDurationDefault
    // -----------------------------------------------------------------

    Kirigami.FormLayout {

        ComboBox {
            id: indicatorsEnabled
            Kirigami.FormData.label: i18n("Indicators:")
            model: [i18n("Disabled"), i18n("Enabled")]
        }

        CheckBox {
            id: indicatorProgress
            enabled: indicatorsEnabled.currentIndex
            visible: indicatorsEnabled.currentIndex
            text: i18n("Display Progress on Indicator")
        }

        KQControls.ColorButton {
            enabled: indicatorsEnabled.currentIndex
            visible: indicatorProgress.checked
            id: indicatorProgressColor
            Kirigami.FormData.label: i18n("Progress Color:")
            showAlphaChannel: true
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex
            visible: indicatorsEnabled.currentIndex
            id: disableInactiveIndicators
            text: i18n("Disable for Inactive Windows")
        }

        ComboBox {
            id: groupIconEnabled
            Kirigami.FormData.label: i18n("Group Overlay:")
            model: [i18n("Disabled"), i18n("Enabled")]
        }
        Label {
            text: i18n("Takes effect on next time plasma groups tasks.")
            font: Kirigami.Theme.smallFont
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorsAnimated
            Kirigami.FormData.label: i18n("Animate Indicators:")
            text: i18n("Enabled")
        }


        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex && !indicatorOverride.checked
            id: indicatorReverse
            Kirigami.FormData.label: i18n("Indicator Location:")
            text: i18n("Reverse shown side")
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorOverride
            text: i18n("Override location")
        }

        ComboBox {
            enabled: indicatorsEnabled.currentIndex
            visible: indicatorOverride.checked
            id: indicatorLocation
            model: [
                i18n("Bottom"),
                i18n("Left"),
                i18n("Right"),
                i18n("Top")
            ]
        }

        Label {
            text: i18n("Be sure to use this when using as a floating widget")
            font: Kirigami.Theme.smallFont
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorEdgeOffset
            Kirigami.FormData.label: i18n("Indicator Edge Offset (px):")
            from: 0
            to: 999
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ComboBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorStyle
            Kirigami.FormData.label: i18n("Indicator Style:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: [
                i18n("Metro"),
                i18n("Ciliora"),
                i18n("Dashes")
                ]
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorMinLimit
            Kirigami.FormData.label: i18n("Indicator Min Limit:")
            from: 0
            to: 10
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorMaxLimit
            Kirigami.FormData.label: i18n("Indicator Max Limit:")
            from: 1
            to: 10
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorDesaturate
            Kirigami.FormData.label: i18n("Minimize Options:")
            text: i18n("Desaturate")
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorGrow
            text: i18n("Shrink when minimized")
        }

        SpinBox {
            id: indicatorGrowFactor
            enabled: indicatorsEnabled.currentIndex
            visible: indicatorGrow.checked
            from: 100
            to: 10 * 100
            stepSize: 25
            Kirigami.FormData.label: i18n("Growth/Shrink factor:")

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
            Kirigami.FormData.label: i18n("Indicator size (px):")
            from: 1
            to: 999
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorLength
            Kirigami.FormData.label: i18n("Indicator length (px):")
            from: 1
            to: 999
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorRadius
            Kirigami.FormData.label: i18n("Indicator Radius (%):")
            from: 0
            to: 100
        }

        SpinBox {
            enabled: indicatorsEnabled.currentIndex
            id: indicatorShrink
            Kirigami.FormData.label: i18n("Indicator margin (px):")
            from: 0
            to: 999
        }


        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex & !indicatorAccentColor.checked
            id: indicatorDominantColor
            Kirigami.FormData.label: i18n("Indicator Color:")
            text: i18n("Use dominant icon color")
        }

        CheckBox {
            enabled: indicatorsEnabled.currentIndex & !indicatorDominantColor.checked
            id: indicatorAccentColor
            text: i18n("Use plasma accent color")
        }

        KQControls.ColorButton {
            enabled: indicatorsEnabled.currentIndex & !indicatorDominantColor.checked & !indicatorAccentColor.checked
            id: indicatorCustomColor
            Kirigami.FormData.label: i18n("Custom Color:")
            showAlphaChannel: true
        }

        Item {
            Kirigami.FormData.isSection: true
        }
    }
}
