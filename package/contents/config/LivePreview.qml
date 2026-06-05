/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

import "../ui/code/singletones"
import "../ui" as FancyUI
import "../ui/code/tools.js" as TaskTools
import org.kde.plasma.core as PlasmaCore

Item {
    id: previewRoot
    Layout.fillWidth: true
    Layout.maximumWidth: 650
    Layout.alignment: Qt.AlignLeft
    implicitHeight: cfg_page && cfg_page.cfg_showLivePreview ? 290 : titleLayout.height
    clip: false

    readonly property int locationBottom: PlasmaCore.Types.BottomEdge
    readonly property int locationTop: PlasmaCore.Types.TopEdge
    readonly property int locationLeft: PlasmaCore.Types.LeftEdge
    readonly property int locationRight: PlasmaCore.Types.RightEdge
    readonly property bool multiStripe: simulatedStripeCount > 1

    property var cfg_page: null
    property int location: PlasmaCore.Types.BottomEdge

    readonly property bool cfg_showToolTips: cfg_page ? cfg_page.cfg_showToolTips : true

    // Reference to the zoomed task item (Index 1) for tooltip positioning
    property var zoomedTaskItem: null

    // Dynamic task model that reacts to grouping settings
    ListModel {
        id: taskModel
    }

    // Grouping mode tracking
    readonly property int groupMode: cfg_page ? cfg_page.cfg_groupingStrategy : 0
    readonly property bool groupPopups: cfg_page ? cfg_page.cfg_groupPopups : true
    readonly property bool groupOverlay: cfg_page ? cfg_page.cfg_groupIconEnabled : true

    onGroupModeChanged: rebuildTaskModel()
    onGroupPopupsChanged: rebuildTaskModel()
    Component.onCompleted: rebuildTaskModel()

    function rebuildTaskModel() {
        taskModel.clear();

        if (groupMode === 0) {
            // Strategy 0: Disabled (5 tasks)
            taskModel.append({ iconName: "plasmadiscover",   taskName: "Discover",   isMinimized: true,  isActive: false, isHovered: false, playingAudio: false, isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: true  });
            taskModel.append({ iconName: "org.kde.dolphin",  taskName: "Dolphin",    isMinimized: false, isActive: true,  isHovered: true,  playingAudio: false, isMuted: false, showBadge: true,  badgeCount: 3, isGroup: false, groupCount: 1, showProgress: false });
            taskModel.append({ iconName: "utilities-terminal",   taskName: "Konsole",isMinimized: false, isActive: false, isHovered: false, playingAudio: false, isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: false });
            taskModel.append({ iconName: "internet-web-browser", taskName: "Browser",isMinimized: false, isActive: false, isHovered: false, playingAudio: true,  isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: false });
            taskModel.append({ iconName: "org.kde.dolphin",  taskName: "Dolphin",    isMinimized: false, isActive: false, isHovered: false, playingAudio: false, isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: false });
        } else if (groupMode === 1 && groupPopups === false) {
            // Strategy 1, Popups false: Side-by-side (5 tasks, dolphins adjacent)
            taskModel.append({ iconName: "plasmadiscover",   taskName: "Discover",   isMinimized: true,  isActive: false, isHovered: false, playingAudio: false, isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: true  });
            taskModel.append({ iconName: "org.kde.dolphin",  taskName: "Dolphin",    isMinimized: false, isActive: true,  isHovered: true,  playingAudio: false, isMuted: false, showBadge: true,  badgeCount: 3, isGroup: false, groupCount: 1, showProgress: false });
            taskModel.append({ iconName: "org.kde.dolphin",  taskName: "Dolphin",    isMinimized: false, isActive: false, isHovered: false, playingAudio: false, isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: false });
            taskModel.append({ iconName: "utilities-terminal",   taskName: "Konsole",isMinimized: false, isActive: false, isHovered: false, playingAudio: false, isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: false });
            taskModel.append({ iconName: "internet-web-browser", taskName: "Browser",isMinimized: false, isActive: false, isHovered: false, playingAudio: true,  isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: false });
        } else {
            // Strategy 1, Popups true: Collapsed (4 tasks, Dolphin is a group)
            taskModel.append({ iconName: "plasmadiscover",   taskName: "Discover",   isMinimized: true,  isActive: false, isHovered: false, playingAudio: false, isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: true  });
            taskModel.append({ iconName: "org.kde.dolphin",  taskName: "Dolphin",    isMinimized: false, isActive: true,  isHovered: true,  playingAudio: false, isMuted: false, showBadge: true,  badgeCount: 3, isGroup: true,  groupCount: 2, showProgress: false });
            taskModel.append({ iconName: "utilities-terminal",   taskName: "Konsole",isMinimized: false, isActive: false, isHovered: false, playingAudio: false, isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: false });
            taskModel.append({ iconName: "internet-web-browser", taskName: "Browser",isMinimized: false, isActive: false, isHovered: false, playingAudio: true,  isMuted: false, showBadge: false, badgeCount: 0, isGroup: false, groupCount: 1, showProgress: false });
        }
    }

    // Current hover state for tooltip positioning parity
    readonly property int effectiveGrowSize: (zoomedTaskItem && cfg_page && cfg_page.cfg_iconOnly === 1 && cfg_page.cfg_taskHoverEffect) ? cfg_page.cfg_iconZoomFactor : 0

    readonly property int currentEdgeIdx: {
        switch (location) {
            case PlasmaCore.Types.TopEdge: return 1;
            case PlasmaCore.Types.LeftEdge: return 2;
            case PlasmaCore.Types.RightEdge: return 3;
            case PlasmaCore.Types.BottomEdge:
            default: return 0;
        }
    }
    property bool isVertical: currentEdgeIdx === 2 || currentEdgeIdx === 3

    property int simulatedLocation: currentEdgeIdx === 0 ? locationBottom :
                                    currentEdgeIdx === 1 ? locationTop :
                                    currentEdgeIdx === 2 ? locationLeft : locationRight
    property int simulatedThickness: cfg_page ? cfg_page.cfg_previewSize : Math.round(Kirigami.Units.gridUnit * 2.5)

    // Multistripe simulation
    readonly property int taskCountDisplay: taskModel.count
    readonly property int simulatedStripeCount: {
        let maxS = (cfg_page && cfg_page.cfg_maxStripes !== undefined) ? cfg_page.cfg_maxStripes : 1
        if (maxS <= 1) return 1

        // preferredMinHeight from LayoutMetrics.js
        let minLaneSize = Kirigami.Units.iconSizes.sizeForLabels + 4
        let count = Math.floor(simulatedThickness / minLaneSize)
        return Math.min(maxS, Math.max(1, count))
    }
    readonly property int simulatedOrthogonalCount: Math.ceil(taskCountDisplay / simulatedStripeCount)
    readonly property int laneHeight: Math.floor(simulatedThickness / simulatedStripeCount)

    // Inner padding (iconSpacing) logic
    readonly property real spacingAdjustment: (cfg_page && cfg_page.cfg_iconSpacing !== undefined) ? cfg_page.cfg_iconSpacing : 1
    function horizontalMargins() {
        return (taskFrame.margins.left + taskFrame.margins.right) * (isVertical ? 1 : spacingAdjustment)
    }
    function verticalMargins() {
        return (taskFrame.margins.top + taskFrame.margins.bottom) * (isVertical ? spacingAdjustment : 1)
    }

    function adjustMargin(isVert, size, margin) {
        if (!size) return margin;
        // Match LayoutMetrics.js: available space is checked against verticalMargins for vertical adjustment
        // Note: Production code is a bit inconsistent here but we aim for visual parity
        let margins = isVert ? horizontalMargins() : verticalMargins();
        if ((size - margins) < Kirigami.Units.iconSizes.small) {
            return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
        }
        let multiplier = (isVert !== isVertical) ? spacingAdjustment : 1;
        return margin * multiplier;
    }

    // Dynamic simulated sizes to match LayoutMetrics.js formulas
    readonly property int simulatedMinLauncherWidth: {
        let baseW = isVertical ? (Kirigami.Units.iconSizes.sizeForLabels + 4) : Math.min(simulatedThickness, Kirigami.Units.iconSizes.small * 3);
        let hMargins = horizontalMargins();
        let topAdj = adjustMargin(false, baseW, taskFrame.margins.top);
        let bottomAdj = adjustMargin(false, baseW, taskFrame.margins.bottom);
        return (baseW + hMargins) - (topAdj + bottomAdj);
    }
    readonly property int simulatedMinWidth: iconsOnly ? simulatedMinLauncherWidth : (simulatedMinLauncherWidth + Kirigami.Units.gridUnit * 10)
    
    readonly property int simulatedMaxWidth: iconsOnly ? (isVertical ? (simulatedThickness + verticalMargins()) : (simulatedThickness + horizontalMargins())) : (Kirigami.Units.gridUnit * 12)

    readonly property bool iconsOnly: cfg_page ? cfg_page.cfg_iconOnly === 1 : true
    readonly property bool centerAlign: iconsOnly && cfg_page && cfg_page.cfg_fill && cfg_page.cfg_fillAlignment === 1

    // Theme FrameSvg for authentic margins calculation
    KSvg.FrameSvgItem {
        id: taskFrame
        visible: false
        imagePath: "widgets/tasks"
        prefix: "normal"
    }

    RowLayout {
        id: titleLayout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: 0
        z: 10
        spacing: Kirigami.Units.smallSpacing

        CheckBox {
            id: headerToggle
            leftPadding: 0
            checked: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_showLivePreview : true
            onToggled: if (previewRoot.cfg_page) previewRoot.cfg_page.cfg_showLivePreview = checked
        }

        Label {
            text: Wrappers.i18n("Preview")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.textColor
        }
    }

 
    GroupBox {
        id: groupBox
        anchors.top: titleLayout.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        padding: Kirigami.Units.smallSpacing
        topPadding: Kirigami.Units.mediumSpacing
        visible: previewRoot.cfg_page && previewRoot.cfg_page.cfg_showLivePreview
    }

    ColumnLayout {
        anchors.fill: groupBox
        anchors.margins: Kirigami.Units.smallSpacing
        visible: groupBox.visible
        spacing: Kirigami.Units.largeSpacing

        // Inner workspace area
        Rectangle {
            id: innerPreviewArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1
            radius: Kirigami.Units.smallSpacing
            clip: true

            // 1. Controls Overlay (Space-saving & Context-aware)
            Kirigami.ShadowedRectangle {
                id: controlsOverlay
                z: 100
                anchors {
                    top: previewRoot.location === PlasmaCore.Types.TopEdge ? undefined : parent.top
                    bottom: previewRoot.location === PlasmaCore.Types.TopEdge ? parent.bottom : undefined
                    right: previewRoot.location === PlasmaCore.Types.RightEdge ? undefined : parent.right
                    left: previewRoot.location === PlasmaCore.Types.RightEdge ? parent.left : undefined
                    margins: Kirigami.Units.largeSpacing
                }
                
                width: overlayLayout.implicitWidth + Kirigami.Units.mediumSpacing * 2
                height: overlayLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
                
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.backgroundColor
                opacity: 0.85
                
                shadow {
                    size: Kirigami.Units.smallSpacing
                    color: Qt.rgba(0, 0, 0, 0.3)
                }

                RowLayout {
                    id: overlayLayout
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.mediumSpacing

                    Label {
                        text: Wrappers.i18n("Panel thickness (preview):")
                        opacity: 0.7
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                    SpinBox {
                        id: localSizeSpinner
                        from: 24
                        to: 128
                        value: previewRoot.cfg_page && previewRoot.cfg_page.cfg_previewSize !== undefined ? previewRoot.cfg_page.cfg_previewSize : 48
                        onValueModified: { if (previewRoot.cfg_page) previewRoot.cfg_page.cfg_previewSize = value }
                        stepSize: 2
                        editable: true

                        ToolTip.text: Wrappers.i18n("This setting only changes the appearance of this preview and does not affect your actual system panel.")
                        ToolTip.visible: hovered
                        ToolTip.delay: Kirigami.Units.toolTipDelay

                        // Smaller SpinBox for overlay
                        contentItem: TextInput {
                            z: 2
                            text: localSizeSpinner.textFromValue(localSizeSpinner.value, localSizeSpinner.locale)
                            font: localSizeSpinner.font
                            color: Kirigami.Theme.textColor
                            selectionColor: Kirigami.Theme.highlightColor
                            selectedTextColor: Kirigami.Theme.highlightedTextColor
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !localSizeSpinner.editable
                            validator: localSizeSpinner.validator
                            inputMethodHints: Qt.ImhDigitsOnly
                        }
                    }
                    Label {
                        text: "px"
                        opacity: 0.5
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

                // Desktop Workspace Background (Local Asset)
                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: Qt.resolvedUrl("../ui/assets/preview_background.png")
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.9 // Vibrant and "Next-gen" look
                    z: -1 // Behind the panel

                    // Safety fallback: Color if image fails to load
                    Rectangle {
                        anchors.fill: parent
                        color: Kirigami.Theme.backgroundColor
                        opacity: 0.2
                        visible: parent.status !== Image.Ready
                    }
                }

                // Panel background (Preserved logic)
                KSvg.FrameSvgItem {
                    id: dummyPanel

                    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                    Kirigami.Theme.inherit: false
                    clip: false

                    width: previewRoot.isVertical ? previewRoot.simulatedThickness : parent.width
                    height: previewRoot.isVertical ? parent.height : previewRoot.simulatedThickness

                    imagePath: "widgets/panel-background"

                    x: previewRoot.isVertical
                        ? (previewRoot.simulatedLocation === previewRoot.locationLeft ? 0 : parent.width - width)
                        : (parent.width - width) / 2
                    y: !previewRoot.isVertical
                        ? (previewRoot.simulatedLocation === previewRoot.locationTop ? 0 : parent.height - height)
                        : (parent.height - height) / 2

                    GridLayout {
                        id: mockTasksLayout
                        
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: (previewRoot.centerAlign && !previewRoot.isVertical) ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
                        anchors.topMargin: (previewRoot.centerAlign && previewRoot.isVertical) ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
                        
                        width: previewRoot.isVertical ? parent.width : Math.min(parent.width, implicitWidth)
                        height: previewRoot.isVertical ? Math.min(parent.height, implicitHeight) : parent.height
                        clip: false

                        columns: previewRoot.isVertical ? previewRoot.simulatedStripeCount : previewRoot.simulatedOrthogonalCount
                        rows: previewRoot.isVertical ? previewRoot.simulatedOrthogonalCount : previewRoot.simulatedStripeCount

                        rowSpacing: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_taskSpacingSize : 0
                        columnSpacing: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_taskSpacingSize : 0

                        Repeater {
                            id: taskRepeater
                            model: taskModel

                            Item {
                                id: mockTask
                                z: isHovered ? 2000 : 0

                                Component.onCompleted: {
                                    if (mockTask.isHovered) previewRoot.zoomedTaskItem = mockTask;
                                }

                                readonly property int maxW: (previewRoot.cfg_page ? previewRoot.cfg_page.cfg_maxButtonLength : Kirigami.Units.gridUnit * 10)

                                Layout.preferredWidth: mockTask.showText ? maxW : previewRoot.simulatedMaxWidth
                                Layout.preferredHeight: previewRoot.laneHeight + (previewRoot.isVertical ? (previewRoot.verticalMargins() - (taskFrame.margins.top + taskFrame.margins.bottom)) : 0)
                                Layout.minimumWidth: previewRoot.laneHeight
                                Layout.minimumHeight: previewRoot.laneHeight
                                Layout.maximumWidth: previewRoot.isVertical ? previewRoot.simulatedThickness : (mockTask.showText ? Layout.preferredWidth : Layout.preferredWidth)
                                Layout.maximumHeight: previewRoot.isVertical ? Layout.preferredWidth : previewRoot.simulatedThickness
                                Layout.fillWidth: previewRoot.isVertical || mockTask.showText
                                Layout.fillHeight: !previewRoot.isVertical || mockTask.showText
                                required property int index
                                required property string iconName
                                required property string taskName
                                required property bool isMinimized
                                required property bool isActive
                                required property bool isHovered
                                required property bool playingAudio
                                required property bool isMuted
                                required property bool showBadge
                                required property int badgeCount
                                required property bool isGroup
                                required property int groupCount
                                required property bool showProgress

                                readonly property var cfg: previewRoot.cfg_page
                                readonly property bool cfgReady: cfg !== null
                                readonly property Item taskIconItem: taskIcon

                                Kirigami.ImageColors {
                                    id: taskImageColors
                                    source: taskIcon.source
                                }

                                readonly property color dominantColor: taskImageColors.dominant
                                readonly property color tintColor: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark ? "#ffffff" : "#000000"
                                readonly property color indicatorColor: Kirigami.ColorUtils.tintWithAlpha(dominantColor, tintColor, .38)

                                readonly property bool isRunning: true
                                readonly property bool isInactive: !mockTask.isActive && !mockTask.isHovered

                                readonly property bool hasAudio: mockTask.playingAudio || mockTask.isMuted

                                readonly property bool isGroupParent: mockTask.isGroup

                                readonly property bool showText: !previewRoot.iconsOnly && (!previewRoot.isVertical || previewRoot.simulatedThickness > (Kirigami.Units.gridUnit * 4))

                                readonly property int effLoc: (previewRoot.simulatedLocation === previewRoot.locationTop ? 3 :
                                                              previewRoot.simulatedLocation === previewRoot.locationLeft ? 1 :
                                                              previewRoot.simulatedLocation === previewRoot.locationRight ? 2 : 0)


                                // 1. Frame background
                                KSvg.FrameSvgItem {
                                    id: taskBackground
                                    anchors.fill: parent
                                    imagePath: (mockTask.cfgReady && mockTask.cfg.cfg_disableButtonSvg) ? "" : "widgets/tasks"
                                    enabledBorders: (mockTask.cfgReady && mockTask.cfg.cfg_useBorders) ? (1 | 2 | 4 | 8) : 0

                                    readonly property string basePrefix: {
                                        if (mockTask.isActive) return "focus";
                                        if (mockTask.isMinimized) return "minimized";
                                        return "normal";
                                    }

                                    prefix: mockTask.isHovered ?
                                        TaskTools.taskPrefixHovered(basePrefix, previewRoot.simulatedLocation) :
                                        TaskTools.taskPrefix(basePrefix, previewRoot.simulatedLocation)

                                    readonly property bool hideDueToDecoration: mockTask.isInactive && mockTask.cfgReady && mockTask.cfg.cfg_disableButtonInactiveSvg
                                    readonly property bool hideDueToColorize: {
                                        if (!mockTask.cfgReady || !mockTask.cfg.cfg_buttonColorize) return false;
                                        if (mockTask.isActive || mockTask.isHovered) return true;
                                        if (mockTask.isInactive && mockTask.cfg.cfg_buttonColorizeInactive) {
                                            return true;
                                        }
                                        return false;
                                    }

                                    visible: !hideDueToDecoration
                                    layer.enabled: hideDueToColorize
                                    layer.effect: MultiEffect {
                                        brightness: 1.0
                                        colorization: 1.0
                                        colorizationColor: {
                                            if (!mockTask.cfgReady) return "transparent";
                                            return mockTask.cfg.cfg_buttonColorizeDominant ?
                                                mockTask.indicatorColor : mockTask.cfg.cfg_buttonColorizeCustom;
                                        }
                                    }
                                }



                                // 3. Progress overlay (reuses production component)
                                FancyUI.TaskProgressOverlay {
                                    anchors.fill: taskBackground
                                    visible: mockTask.showProgress && mockTask.cfgReady && mockTask.cfg.cfg_indicatorProgressStyle > 0
                                    pStyle: mockTask.cfgReady ? mockTask.cfg.cfg_indicatorProgressStyle : 0
                                    pColor: mockTask.cfgReady ? mockTask.cfg.cfg_indicatorProgressColor : "transparent"
                                    pOpacity: mockTask.cfgReady ? mockTask.cfg.cfg_indicatorProgressOpacity / 100.0 : 1.0
                                    pThick: mockTask.cfgReady ? mockTask.cfg.cfg_indicatorProgressThickness : 2
                                    pPosition: 0.7
                                    panelLocation: previewRoot.simulatedLocation
                                }

                                // Group overlay
                                Loader {
                                    id: groupExpanderLoader
                                    active: (mockTask.cfgReady && mockTask.cfg.cfg_groupIconEnabled) && mockTask.isGroupParent
                                    sourceComponent: Component {
                                         FancyUI.GroupExpanderOverlay {
                                            iconBox: iconBox
                                            taskModel: ({ "IsGroupParent": true, "IsWindow": false })
                                            parent: mockTask
                                            locationOverride: mockTask.effLoc
                                        }
                                    }
                                }

                                // 4. Icon & badges
                                Item {
                                    id: iconBox

                                    readonly property int mLeft: previewRoot.adjustMargin(true, parent.width, taskFrame.margins.left)
                                    readonly property int mRight: previewRoot.adjustMargin(true, parent.width, taskFrame.margins.right)
                                    readonly property int mTop: previewRoot.adjustMargin(false, parent.height, taskFrame.margins.top)
                                    readonly property int mBottom: previewRoot.adjustMargin(false, parent.height, taskFrame.margins.bottom)

                                    // Content area should be a square based on the smaller dimension (height for horizontal panel)
                                    readonly property real contentSize: (previewRoot.isVertical ? parent.width : parent.height) -
                                                                         (previewRoot.isVertical ? (taskFrame.margins.left + taskFrame.margins.right) : (taskFrame.margins.top + taskFrame.margins.bottom))

                                    width: contentSize
                                    height: contentSize

                                    states: [
                                        State {
                                            name: "iconsOnly"
                                            when: !mockTask.showText
                                            AnchorChanges {
                                                target: iconBox
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: undefined
                                                anchors.top: undefined
                                            }
                                        },
                                        State {
                                            name: "classic"
                                            when: mockTask.showText
                                            AnchorChanges {
                                                target: iconBox
                                                anchors.horizontalCenter: previewRoot.isVertical ? parent.horizontalCenter : undefined
                                                anchors.left: previewRoot.isVertical ? undefined : parent.left
                                                anchors.verticalCenter: previewRoot.isVertical ? undefined : parent.verticalCenter
                                                anchors.top: previewRoot.isVertical ? parent.top : undefined
                                            }
                                            PropertyChanges {
                                                target: iconBox
                                                anchors.leftMargin: previewRoot.isVertical ? 0 : mLeft
                                                anchors.topMargin: previewRoot.isVertical ? mTop : 0
                                            }
                                        }
                                    ]

                                    Kirigami.Icon {
                                        id: taskIcon
                                        // anchors.fill: parent // REMOVED: fill prevents custom width/height and zoom

                                        readonly property bool sizeOverride: mockTask.cfgReady && mockTask.cfg.cfg_iconSizeOverride
                                        readonly property int fixedSize: mockTask.cfgReady ? mockTask.cfg.cfg_iconSizePx : 32
                                        readonly property real iconScale: mockTask.cfgReady ? mockTask.cfg.cfg_iconScale / 100 : 1.0
                                        readonly property int growSize: {
                                            if (!mockTask.cfgReady || mockTask.cfg.cfg_iconOnly !== 1 || !mockTask.cfg.cfg_taskHoverEffect) {
                                                return 0;
                                            }
                                            const activeHoveredTask = previewRoot.zoomedTaskItem;
                                            if (!activeHoveredTask) {
                                                return 0;
                                            }
                                            const diff = Math.abs(mockTask.index - activeHoveredTask.index);
                                            const isParabolic = mockTask.cfg.cfg_taskHoverEffectStyle === 1;

                                            if (diff === 0) {
                                                return mockTask.cfg.cfg_iconZoomFactor;
                                            }
                                            if (isParabolic) {
                                                if (diff === 1) {
                                                    return Math.round(0.30 * mockTask.cfg.cfg_iconZoomFactor);
                                                }
                                            }
                                            return 0;
                                        }

                                        readonly property bool scaleFromEdge: mockTask.cfgReady && mockTask.cfg.cfg_iconScaleFromEdge
                                        readonly property int edgeOffset: mockTask.cfgReady ? mockTask.cfg.cfg_iconEdgeOffset : 0

                                        readonly property int baseWidth: (sizeOverride ? fixedSize : (parent.width * iconScale))
                                        readonly property int baseHeight: (sizeOverride ? fixedSize : (parent.height * iconScale))
                                        readonly property int iconSize: Math.min(baseWidth, baseHeight) + growSize
                                        readonly property real edgeMarginH: scaleFromEdge ? edgeOffset : (parent.width - iconSize) / 2
                                        readonly property real edgeMarginV: scaleFromEdge ? edgeOffset : (parent.height - iconSize) / 2

                                        width: iconSize
                                        height: iconSize

                                        // Simplified alignment (matches Task.qml)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: edgeMarginV

                                        states: [
                                            State {
                                                name: "top"
                                                when: previewRoot.simulatedLocation === previewRoot.locationTop
                                                AnchorChanges { target: taskIcon; anchors.top: parent.top; anchors.bottom: undefined; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: undefined; anchors.left: undefined; anchors.right: undefined }
                                                PropertyChanges { target: taskIcon; anchors.topMargin: taskIcon.edgeMarginV; anchors.bottomMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                                            },
                                            State {
                                                name: "left"
                                                when: previewRoot.simulatedLocation === previewRoot.locationLeft
                                                AnchorChanges { target: taskIcon; anchors.left: parent.left; anchors.right: undefined; anchors.verticalCenter: parent.verticalCenter; anchors.horizontalCenter: undefined; anchors.top: undefined; anchors.bottom: undefined }
                                                PropertyChanges { target: taskIcon; anchors.leftMargin: taskIcon.edgeMarginH; anchors.rightMargin: 0; anchors.topMargin: 0; anchors.bottomMargin: 0 }
                                            },
                                            State {
                                                name: "right"
                                                when: previewRoot.simulatedLocation === previewRoot.locationRight
                                                AnchorChanges { target: taskIcon; anchors.right: parent.right; anchors.left: undefined; anchors.verticalCenter: parent.verticalCenter; anchors.horizontalCenter: undefined; anchors.top: undefined; anchors.bottom: undefined }
                                                PropertyChanges { target: taskIcon; anchors.rightMargin: taskIcon.edgeMarginH; anchors.leftMargin: 0; anchors.topMargin: 0; anchors.bottomMargin: 0 }
                                            }
                                        ]

                                        source: mockTask.iconName
                                        roundToIconSize: false

                                        layer.enabled: mockTask.cfgReady && mockTask.cfg.cfg_clipIconToShape
                                        layer.smooth: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: mockTask.cfgReady && mockTask.cfg.cfg_clipIconToShape
                                            maskSource: previewIconMask
                                            maskThresholdMin: 0.5
                                            maskSpreadAtMin: 1.0
                                        }
                                    }

                                    Rectangle {
                                        id: previewIconMask
                                        x: -9999
                                        y: -9999
                                        width: taskIcon.width
                                        height: taskIcon.height
                                        radius: mockTask.cfgReady ? (mockTask.cfg.cfg_iconClipRadius / 200) * Math.min(taskIcon.width, taskIcon.height) : Math.min(taskIcon.width, taskIcon.height) * 0.25
                                        color: "black"
                                        visible: true
                                        antialiasing: true
                                        layer.enabled: true
                                        layer.smooth: true
                                    }

                                    Loader {
                                        id: previewIconColorsLoader
                                        // ImageColors is a heavy C++ component that parses the icon. To prevent memory and CPU waste,
                                        // we only activate this Loader when shape clipping is enabled, background card is enabled,
                                        // and a dynamic color extraction mode (dominant or average) is selected.
                                        active: mockTask.cfgReady && mockTask.cfg.cfg_clipIconToShape && mockTask.cfg.cfg_clipIconBackgroundEnabled && (mockTask.cfg.cfg_clipIconBackgroundColorMode === 1 || mockTask.cfg.cfg_clipIconBackgroundColorMode === 2)
                                        sourceComponent: Kirigami.ImageColors {
                                            source: taskIcon.source
                                        }
                                    }

                                    Rectangle {
                                        id: previewIconBackground
                                        anchors.fill: taskIcon
                                        radius: mockTask.cfgReady ? (mockTask.cfg.cfg_iconClipRadius / 200) * Math.min(taskIcon.width, taskIcon.height) : Math.min(taskIcon.width, taskIcon.height) * 0.25
                                        antialiasing: true
                                        color: {
                                            if (!mockTask.cfgReady) {
                                                return "#000000";
                                            }
                                            const mode = mockTask.cfg.cfg_clipIconBackgroundColorMode;
                                            if (mode === 1) {
                                                let pDom = "dominant";
                                                const domColor = previewIconColorsLoader.item ? previewIconColorsLoader.item[pDom] : "transparent";
                                                return TaskTools.harmonizeIconColor(domColor, domColor, Kirigami.Theme.backgroundColor, false);
                                            } else if (mode === 2) {
                                                let pDom = "dominant";
                                                let pPal = "palette";
                                                let pAvg = "average";
                                                const avgColor = previewIconColorsLoader.item ? TaskTools.getAveragePaletteColor(previewIconColorsLoader.item[pPal], previewIconColorsLoader.item[pAvg]) : "transparent";
                                                const domColor = previewIconColorsLoader.item ? previewIconColorsLoader.item[pDom] : "transparent";
                                                return TaskTools.harmonizeIconColor(avgColor, domColor, Kirigami.Theme.backgroundColor, true);
                                            } else if (mode === 3) {
                                                return Kirigami.Theme.highlightColor;
                                            }
                                            return mockTask.cfg.cfg_clipIconBackgroundColor;
                                        }
                                        opacity: mockTask.cfgReady ? (mockTask.cfg.cfg_clipIconBackgroundOpacity / 100) : 0.2
                                        visible: mockTask.cfgReady && mockTask.cfg.cfg_clipIconToShape && mockTask.cfg.cfg_clipIconBackgroundEnabled
                                        z: -1
                                    }

                                    // Notification badge (proportional to taskIcon, scales with zoom)
                                    FancyUI.Badge {
                                        visible: mockTask.showBadge && mockTask.cfgReady && mockTask.cfg.cfg_showBadges
                                        z: 10

                                        readonly property real iconR: Math.min(taskIcon.width, taskIcon.height) / 2
                                        readonly property real badgeDiam: Math.max(8, iconR * 0.7)
                                        height: badgeDiam

                                        readonly property real notifCX: previewRoot.isVertical ? (taskIcon.width * 0.5) : (taskIcon.width * 0.88)
                                        readonly property real notifCY: previewRoot.isVertical ? (taskIcon.height * 0.88) : (taskIcon.height * 0.05)
                                        x: taskIcon.x + notifCX - width / 2
                                        y: taskIcon.y + notifCY

                                        number: mockTask.badgeCount
                                        isRound: true
                                        hovered: mockTask.isHovered
                                    }

                                }
                                
                                // Audio indicator (Matching TaskBadgeOverlay.qml exactly)
                                FancyUI.Badge {
                                    id: audioBadge
                                    visible: (mockTask.playingAudio || mockTask.isMuted) && mockTask.cfgReady && mockTask.cfg.cfg_indicateAudioStreams
                                    z: 50

                                    readonly property real iconR: Math.min(taskIcon.width, taskIcon.height) / 2
                                    readonly property real badgeDiam: Math.max(8, iconR * 0.7)
                                    readonly property real audioBadgeDiam: badgeDiam * 1.4
                                    
                                    height: audioBadgeDiam
                                    width: height

                                    // Match proportions from TaskBadgeOverlay.qml
                                    readonly property real audioBaseX: previewRoot.isVertical ? (taskIcon.width * 0.045) : (-taskIcon.width * 0.045)
                                    readonly property real audioBaseY: previewRoot.isVertical ? (taskIcon.height * 0.1) : (taskIcon.height * 0.045)

                                    x: taskIcon.x + audioBaseX
                                    y: taskIcon.y + audioBaseY

                                    textSource: "🕪"
                                    mirrorText: true
                                    overlaySource: mockTask.isMuted ? "⦸" : ""
                                    opacity: mockTask.isMuted ? 0.7 : 1.0
                                    
                                    showBackground: false
                                    shadowEnabled: true
                                    fontFactor: 0.85
                                    isBold: false
                                    isRound: true
                                }

                                // 5. Text label
                                Label {
                                    id: label
                                    visible: mockTask.showText
                                    text: mockTask.taskName
                                    color: Kirigami.Theme.textColor
                                    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

                                    anchors {
                                        left: previewRoot.isVertical ? parent.left : iconBox.right
                                        leftMargin: Kirigami.Units.smallSpacing
                                        right: parent.right
                                        rightMargin: Kirigami.Units.smallSpacing
                                        top: previewRoot.isVertical ? iconBox.bottom : parent.top
                                        bottom: parent.bottom
                                    }

                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                    verticalAlignment: previewRoot.isVertical ? Text.AlignTop : Text.AlignVCenter
                                    horizontalAlignment: (previewRoot.isVertical || mockTask.width < 100) ? Text.AlignHCenter : Text.AlignLeft
                                    maximumLineCount: 1
                                }

                                // 6. Group expander overlay (Matching GroupExpanderOverlay.qml)
                                KSvg.SvgItem {
                                    id: groupArrow
                                    visible: mockTask.isGroup && mockTask.cfgReady && mockTask.cfg.cfg_groupIconEnabled
                                    z: 60

                                    readonly property int effLoc: mockTask.effLoc
                                    
                                    anchors {
                                        horizontalCenter: (effLoc === 0 || effLoc === 3) ? parent.horizontalCenter : undefined
                                        verticalCenter: (effLoc === 1 || effLoc === 2) ? parent.verticalCenter : undefined
                                        bottom: effLoc === 0 ? parent.bottom : undefined
                                        top: effLoc === 3 ? parent.top : undefined
                                        left: effLoc === 1 ? parent.left : undefined
                                        right: effLoc === 2 ? parent.right : undefined
                                    }

                                    implicitWidth: Math.min(naturalSize.width, 16)
                                    implicitHeight: Math.min(naturalSize.height, 16)

                                    imagePath: "widgets/tasks"
                                    elementId: {
                                        switch (effLoc) {
                                            case 1: return "group-expander-left";
                                            case 3: return "group-expander-top";
                                            case 2: return "group-expander-right";
                                            default: return "group-expander-bottom";
                                        }
                                    }
                                }

                                // 6. Indicator
                                Item {
                                    id: indicatorArea
                                    anchors.fill: parent
                                    visible: mockTask.cfgReady && mockTask.cfg.cfg_indicatorsEnabled && mockTask.isRunning

                                    readonly property int locMap: (mockTask.cfgReady && mockTask.cfg.cfg_indicatorOverride) ? mockTask.cfg.cfg_indicatorLocation : -1
                                    readonly property int effLoc: locMap !== -1 ? locMap : mockTask.effLoc

                                    readonly property bool isVerticalIndicator: effLoc === 1 || effLoc === 2
                                    readonly property int spacing: 2

                                    // Expose parent properties for nested Repeater delegate
                                    readonly property int segCount: mockTask.groupCount
                                    readonly property bool parentIsGroupParent: mockTask.isGroupParent
                                    readonly property var parentCfg: mockTask.cfg
                                    readonly property bool parentCfgReady: mockTask.cfgReady
                                    readonly property real parentWidth: mockTask.width
                                    readonly property real parentHeight: mockTask.height
                                    readonly property bool parentIsMinimized: mockTask.isMinimized
                                    readonly property color parentIndicatorColor: mockTask.indicatorColor

                                    Repeater {
                                        model: indicatorArea.segCount
                                        Rectangle {
                                            id: indicator
                                            required property int index
                                            readonly property int indStyle: indicatorArea.parentCfgReady ? indicatorArea.parentCfg.cfg_indicatorStyle : 0
                                            readonly property int indLength: indicatorArea.parentCfgReady ? indicatorArea.parentCfg.cfg_indicatorLength : 8
                                            readonly property int indSize: indicatorArea.parentCfgReady ? indicatorArea.parentCfg.cfg_indicatorSize : 2
                                            readonly property int indShrink: indicatorArea.parentCfgReady ? indicatorArea.parentCfg.cfg_indicatorShrink : 0

                                            readonly property real pSize: !indicatorArea.isVerticalIndicator ? indicatorArea.parentWidth : indicatorArea.parentHeight
                                            readonly property real computedSize: indStyle === 1 ? indLength : Math.max(8, (pSize - indShrink) / (indicatorArea.parentIsGroupParent ? 2.5 : 1))

                                            width: indicatorArea.isVerticalIndicator ? indSize : computedSize
                                            height: indicatorArea.isVerticalIndicator ? computedSize : indSize

                                            readonly property int edgeOff: indicatorArea.parentCfgReady ? indicatorArea.parentCfg.cfg_indicatorEdgeOffset : 0

                                            x: {
                                                if (!indicatorArea) return 0;
                                                let sc = indicatorArea.segCount;
                                                let base = indicatorArea.isVerticalIndicator ? 
                                                    (indicatorArea.effLoc === 1 ? edgeOff : parent.width - width - edgeOff) :
                                                    (parent.width - (width * sc + (sc > 1 ? indicatorArea.spacing * (sc - 1) : 0))) / 2;
                                                
                                                if (!indicatorArea.isVerticalIndicator && sc > 1) {
                                                    return base + (index * (width + indicatorArea.spacing));
                                                }
                                                return base;
                                            }
                                            y: {
                                                if (!indicatorArea) return 0;
                                                let sc = indicatorArea.segCount;
                                                let base = !indicatorArea.isVerticalIndicator ? 
                                                    (indicatorArea.effLoc === 3 ? edgeOff : parent.height - height - edgeOff) :
                                                    (parent.height - (height * sc + (sc > 1 ? indicatorArea.spacing * (sc - 1) : 0))) / 2;
                                                
                                                if (indicatorArea.isVerticalIndicator && sc > 1) {
                                                    return base + (index * (height + indicatorArea.spacing));
                                                }
                                                return base;
                                            }

                                            color: {
                                                if (!indicatorArea.parentCfgReady) return Kirigami.Theme.textColor;

                                                let baseColor = TaskTools.resolveIndicatorBaseColor(
                                                    indicatorArea.parentCfg.cfg_indicatorAccentColor,
                                                    indicatorArea.parentCfg.cfg_indicatorDominantColor,
                                                    Kirigami.Theme.highlightColor,
                                                    indicatorArea.parentIndicatorColor,
                                                    indicatorArea.parentCfg.cfg_indicatorCustomColor
                                                );

                                                if (indicatorArea.parentCfg.cfg_indicatorDesaturate && indicatorArea.parentIsMinimized) {
                                                    let c = Qt.color(baseColor)
                                                    return Qt.hsla(c.hslHue, 0.0, c.hslLightness, c.a * 0.5)
                                                }
                                                return baseColor
                                            }

                                            radius: Math.min(width, height) * ((indicatorArea.parentCfgReady ? indicatorArea.parentCfg.cfg_indicatorRadius : 0) / 200)
                                        }
                                    }
                                }

                                // 7. Hover cursor
                                Image {
                                    width: Math.round(Kirigami.Units.gridUnit * 1.5)
                                    height: width
                                    visible: mockTask.isHovered
                                    x: parent.width - width - Kirigami.Units.smallSpacing
                                    y: previewRoot.multiStripe ? 0 : Math.round(parent.height * 0.3)
                                    z: 99

                                    source: "data:image/svg+xml;utf8," +
                                        '<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">' +
                                        '<path d="m3.93 2.75a.9.9 0 0 0 -.362.072.93.93 0 0 0 -.568.73l.002 16.497a1 1 0 0 0 1.299.865l3.076-1.273 1.697 2.27a2.265 2.265 0 0 0 4.092-1.696l-.402-2.805 3.074-1.275q.135-.068.248-.18a1 1 0 0 0 .059-1.35l-11.663-11.665a.92.92 0 0 0 -.552-.189" fill="white"/>' +
                                        '<path d="m4 3.873-.004 15.977 3.352-1.766 2.271 2.73a1.402 1.402 0 0 0 2.389-.988l-.326-3.539 3.619-1.119z" fill="black"/>' +
                                        '</svg>'

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Kirigami.Theme.backgroundColor
                                        shadowBlur: 0.5
                                        shadowHorizontalOffset: 1
                                        shadowVerticalOffset: 1
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }

    // --- Mock Tooltip Simulation ---
    // Anchored to the zoomed task (Index 1)
    Kirigami.ShadowedRectangle {
        id: mockToolTip
        z: 999
        parent: innerPreviewArea

        visible: previewRoot.zoomedTaskItem !== null

        Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
        Kirigami.Theme.inherit: false

        color: Kirigami.Theme.backgroundColor
        radius: 4
        shadow.size: 12
        shadow.color: Qt.rgba(0, 0, 0, 0.3)
        shadow.yOffset: 2

        implicitWidth: mainLayout.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: mainLayout.implicitHeight + Kirigami.Units.smallSpacing * 2

        // Positioning logic based on actual zoomed icon bounds
        readonly property real targetGrow: previewRoot.effectiveGrowSize / 2
        // Positioning logic based on actual visual icon bounds inside the button
        readonly property var targetTask: previewRoot.zoomedTaskItem
        readonly property var targetIcon: targetTask ? targetTask.taskIconItem : null
        
        readonly property real targetX: (targetTask && targetIcon) ? (dummyPanel.x + mockTasksLayout.x + targetTask.x + targetIcon.parent.x + targetIcon.x) : 0
        readonly property real targetY: (targetTask && targetIcon) ? (dummyPanel.y + mockTasksLayout.y + targetTask.y + targetIcon.parent.y + targetIcon.y) : 0
        readonly property real targetW: targetIcon ? targetIcon.width : 0
        readonly property real targetH: targetIcon ? targetIcon.height : 0

        x: {
            let buttonX = targetTask ? (dummyPanel.x + mockTasksLayout.x + targetTask.x) : 0;
            let buttonW = targetTask ? targetTask.width : 0;
            let centerX = buttonX + buttonW / 2;

            if (previewRoot.isVertical) {
                if (previewRoot.simulatedLocation === previewRoot.locationLeft) {
                    return Math.max(targetX + targetW, dummyPanel.x + dummyPanel.width) + Kirigami.Units.smallSpacing;
                } else {
                    return Math.min(targetX, dummyPanel.x) - width - Kirigami.Units.smallSpacing;
                }
            } else {
                return Math.max(Kirigami.Units.smallSpacing, 
                                Math.min(centerX - width / 2, parent.width - width - Kirigami.Units.smallSpacing));
            }
        }

        y: {
            let buttonY = targetTask ? (dummyPanel.y + mockTasksLayout.y + targetTask.y) : 0;
            let buttonH = targetTask ? targetTask.height : 0;
            let centerY = buttonY + buttonH / 2;

            if (!previewRoot.isVertical) {
                if (previewRoot.simulatedLocation === previewRoot.locationBottom) {
                    return Math.min(targetY, dummyPanel.y) - height - Kirigami.Units.smallSpacing;
                } else {
                    return Math.max(targetY + targetH, dummyPanel.y + dummyPanel.height) + Kirigami.Units.smallSpacing;
                }
            } else {
                return Math.max(Kirigami.Units.smallSpacing, 
                                Math.min(centerY - height / 2, parent.height - height - Kirigami.Units.smallSpacing));
            }
        }

        ColumnLayout {
            id: mainLayout
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            // MODE 1: Thumbnail + Overlays (cfg_showToolTips === true)
            ColumnLayout {
                visible: previewRoot.cfg_showToolTips
                spacing: Kirigami.Units.smallSpacing
                
                // 1. App Name Header
                Label {
                    text: Wrappers.i18n("App name")
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    color: Kirigami.Theme.textColor
                    opacity: 1.0
                }

                // 2. Thumbnail Container with Overlays
                Item {
                    id: thumbnailArea
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    Layout.preferredHeight: Math.round(Layout.preferredWidth / 1.6)
                    
                    Rectangle {
                        anchors.fill: parent
                        color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.15)
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
                        radius: 4
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: Qt.resolvedUrl("../ui/assets/preview_thumbnail.png")
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    // Overlay Title (Top-Left)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: Kirigami.Units.smallSpacing
                        
                        height: overlayText.implicitHeight + Kirigami.Units.smallSpacing
                        width: Math.min(overlayText.implicitWidth + Kirigami.Units.mediumSpacing * 2, parent.width - Kirigami.Units.gridUnit * 3)
                        
                        color: Qt.rgba(0, 0, 0, 0.45)
                        radius: 3

                        Label {
                            id: overlayText
                            anchors.centerIn: parent
                            text: Wrappers.i18n("Window title")
                            color: "white"
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                            elide: Text.ElideRight
                            width: parent.width - Kirigami.Units.smallSpacing
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Overlay Close Button (Top-Right)
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Kirigami.Units.smallSpacing
                        width: Kirigami.Units.gridUnit * 1.2
                        height: width
                        color: Qt.rgba(0, 0, 0, 0.45)
                        radius: 3
                        
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            source: "window-close"
                            opacity: 0.9
                            color: "white"
                        }
                    }
                }
            }

            // MODE 2: List/Text-only (cfg_showToolTips === false)
            RowLayout {
                visible: !previewRoot.cfg_showToolTips
                spacing: Kirigami.Units.mediumSpacing
                
                Kirigami.Icon {
                    source: "system-file-manager"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Layout.preferredWidth
                }

                Label {
                    text: Wrappers.i18n("%1 — %2", Wrappers.i18n("Window title"), Wrappers.i18n("App name"))
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                }
            }
        }
    }
}
