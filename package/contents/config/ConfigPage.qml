/*
    SPDX-FileCopyrightText: 2024-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.Page {
    // --- Properties to silence KCM errors ---
    // Defaults for existing aliases
    // --- General ---
    property bool cfg_showOnlyCurrentScreen: false
    property bool cfg_showOnlyCurrentScreenDefault: false
    property bool cfg_showOnlyCurrentDesktop: false
    property bool cfg_showOnlyCurrentDesktopDefault: false
    property bool cfg_showOnlyCurrentActivity: false
    property bool cfg_showOnlyCurrentActivityDefault: false
    property int cfg_minimizedFilter: 0
    property int cfg_minimizedFilterDefault: 0
    property var cfg_showOnlyMinimized: false
    property var cfg_showOnlyMinimizedDefault: false
    property var cfg_showOnlyNotMinimized: false
    property var cfg_showOnlyNotMinimizedDefault: false
    property bool cfg_unhideOnAttention: false
    property bool cfg_unhideOnAttentionDefault: false
    property bool cfg_animateAttentionStatus: true
    property bool cfg_animateAttentionStatusDefault: true
    property bool cfg_hideMoveToDesktopMenuWithOneDesktop: true
    property bool cfg_hideMoveToDesktopMenuWithOneDesktopDefault: true
    property int cfg_maxStripes: 0
    property int cfg_maxStripesDefault: 0
    property int cfg_maxButtonLength: 0
    property int cfg_maxButtonLengthDefault: 0
    property bool cfg_forceStripes: false
    property bool cfg_forceStripesDefault: false
    property bool cfg_enableToolTips: true
    property bool cfg_enableToolTipsDefault: true
    property bool cfg_showToolTips: true
    property bool cfg_showToolTipsDefault: true
    property int cfg_wheelAction: 1
    property int cfg_wheelActionDefault: 1
    property int cfg_wheelCtrlAction: 2
    property int cfg_wheelCtrlActionDefault: 2
    property bool cfg_wheelCtrlActionEnabled: true
    property bool cfg_wheelCtrlActionEnabledDefault: true
    property bool cfg_wheelShiftSystemVolumeEnabled: true
    property bool cfg_wheelShiftSystemVolumeEnabledDefault: true
    property bool cfg_showMediaControls: true
    property bool cfg_showMediaControlsDefault: true
    property bool cfg_wheelSkipMinimized: false
    property bool cfg_wheelSkipMinimizedDefault: false
    property bool cfg_highlightWindows: true
    property bool cfg_highlightWindowsDefault: true
    property bool cfg_indicateAudioStreams: true
    property bool cfg_indicateAudioStreamsDefault: true
    property int cfg_iconScale: 100
    property int cfg_iconScaleDefault: 100
    property int cfg_iconSizePx: 32
    property int cfg_iconSizePxDefault: 32
    property bool cfg_iconSizeOverride: false
    property bool cfg_iconSizeOverrideDefault: false

    // --- Preview Config ---
    property int cfg_previewSize: 48
    property int cfg_previewSizeDefault: 48
    property bool cfg_fill: false
    property bool cfg_fillDefault: false
    property int cfg_fillAlignment: 0
    property int cfg_fillAlignmentDefault: 0
    property bool cfg_taskHoverEffect: true
    property bool cfg_taskHoverEffectDefault: true
    property int cfg_taskHoverEffectStyle: 0
    property int cfg_taskHoverEffectStyleDefault: 0
    property int cfg_maxTextLines: 1
    property int cfg_maxTextLinesDefault: 1
    property bool cfg_minimizeActiveTaskOnClick: true
    property bool cfg_minimizeActiveTaskOnClickDefault: true
    property bool cfg_reverseMode: false
    property bool cfg_reverseModeDefault: false
    property int cfg_iconSpacing: 4
    property int cfg_iconSpacingDefault: 4
    property bool cfg_useBorders: true
    property bool cfg_useBordersDefault: true
    property int cfg_taskSpacingSize: 0
    property int cfg_taskSpacingSizeDefault: 0
    property bool cfg_overridePlasmaButtonDirection: false
    property bool cfg_overridePlasmaButtonDirectionDefault: false
    property int cfg_plasmaButtonDirection: 0
    property int cfg_plasmaButtonDirectionDefault: 0
    property int cfg_iconZoomFactor: 0
    property int cfg_iconZoomFactorDefault: 0
    property int cfg_iconZoomDuration: 200
    property int cfg_iconZoomDurationDefault: 200

    // --- Appearance / Behavior ---
    property int cfg_groupingStrategy: 0
    property int cfg_groupingStrategyDefault: 0
    property int cfg_iconOnly: 0
    property int cfg_iconOnlyDefault: 0
    property int cfg_groupedTaskVisualization: 0
    property int cfg_groupedTaskVisualizationDefault: 0
    property int cfg_sortingStrategy: 0
    property int cfg_sortingStrategyDefault: 0

    property int cfg_mediaControlsLocation: 0
    property int cfg_mediaControlsLocationDefault: 0

    property bool cfg_groupPopups: true
    property bool cfg_groupPopupsDefault: true

    property var cfg_groupingAppIdBlacklist: []
    property var cfg_groupingAppIdBlacklistDefault: []
    property var cfg_groupingLauncherUrlBlacklist: []
    property var cfg_groupingLauncherUrlBlacklistDefault: []
    property var cfg_launchers: []
    property var cfg_launchersDefault: []
    property int cfg_middleClickAction: 0
    property int cfg_middleClickActionDefault: 0

    // --- Task Button Appearance ---
    property bool cfg_buttonColorize: false
    property bool cfg_buttonColorizeDefault: false
    property bool cfg_buttonColorizeInactive: false
    property bool cfg_buttonColorizeInactiveDefault: false
    property bool cfg_buttonColorizeDominant: false
    property bool cfg_buttonColorizeDominantDefault: false
    property string cfg_buttonColorizeCustom: ""
    property string cfg_buttonColorizeCustomDefault: ""
    property bool cfg_disableButtonSvg: false
    property bool cfg_disableButtonSvgDefault: false
    property bool cfg_disableButtonInactiveSvg: false
    property bool cfg_disableButtonInactiveSvgDefault: false

    property bool cfg_clipIconToShape: false
    property bool cfg_clipIconToShapeDefault: false
    property int cfg_iconClipRadius: 50
    property int cfg_iconClipRadiusDefault: 50
    property bool cfg_clipIconBackgroundEnabled: false
    property bool cfg_clipIconBackgroundEnabledDefault: false
    property string cfg_clipIconBackgroundColor: "#000000"
    property string cfg_clipIconBackgroundColorDefault: "#000000"
    property int cfg_clipIconBackgroundOpacity: 20
    property int cfg_clipIconBackgroundOpacityDefault: 20
    property int cfg_clipIconBackgroundColorMode: 0
    property int cfg_clipIconBackgroundColorModeDefault: 0

    // --- Indicators ---
    property int cfg_indicatorsEnabled: 1
    property int cfg_indicatorsEnabledDefault: 1
    property int cfg_indicatorProgressStyle: 0
    property int cfg_indicatorProgressStyleDefault: 0
    property string cfg_indicatorProgressColor: ""
    property string cfg_indicatorProgressColorDefault: ""
    property int cfg_indicatorProgressThickness: 2
    property int cfg_indicatorProgressThicknessDefault: 2
    property int cfg_indicatorProgressOpacity: 100
    property int cfg_indicatorProgressOpacityDefault: 100
    property bool cfg_disableInactiveIndicators: false
    property bool cfg_disableInactiveIndicatorsDefault: false
    property bool cfg_indicatorsAnimated: true
    property bool cfg_indicatorsAnimatedDefault: true
    property int cfg_groupIconEnabled: 0
    property int cfg_groupIconEnabledDefault: 0
    property int cfg_indicatorLocation: 0
    property int cfg_indicatorLocationDefault: 0
    property int cfg_indicatorStyle: 0
    property int cfg_indicatorStyleDefault: 0
    property int cfg_indicatorMinLimit: 0
    property int cfg_indicatorMinLimitDefault: 0
    property int cfg_indicatorMaxLimit: 0
    property int cfg_indicatorMaxLimitDefault: 0
    property bool cfg_indicatorDesaturate: false
    property bool cfg_indicatorDesaturateDefault: false

    property int cfg_indicatorEdgeOffset: 0
    property int cfg_indicatorEdgeOffsetDefault: 0
    property int cfg_indicatorSize: 0
    property int cfg_indicatorSizeDefault: 0
    property int cfg_indicatorLength: 0
    property int cfg_indicatorLengthDefault: 0
    property int cfg_indicatorRadius: 0
    property int cfg_indicatorRadiusDefault: 0
    property int cfg_indicatorShrink: 0
    property int cfg_indicatorShrinkDefault: 0

    property int cfg_indicatorActiveLength: 12
    property int cfg_indicatorActiveLengthDefault: 12
    property int cfg_indicatorActiveSize: 5
    property int cfg_indicatorActiveSizeDefault: 5
    property int cfg_indicatorHoverLength: 14
    property int cfg_indicatorHoverLengthDefault: 14
    property int cfg_indicatorHoverSize: 5
    property int cfg_indicatorHoverSizeDefault: 5
    property bool cfg_indicatorResize: true
    property bool cfg_indicatorResizeDefault: true
    property bool cfg_indicatorResizeLength: true
    property bool cfg_indicatorResizeLengthDefault: true
    property bool cfg_indicatorResizeThickness: true
    property bool cfg_indicatorResizeThicknessDefault: true
    property bool cfg_indicatorHoverSeparate: false
    property bool cfg_indicatorHoverSeparateDefault: false
    property bool cfg_indicatorGroupSeparate: false
    property bool cfg_indicatorGroupSeparateDefault: false
    property int cfg_indicatorGroupLength: 10
    property int cfg_indicatorGroupLengthDefault: 10
    property int cfg_indicatorGroupSize: 3
    property int cfg_indicatorGroupSizeDefault: 3
    property bool cfg_indicatorShowPlus: true
    property bool cfg_indicatorShowPlusDefault: true
    property bool cfg_indicatorHighlightActive: true
    property bool cfg_indicatorHighlightActiveDefault: true
    property int cfg_indicatorAlignment: 0
    property int cfg_indicatorAlignmentDefault: 0
    property bool cfg_indicatorDominantColor: false
    property bool cfg_indicatorDominantColorDefault: false
    property bool cfg_indicatorAccentColor: false
    property bool cfg_indicatorAccentColorDefault: false
    property string cfg_indicatorCustomColor: ""
    property string cfg_indicatorCustomColorDefault: ""
    property bool cfg_indicatorReverse: false
    property bool cfg_indicatorReverseDefault: false
    property bool cfg_indicatorOverride: false
    property bool cfg_indicatorOverrideDefault: false
    property bool cfg_iconScaleFromEdge: false
    property bool cfg_iconScaleFromEdgeDefault: false
    property int cfg_iconEdgeOffset: 0
    property int cfg_iconEdgeOffsetDefault: 0
    property bool cfg_showBadges: true
    property bool cfg_showBadgesDefault: true
    property bool cfg_badgeHighlightNew: true
    property bool cfg_badgeHighlightNewDefault: true
    property bool cfg_showLivePreview: true
    property bool cfg_showLivePreviewDefault: true
    property bool cfg_smokeExplosionOnClose: false
    property bool cfg_smokeExplosionOnCloseDefault: false
    property bool cfg_unpinByDrag: false
    property bool cfg_unpinByDragDefault: false
    property bool cfg_unpinByDragExplosion: false
    property bool cfg_unpinByDragExplosionDefault: false
    property bool cfg_showBadgesOnLaunchers: true
    property bool cfg_showBadgesOnLaunchersDefault: true
    property bool cfg_showBrowserHistory: false
    property bool cfg_showBrowserHistoryDefault: false
    property int cfg_browserHistoryLimit: 10
    property int cfg_browserHistoryLimitDefault: 10
}
