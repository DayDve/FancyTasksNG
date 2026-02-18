/*
    SPDX-FileCopyrightText: 2024 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    // --- Properties to silence KCM errors ---
    // Defaults for existing aliases
    // --- General ---
    property bool cfg_showOnlyCurrentScreen
    property bool cfg_showOnlyCurrentScreenDefault
    property bool cfg_showOnlyCurrentDesktop
    property bool cfg_showOnlyCurrentDesktopDefault
    property bool cfg_showOnlyCurrentActivity
    property bool cfg_showOnlyCurrentActivityDefault
    property bool cfg_showOnlyMinimized
    property bool cfg_showOnlyMinimizedDefault
    property bool cfg_unhideOnAttention
    property bool cfg_unhideOnAttentionDefault
    property int cfg_maxStripes
    property int cfg_maxStripesDefault
    property int cfg_maxButtonLength
    property int cfg_maxButtonLengthDefault
    property bool cfg_forceStripes
    property bool cfg_forceStripesDefault
    property bool cfg_showToolTips
    property bool cfg_showToolTipsDefault
    property int cfg_taskMaxWidth
    property int cfg_taskMaxWidthDefault
    property bool cfg_wheelEnabled
    property bool cfg_wheelEnabledDefault
    property bool cfg_wheelSkipMinimized
    property bool cfg_wheelSkipMinimizedDefault
    property bool cfg_highlightWindows
    property bool cfg_highlightWindowsDefault
    property bool cfg_indicateAudioStreams
    property bool cfg_indicateAudioStreamsDefault
    property int cfg_iconScale
    property int cfg_iconScaleDefault
    property int cfg_iconSizePx
    property int cfg_iconSizePxDefault
    property bool cfg_iconSizeOverride
    property bool cfg_iconSizeOverrideDefault
    property bool cfg_fill
    property bool cfg_fillDefault
    property bool cfg_taskHoverEffect
    property bool cfg_taskHoverEffectDefault
    property int cfg_maxTextLines
    property int cfg_maxTextLinesDefault
    property bool cfg_minimizeActiveTaskOnClick
    property bool cfg_minimizeActiveTaskOnClickDefault
    property bool cfg_reverseMode
    property bool cfg_reverseModeDefault
    property int cfg_iconSpacing
    property int cfg_iconSpacingDefault
    property bool cfg_useBorders
    property bool cfg_useBordersDefault
    property int cfg_taskSpacingSize
    property int cfg_taskSpacingSizeDefault
    property bool cfg_overridePlasmaButtonDirection
    property bool cfg_overridePlasmaButtonDirectionDefault
    property int cfg_plasmaButtonDirection
    property int cfg_plasmaButtonDirectionDefault
    property int cfg_iconZoomFactor
    property int cfg_iconZoomFactorDefault
    property int cfg_iconZoomDuration
    property int cfg_iconZoomDurationDefault

    // --- Appearance / Behavior ---
    property int cfg_groupingStrategy
    property int cfg_groupingStrategyDefault
    property int cfg_iconOnly
    property int cfg_iconOnlyDefault
    property int cfg_groupedTaskVisualization
    property int cfg_groupedTaskVisualizationDefault
    property bool cfg_groupPopups
    property bool cfg_groupPopupsDefault
    property bool cfg_onlyGroupWhenFull
    property bool cfg_onlyGroupWhenFullDefault
    property int cfg_sortingStrategy
    property int cfg_sortingStrategyDefault
    property bool cfg_separateLaunchers
    property bool cfg_separateLaunchersDefault
    property bool cfg_hideLauncherOnStart
    property bool cfg_hideLauncherOnStartDefault
    property var cfg_groupingAppIdBlacklist
    property var cfg_groupingAppIdBlacklistDefault
    property var cfg_groupingLauncherUrlBlacklist
    property var cfg_groupingLauncherUrlBlacklistDefault
    property var cfg_launchers
    property var cfg_launchersDefault
    property int cfg_middleClickAction
    property int cfg_middleClickActionDefault

    // --- Task Button Appearance ---
    property bool cfg_buttonColorize
    property bool cfg_buttonColorizeDefault
    property bool cfg_buttonColorizeInactive
    property bool cfg_buttonColorizeInactiveDefault
    property bool cfg_buttonColorizeDominant
    property bool cfg_buttonColorizeDominantDefault
    property string cfg_buttonColorizeCustom
    property string cfg_buttonColorizeCustomDefault
    property bool cfg_disableButtonSvg
    property bool cfg_disableButtonSvgDefault
    property bool cfg_disableButtonInactiveSvg
    property bool cfg_disableButtonInactiveSvgDefault

    // --- Indicators ---
    property int cfg_indicatorsEnabled
    property int cfg_indicatorsEnabledDefault
    property bool cfg_indicatorProgress
    property bool cfg_indicatorProgressDefault
    property string cfg_indicatorProgressColor
    property string cfg_indicatorProgressColorDefault
    property bool cfg_disableInactiveIndicators
    property bool cfg_disableInactiveIndicatorsDefault
    property bool cfg_indicatorsAnimated
    property bool cfg_indicatorsAnimatedDefault
    property int cfg_groupIconEnabled
    property int cfg_groupIconEnabledDefault
    property int cfg_indicatorLocation
    property int cfg_indicatorLocationDefault
    property int cfg_indicatorStyle
    property int cfg_indicatorStyleDefault
    property int cfg_indicatorMinLimit
    property int cfg_indicatorMinLimitDefault
    property int cfg_indicatorMaxLimit
    property int cfg_indicatorMaxLimitDefault
    property bool cfg_indicatorDesaturate
    property bool cfg_indicatorDesaturateDefault
    property bool cfg_indicatorGrow
    property bool cfg_indicatorGrowDefault
    property int cfg_indicatorGrowFactor
    property int cfg_indicatorGrowFactorDefault
    property int cfg_indicatorEdgeOffset
    property int cfg_indicatorEdgeOffsetDefault
    property int cfg_indicatorSize
    property int cfg_indicatorSizeDefault
    property int cfg_indicatorLength
    property int cfg_indicatorLengthDefault
    property int cfg_indicatorRadius
    property int cfg_indicatorRadiusDefault
    property int cfg_indicatorShrink
    property int cfg_indicatorShrinkDefault
    property bool cfg_indicatorDominantColor
    property bool cfg_indicatorDominantColorDefault
    property bool cfg_indicatorAccentColor
    property bool cfg_indicatorAccentColorDefault
    property string cfg_indicatorCustomColor
    property string cfg_indicatorCustomColorDefault
    property bool cfg_indicatorReverse
    property bool cfg_indicatorReverseDefault
    property bool cfg_indicatorOverride
    property bool cfg_indicatorOverrideDefault
    property bool cfg_iconScaleFromEdge
    property bool cfg_iconScaleFromEdgeDefault
    property int cfg_iconEdgeOffset
    property int cfg_iconEdgeOffsetDefault
}
