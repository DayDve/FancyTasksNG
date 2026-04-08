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

Item {
    id: previewRoot
    Layout.fillWidth: true
    implicitHeight: Kirigami.Units.gridUnit * 20 // Approx 360px, provides room for tooltip demo

    readonly property int locationBottom: 3
    readonly property int locationTop: 1
    readonly property int locationLeft: 0
    readonly property int locationRight: 2

    property var cfg_page: null
    property var fallbackIcons: ["system-run", "preferences-system"]
    property var fakeNames: ["Konsole", "System Settings"]

    function getIconName(index) {
        if (cfg_page && cfg_page.cfg_launchers && cfg_page.cfg_launchers.length > index) {
            let match = cfg_page.cfg_launchers[index].match(/([^\/:]+)\.desktop$/);
            if (match) return match[1];
        }
        return fallbackIcons[index % fallbackIcons.length];
    }

    function getTaskName(index) {
        if (cfg_page && cfg_page.cfg_launchers && cfg_page.cfg_launchers.length > index) {
            let url = cfg_page.cfg_launchers[index];

            if (url.indexOf("://") !== -1) {
                let name = url.split("://").pop();
                return name.charAt(0).toUpperCase() + name.slice(1);
            }

            let match = url.match(/([^\/:]+)\.desktop$/);
            if (match) {
                let name = match[1].split('.').pop();
                return name.charAt(0).toUpperCase() + name.slice(1);
            }
        }
        return fakeNames[index % fakeNames.length];
    }

    // Panel simulation
    property int currentEdgeIdx: cfg_page ? cfg_page.cfg_previewEdge : 0
    property bool isVertical: currentEdgeIdx === 2 || currentEdgeIdx === 3
    property int simulatedLocation: currentEdgeIdx === 0 ? locationBottom :
                                    currentEdgeIdx === 1 ? locationTop :
                                    currentEdgeIdx === 2 ? locationLeft : locationRight
    property int simulatedThickness: cfg_page ? cfg_page.cfg_previewSize : Math.round(Kirigami.Units.gridUnit * 2.5)

    // Multistripe simulation
    readonly property int taskCountDisplay: 4
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

    readonly property bool iconsOnly: cfg_page ? cfg_page.cfg_iconOnly === 1 : true

    // Shared ImageColors for dominant color preview
    Kirigami.ImageColors {
        id: sharedImageColors
        source: "system-run"
    }
    readonly property color dominantColor: sharedImageColors.dominant
    readonly property color indicatorColor: Kirigami.ColorUtils.tintWithAlpha(dominantColor, Kirigami.Theme.textColor, .38)

    // Theme FrameSvg for authentic margins
    KSvg.FrameSvgItem {
        id: taskFrame
        visible: false
        imagePath: "widgets/tasks"
        prefix: "normal"
    }

    GroupBox {
        id: groupBox
        anchors.fill: parent
        padding: Kirigami.Units.smallSpacing
        topPadding: Kirigami.Units.mediumSpacing // Space for the top row of controls

        // Background / Border of the GroupBox will be handled by the theme
        // but we need to ensure the label is on TOP of it.
    }

    // Standalone label positioned on the GroupBox border
    Label {
        id: titleLabel
        x: groupBox.x + Kirigami.Units.gridUnit
        y: groupBox.y - height / 2
        z: 10
        text: Wrappers.i18n("Preview")
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        color: Kirigami.Theme.textColor

        // Background to "cut" the border
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Kirigami.Units.smallSpacing / 2
            z: -1
            color: Kirigami.Theme.backgroundColor
        }
    }

    ColumnLayout {
        anchors.fill: groupBox
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.largeSpacing

        // 1. Controls at the top
        RowLayout {
            id: controlsLayout
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.mediumSpacing

            Label {
                text: Wrappers.i18n("Location:")
                opacity: 0.6
            }
                ComboBox {
                    id: localEdgeCombo
                    model: [Wrappers.i18n("Bottom"), Wrappers.i18n("Top"), Wrappers.i18n("Left"), Wrappers.i18n("Right")]
                    currentIndex: previewRoot.cfg_page && previewRoot.cfg_page.cfg_previewEdge !== undefined ? previewRoot.cfg_page.cfg_previewEdge : 0
                    onActivated: (index) => { if (previewRoot.cfg_page) previewRoot.cfg_page.cfg_previewEdge = index }
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                }
                Label {
                    text: "   " + Wrappers.i18n("Size:")
                    opacity: 0.6
                }
                SpinBox {
                    id: localSizeSpinner
                    from: 24
                    to: 128
                    value: previewRoot.cfg_page && previewRoot.cfg_page.cfg_previewSize !== undefined ? previewRoot.cfg_page.cfg_previewSize : 48
                    onValueModified: { if (previewRoot.cfg_page) previewRoot.cfg_page.cfg_previewSize = value }
                    stepSize: 2
                    editable: true
                }
                Label {
                    text: "px"
                    opacity: 0.6
                }
            }

            // 2. Inner workspace area
            Rectangle {
                id: innerPreviewArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.05)
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: Kirigami.Units.smallSpacing

                clip: true

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
                        width: (!previewRoot.iconsOnly || previewRoot.isVertical) ? parent.width : implicitWidth
                        height: (!previewRoot.iconsOnly || !previewRoot.isVertical) ? parent.height : implicitHeight
                        clip: false

                        columns: previewRoot.isVertical ? previewRoot.simulatedStripeCount : previewRoot.simulatedOrthogonalCount
                        rows: previewRoot.isVertical ? previewRoot.simulatedOrthogonalCount : previewRoot.simulatedStripeCount

                        rowSpacing: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_taskSpacingSize : 0
                        columnSpacing: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_taskSpacingSize : 0

                        Repeater {
                            id: taskRepeater
                            model: previewRoot.taskCountDisplay

                            Item {
                                id: mockTask

                                readonly property int maxW: (previewRoot.cfg_page ? previewRoot.cfg_page.cfg_maxButtonLength : Kirigami.Units.gridUnit * 10)

                                Layout.preferredWidth: mockTask.showText ? maxW : previewRoot.laneHeight
                                Layout.preferredHeight: previewRoot.laneHeight
                                Layout.maximumWidth: mockTask.showText ? maxW : (previewRoot.isVertical ? previewRoot.simulatedThickness : previewRoot.laneHeight)
                                Layout.maximumHeight: previewRoot.isVertical ? (mockTask.showText ? maxW : previewRoot.laneHeight) : previewRoot.simulatedThickness
                                Layout.fillWidth: previewRoot.isVertical || mockTask.showText
                                Layout.fillHeight: !previewRoot.isVertical || mockTask.showText
                                required property int index

                                readonly property var cfg: previewRoot.cfg_page
                                readonly property bool cfgReady: cfg !== null

                                // Task 0: minimized, progress demo, audio badge
                                // Task 1: hovered, active, count badge
                                readonly property bool isRunning: true
                                readonly property bool isMinimized: mockTask.index === 0
                                readonly property bool isActive: mockTask.index === 1
                                readonly property bool isHovered: mockTask.index === 1
                                readonly property bool isInactive: !isActive && !isHovered

                                // Simulated audio state: Task 0 is playing, Task 2 is muted
                                readonly property bool playingAudio: index === 0
                                readonly property bool isMuted: index === 2
                                readonly property bool hasAudio: playingAudio || isMuted

                                readonly property bool showText: !previewRoot.iconsOnly && (!previewRoot.isVertical || previewRoot.simulatedThickness > (Kirigami.Units.gridUnit * 4))

                                function adjustMargin(size, margin) {
                                    if (!size) return margin;
                                    var totalMargins = taskFrame.margins.top + taskFrame.margins.bottom;
                                    if ((size - totalMargins) < Kirigami.Units.iconSizes.small) {
                                        return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
                                    }
                                    return margin;
                                }

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
                                    readonly property bool hideDueToColorize: mockTask.cfgReady && mockTask.cfg.cfg_buttonColorize && (mockTask.isActive || mockTask.isHovered || (mockTask.isInactive && mockTask.cfg.cfg_buttonColorizeInactive))

                                    visible: !hideDueToDecoration && !hideDueToColorize
                                }

                                // 2. Color overlay
                                MultiEffect {
                                    id: colorOverride
                                    anchors.fill: taskBackground
                                    source: taskBackground

                                    readonly property bool canShow: mockTask.cfgReady && mockTask.cfg.cfg_buttonColorize
                                    readonly property bool isAllowedForInactive: mockTask.isActive || mockTask.isHovered || (mockTask.isInactive && mockTask.cfg.cfg_buttonColorizeInactive)

                                    visible: canShow && isAllowedForInactive && !taskBackground.hideDueToDecoration

                                    colorizationColor: {
                                        if (!mockTask.cfgReady) return "transparent";
                                        return mockTask.cfg.cfg_buttonColorizeDominant ?
                                            previewRoot.indicatorColor : mockTask.cfg.cfg_buttonColorizeCustom;
                                    }
                                    colorization: 1.0
                                }

                                // 3. Progress overlay
                                Item {
                                    id: progressOverlay
                                    anchors.fill: taskBackground
                                    visible: mockTask.index === 0 && mockTask.cfg.cfg_indicatorProgressStyle > 0
                                    opacity: mockTask.cfg.cfg_indicatorProgressOpacity / 100.0

                                    readonly property int pStyle: mockTask.cfg.cfg_indicatorProgressStyle
                                    readonly property real pPosition: 0.7

                                    // Styles 1 & 2: SVG fill
                                    Item {
                                        visible: progressOverlay.pStyle === 1 || progressOverlay.pStyle === 2
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        width: progressOverlay.pStyle === 1 ? parent.width * progressOverlay.pPosition : parent.width
                                        height: progressOverlay.pStyle === 2 ? parent.height * progressOverlay.pPosition : parent.height
                                        clip: true

                                        KSvg.FrameSvgItem {
                                            width: progressOverlay.width
                                            height: progressOverlay.height
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            imagePath: "widgets/tasks"
                                            prefix: TaskTools.taskPrefix("progress", previewRoot.simulatedLocation)
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                colorizationColor: mockTask.cfg.cfg_indicatorProgressColor
                                                colorization: 1.0
                                            }
                                        }
                                    }

                                    // Styles 3-6: Edge strips
                                    Rectangle {
                                        visible: progressOverlay.pStyle >= 3 && progressOverlay.pStyle <= 6
                                        color: mockTask.cfg.cfg_indicatorProgressColor

                                        readonly property int thick: mockTask.cfg.cfg_indicatorProgressThickness
                                        readonly property bool isHoriz: progressOverlay.pStyle === 3 || progressOverlay.pStyle === 4

                                        width: isHoriz ? (parent.width * progressOverlay.pPosition) : thick
                                        height: !isHoriz ? (parent.height * progressOverlay.pPosition) : thick

                                        anchors.top: (progressOverlay.pStyle === 3 || progressOverlay.pStyle === 5 || progressOverlay.pStyle === 6) ? parent.top : undefined
                                        anchors.bottom: (progressOverlay.pStyle === 4) ? parent.bottom : undefined
                                        anchors.left: (progressOverlay.pStyle === 3 || progressOverlay.pStyle === 4 || progressOverlay.pStyle === 5) ? parent.left : undefined
                                        anchors.right: (progressOverlay.pStyle === 6) ? parent.right : undefined
                                    }
                                }

                                // 4. Icon & badges
                                Item {
                                    id: iconBox

                                    readonly property real simulatedMinWidth: previewRoot.isVertical ? iconBox.height : (previewRoot.laneHeight - (Kirigami.Units.smallSpacing / 2))

                                    width: previewRoot.isVertical ? (parent.width - mockTask.adjustMargin(parent.width, taskFrame.margins.left) - mockTask.adjustMargin(parent.width, taskFrame.margins.right)) :
                                                                    (mockTask.showText ? Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium) :
                                                                                Math.min(simulatedMinWidth, parent.width - mockTask.adjustMargin(parent.width, taskFrame.margins.left) - mockTask.adjustMargin(parent.width, taskFrame.margins.right)))
                                    height: parent.height - mockTask.adjustMargin(parent.height, taskFrame.margins.top) - mockTask.adjustMargin(parent.height, taskFrame.margins.bottom) - Kirigami.Units.smallSpacing

                                    anchors {
                                        left: parent.left
                                        top: parent.top
                                        topMargin: mockTask.adjustMargin(parent.height, taskFrame.margins.top) + (Kirigami.Units.smallSpacing / 2)
                                    }

                                    anchors.horizontalCenter: (mockTask.showText || previewRoot.isVertical) ? undefined : parent.horizontalCenter
                                    anchors.leftMargin: (mockTask.showText && !previewRoot.isVertical) ? mockTask.adjustMargin(parent.width, taskFrame.margins.left) : (anchors.horizontalCenter ? 0 : (parent.width - width) / 2)

                                    Kirigami.Icon {
                                        id: taskIcon
                                        readonly property bool sizeOverride: mockTask.cfgReady && mockTask.cfg.cfg_iconSizeOverride
                                        readonly property int fixedSize: mockTask.cfgReady ? mockTask.cfg.cfg_iconSizePx : 32
                                        readonly property real iconScale: mockTask.cfgReady ? mockTask.cfg.cfg_iconScale / 100 : 1.0
                                        readonly property int growSize: (mockTask.isHovered && mockTask.cfg.cfg_iconOnly === 1 && mockTask.cfg.cfg_taskHoverEffect) ? mockTask.cfg.cfg_iconZoomFactor : 0

                                        readonly property bool scaleFromEdge: mockTask.cfgReady && mockTask.cfg.cfg_iconScaleFromEdge
                                        readonly property int edgeOffset: mockTask.cfgReady ? mockTask.cfg.cfg_iconEdgeOffset : 0

                                        readonly property int baseWidth: (sizeOverride ? fixedSize : (iconBox.width * iconScale))
                                        readonly property int baseHeight: (sizeOverride ? fixedSize : (iconBox.height * iconScale))

                                        readonly property real edgeMarginH: scaleFromEdge ? edgeOffset : (parent.width - baseWidth) / 2
                                        readonly property real edgeMarginV: scaleFromEdge ? edgeOffset : (parent.height - baseHeight) / 2

                                        width: baseWidth + growSize
                                        height: baseHeight + growSize

                                        x: {
                                            let loc = previewRoot.simulatedLocation
                                            if (loc === previewRoot.locationLeft) return edgeMarginH
                                            if (loc === previewRoot.locationRight) return parent.width - width - edgeMarginH
                                            return (parent.width - width) / 2
                                        }
                                        y: {
                                            let loc = previewRoot.simulatedLocation
                                            if (loc === previewRoot.locationTop) return edgeMarginV
                                            if (loc === previewRoot.locationBottom) return parent.height - height - edgeMarginV
                                            return (parent.height - height) / 2
                                        }

                                        source: previewRoot.getIconName(mockTask.index)
                                        roundToIconSize: false
                                    }

                                    // Count badge (task 1)
                                    FancyUI.Badge {
                                        visible: mockTask.index === 1 && mockTask.cfgReady && mockTask.cfg.cfg_showBadges
                                        anchors.right: taskIcon.right
                                        anchors.top: taskIcon.top
                                        height: Math.round(taskIcon.height * 0.4)
                                        z: 10
                                        number: 3
                                        isRound: true
                                        hovered: mockTask.isHovered
                                    }

                                }
                                
                                // 5. Audio badge (Moved out of iconBox to match production hierarchy)
                                FancyUI.Badge {
                                    id: audioBadge
                                    visible: mockTask.hasAudio && mockTask.cfgReady && mockTask.cfg.cfg_indicateAudioStreams
                                    z: 50 // Above everything
                                    
                                    // Visual size logic from AudioStream.qml
                                    readonly property int visualSize: Math.round(Math.min(Math.min(iconBox.width, iconBox.height) * 0.4, Kirigami.Units.iconSizes.smallMedium))
                                    height: visualSize
                                    width: visualSize

                                    // Clamping logic relative to mockTask, matching AudioStream.qml exactly
                                    x: Math.max(0, Math.min(mockTask.width - visualSize, iconBox.x + taskIcon.x))
                                    y: Math.max(0, Math.min(mockTask.height - visualSize, iconBox.y + taskIcon.y))

                                    iconSource: mockTask.isMuted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                                    highlightColor: mockTask.isMuted ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
                                    hovered: mockTask.isHovered
                                }

                                // 5. Text label
                                Label {
                                    id: label
                                    visible: mockTask.showText
                                    text: previewRoot.getTaskName(mockTask.index)
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

                                // 6. Indicator
                                Rectangle {
                                    id: indicator
                                    visible: mockTask.cfgReady && mockTask.cfg.cfg_indicatorsEnabled && mockTask.isRunning

                                    readonly property int locMap: (mockTask.cfgReady && mockTask.cfg.cfg_indicatorOverride) ? mockTask.cfg.cfg_indicatorLocation : -1
                                    readonly property int effLoc: locMap !== -1 ? locMap :
                                        (previewRoot.simulatedLocation === previewRoot.locationTop ? 3 :
                                        previewRoot.simulatedLocation === previewRoot.locationLeft ? 1 :
                                        previewRoot.simulatedLocation === previewRoot.locationRight ? 2 : 0)

                                    readonly property bool isVerticalIndicator: effLoc === 1 || effLoc === 2

                                    readonly property int indStyle: mockTask.cfgReady ? mockTask.cfg.cfg_indicatorStyle : 0
                                    readonly property int indLength: mockTask.cfgReady ? mockTask.cfg.cfg_indicatorLength : 8
                                    readonly property int indSize: mockTask.cfgReady ? mockTask.cfg.cfg_indicatorSize : 2
                                    readonly property int indShrink: mockTask.cfgReady ? mockTask.cfg.cfg_indicatorShrink : 0

                                    readonly property real pSize: !isVerticalIndicator ? mockTask.width : mockTask.height
                                    readonly property real computedSize: indStyle === 1 ? indLength : Math.max(8, pSize - indShrink)

                                    width: isVerticalIndicator ? indSize : computedSize
                                    height: isVerticalIndicator ? computedSize : indSize

                                    readonly property int edgeOff: mockTask.cfgReady ? mockTask.cfg.cfg_indicatorEdgeOffset : 0

                                    x: {
                                        if (isVerticalIndicator)
                                            return effLoc === 1 ? edgeOff : parent.width - width - edgeOff
                                        return (parent.width - width) / 2
                                    }
                                    y: {
                                        if (!isVerticalIndicator)
                                            return effLoc === 3 ? edgeOff : parent.height - height - edgeOff
                                        return (parent.height - height) / 2
                                    }

                                    color: {
                                        if (!mockTask.cfgReady) return Kirigami.Theme.textColor;
                                        if (mockTask.cfg.cfg_indicatorDominantColor || mockTask.cfg.cfg_indicatorAccentColor)
                                            return Kirigami.Theme.highlightColor
                                        let baseColor = mockTask.cfg.cfg_indicatorCustomColor

                                        if (mockTask.cfg.cfg_indicatorDesaturate && mockTask.isMinimized) {
                                            let c = Qt.color(baseColor)
                                            return Qt.hsla(c.hslHue, 0.0, c.hslLightness, c.a * 0.5)
                                        }
                                        return baseColor
                                    }

                                    radius: Math.min(width, height) * ((mockTask.cfgReady ? mockTask.cfg.cfg_indicatorRadius : 0) / 200)
                                }

                                // 7. Hover cursor
                                Image {
                                    width: Math.round(Kirigami.Units.gridUnit * 1.5)
                                    height: width
                                    visible: mockTask.isHovered
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.margins: Kirigami.Units.smallSpacing
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
}
