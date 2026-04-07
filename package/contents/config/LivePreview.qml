pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.ksvg as KSvg

import "../ui/code/singletones"
import "../ui" as FancyUI
import "../ui/code/tools.js" as TaskTools
import "../ui/code/layoutmetrics.js" as LayoutMetrics

Item {
    id: previewRoot
    Layout.fillWidth: true
    // Allocate fixed preview playground space
    implicitHeight: 200

    property var cfg_page: null
    property var fallbackIcons: ["system-run", "preferences-system"]
    property var fakeNames: ["Konsole", "System Settings"]

    function getIconName(index) {
        if (cfg_page && previewRoot.cfg_page.cfg_launchers && previewRoot.cfg_page.cfg_launchers.length > index) {
            let url = previewRoot.cfg_page.cfg_launchers[index];
            let match = url.match(/([^\/:]+)\.desktop$/);
            if (match) return match[1];
        }
        return fallbackIcons[index % fallbackIcons.length];
    }
    
    // Panel Mock Settings
    // Mapped edges: 0=Bottom, 1=Top, 2=Left, 3=Right
    property int currentEdgeIdx: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_previewEdge : 0
    property bool isVertical: currentEdgeIdx === 2 || currentEdgeIdx === 3
    property int simulatedLocation: currentEdgeIdx === 0 ? PlasmaCore.Types.BottomEdge :
                                    currentEdgeIdx === 1 ? PlasmaCore.Types.TopEdge :
                                    currentEdgeIdx === 2 ? PlasmaCore.Types.LeftEdge : PlasmaCore.Types.RightEdge
    property int simulatedThickness: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_previewSize : 48

    // Mock objects for LayoutMetrics.js (must be IDs to be visible as globals)
    QtObject {
        id: tasks
        readonly property bool vertical: previewRoot.isVertical
        readonly property bool iconsOnly: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_iconOnly === 1 : true
        // Realistic panel dimensions for the math to work
        readonly property real height: vertical ? 400 : previewRoot.simulatedThickness
        readonly property real width: vertical ? previewRoot.simulatedThickness : 600
        readonly property QtObject plasmoid: QtObject {
            readonly property QtObject configuration: QtObject {
                readonly property real iconSpacing: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_iconSpacing : 1
                readonly property int maxStripes: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_maxStripes : 1
                readonly property int taskMaxWidth: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_taskMaxWidth : 1
            }
        }
    }
    // REAL FrameSvgItem to provide authentic margins from the system theme
    // This eliminates hardcoding and ensures parity with the actual plasmoid
    KSvg.FrameSvgItem {
        id: taskFrame
        visible: false
        imagePath: "widgets/tasks"
        prefix: "normal"
    }

    GroupBox {
        id: groupBox
        anchors.fill: parent
        title: Wrappers.i18n("Preview")
        
        Item {
            anchors.fill: parent

            // Config row in the center of the playground
            Rectangle {
                anchors.centerIn: parent
                z: 99
                color: Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.disabledTextColor
                radius: Kirigami.Units.smallSpacing
                width: controlsLayout.implicitWidth + 16
                height: controlsLayout.implicitHeight + 16

                RowLayout {
                    id: controlsLayout
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing
                    
                    Label { 
                        text: Wrappers.i18n("Location:") 
                        opacity: 0.7
                    }
                    ComboBox {
                        id: localEdgeCombo
                        model: [Wrappers.i18n("Bottom"), Wrappers.i18n("Top"), Wrappers.i18n("Left"), Wrappers.i18n("Right")]
                        currentIndex: previewRoot.cfg_page && previewRoot.cfg_page.cfg_previewEdge !== undefined ? previewRoot.cfg_page.cfg_previewEdge : 0
                        onActivated: (index) => { if (previewRoot.cfg_page) previewRoot.cfg_page.cfg_previewEdge = index }
                        Layout.preferredWidth: 120
                    }
                    Label { 
                        text: "   " + Wrappers.i18n("Size:") 
                        opacity: 0.7
                    }
                    SpinBox {
                        id: localSizeSpinner
                        from: 24
                        to: 128
                        value: previewRoot.cfg_page && previewRoot.cfg_page.cfg_previewSize !== undefined ? previewRoot.cfg_page.cfg_previewSize : 48
                        onValueModified: { if (previewRoot.cfg_page) previewRoot.cfg_page.cfg_previewSize = value }
                        stepSize: 2
                    }
                    Label { 
                        text: "px" 
                        opacity: 0.7
                    }
                }
            }

            // Simulate panel background
            KSvg.FrameSvgItem {
                id: dummyPanel
                
                width: previewRoot.isVertical ? previewRoot.simulatedThickness : parent.width
                height: previewRoot.isVertical ? parent.height : previewRoot.simulatedThickness
                
                imagePath: "widgets/panel-background"
                
                states: [
                    State {
                        name: "bottom"
                        when: previewRoot.simulatedLocation === PlasmaCore.Types.BottomEdge
                        AnchorChanges { target: dummyPanel; anchors.bottom: dummyPanel.parent.bottom; anchors.top: undefined; anchors.left: undefined; anchors.right: undefined; anchors.horizontalCenter: dummyPanel.parent.horizontalCenter; anchors.verticalCenter: undefined }
                    },
                    State {
                        name: "top"
                        when: previewRoot.simulatedLocation === PlasmaCore.Types.TopEdge
                        AnchorChanges { target: dummyPanel; anchors.bottom: undefined; anchors.top: dummyPanel.parent.top; anchors.left: undefined; anchors.right: undefined; anchors.horizontalCenter: dummyPanel.parent.horizontalCenter; anchors.verticalCenter: undefined }
                    },
                    State {
                        name: "left"
                        when: previewRoot.simulatedLocation === PlasmaCore.Types.LeftEdge
                        AnchorChanges { target: dummyPanel; anchors.bottom: undefined; anchors.top: undefined; anchors.left: dummyPanel.parent.left; anchors.right: undefined; anchors.horizontalCenter: undefined; anchors.verticalCenter: dummyPanel.parent.verticalCenter }
                    },
                    State {
                        name: "right"
                        when: previewRoot.simulatedLocation === PlasmaCore.Types.RightEdge
                        AnchorChanges { target: dummyPanel; anchors.bottom: undefined; anchors.top: undefined; anchors.left: undefined; anchors.right: dummyPanel.parent.right; anchors.horizontalCenter: undefined; anchors.verticalCenter: dummyPanel.parent.verticalCenter }
                    }
                ]
                
                Flickable {
                    id: flickable
                    anchors.fill: parent
                    contentWidth: mockTasksLayout.width
                    contentHeight: mockTasksLayout.height
                    interactive: true
                    clip: true
                    
                    GridLayout {
                        id: mockTasksLayout
                        anchors.centerIn: parent
                        
                        columns: previewRoot.isVertical ? 1 : -1
                        rows: previewRoot.isVertical ? -1 : 1
                        rowSpacing: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_taskSpacingSize : 0
                        columnSpacing: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_taskSpacingSize : 0
                    

                    Repeater {
                        id: taskRepeater
                        model: 2
                        
                        Item {
                            id: mockTask
                            required property int index
                            
                            // Task 0: Not Hovered, Minimized, Running, Progess Demo, Badge Demo
                            // Task 1: Hovered, Active, Running
                            readonly property bool isPinned: false
                            readonly property bool isRunning: true
                            readonly property bool isMinimized: mockTask.index === 0
                            readonly property bool isActive: mockTask.index === 1
                            readonly property bool isHovered: mockTask.index === 1
                            readonly property bool cfgReady: previewRoot.cfg_page !== null
                            
                            // Geometry Logic: 1:1 Parity with Task.qml
                            readonly property real marginsV: taskFrame.margins.top + taskFrame.margins.bottom
                            readonly property real marginsH: taskFrame.margins.left + taskFrame.margins.right
                            
                            readonly property bool iconOnly: tasks.iconsOnly
                            readonly property bool showText: !iconOnly && (!previewRoot.isVertical || previewRoot.simulatedThickness > 80)
                            
                            function adjustMargin(isH, size, margin) {
                                if (!size) return margin;
                                var spacing = (mockTask.cfgReady && previewRoot.cfg_page.cfg_iconSpacing !== undefined) ? previewRoot.cfg_page.cfg_iconSpacing : 1;
                                var multiplier = (previewRoot.isVertical ? (isH ? 1 : spacing) : (isH ? spacing : 1));
                                var totalMargins = (isH ? (taskFrame.margins.left + taskFrame.margins.right) : (taskFrame.margins.top + taskFrame.margins.bottom)) * multiplier;
                                
                                if ((size - totalMargins) < Kirigami.Units.iconSizes.small) {
                                    return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
                                }
                                return margin * multiplier;
                            }

                            readonly property real cellWidth: {
                                if (previewRoot.isVertical) return previewRoot.simulatedThickness;
                                if (showText) {
                                     let baseFactor = 1.0;
                                     if (mockTask.cfgReady) {
                                         switch (previewRoot.cfg_page.cfg_taskMaxWidth) {
                                             case 0: baseFactor = 1.2; break;
                                             case 1: baseFactor = 1.6; break;
                                             case 2: baseFactor = 2.0; break;
                                         }
                                     }
                                     const laneHeight = previewRoot.simulatedThickness;
                                     const factorReduction = (Math.min(50, laneHeight) - 20) * 0.01;
                                     const factor = Math.max(1, baseFactor - Math.max(0, factorReduction));
                                     
                                     let minW = (previewRoot.simulatedThickness) + (Kirigami.Units.gridUnit * 8);
                                     return Math.floor(minW * factor);
                                }
                                return previewRoot.simulatedThickness; 
                            }
                            readonly property real cellHeight: {
                                if (previewRoot.isVertical && showText) return Math.max(50, Kirigami.Units.gridUnit * 3);
                                return previewRoot.simulatedThickness;
                            }

                            Layout.preferredWidth: cellWidth
                            Layout.preferredHeight: cellHeight
                            
                            // 1. Frame background
                            KSvg.FrameSvgItem {
                                id: taskBackground
                                anchors.fill: parent
                                imagePath: (mockTask.cfgReady && previewRoot.cfg_page.cfg_disableButtonSvg) ? "" : "widgets/tasks"
                                enabledBorders: (mockTask.cfgReady && previewRoot.cfg_page.cfg_useBorders) ? (1 | 2 | 4 | 8) : 0
                                
                                readonly property string basePrefix: (mockTask.isMinimized && !(previewRoot.cfg_page.cfg_buttonColorize && previewRoot.cfg_page.cfg_buttonColorizeInactive) ? "minimized" : "normal")
                                prefix: mockTask.isHovered ? 
                                    TaskTools.taskPrefixHovered(basePrefix, previewRoot.simulatedLocation) : 
                                    TaskTools.taskPrefix(basePrefix, previewRoot.simulatedLocation)

                                Kirigami.ImageColors {
                                    id: imageColors
                                    source: "system-run" // Mock source for preview
                                }
                                property color dominantColor: imageColors.dominant
                            }

                             // 3. Progress overlay (Unified Implementation)
                              Item {
                                  id: progressOverlay
                                  anchors.fill: taskBackground
                                  // Show progress on the FIRST task (index 0) for clarity
                                  visible: mockTask.index === 0 && previewRoot.cfg_page.cfg_indicatorProgressStyle > 0
                                  opacity: previewRoot.cfg_page.cfg_indicatorProgressOpacity / 100.0

                                  readonly property int pStyle: previewRoot.cfg_page.cfg_indicatorProgressStyle
                                  readonly property real pPosition: 0.7 // Simulated 70% progress

                                  // Styles 1 & 2: Shape/Background Fill (SVG based)
                                  Item {
                                      id: previewFillClip
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
                                              brightness: 1.0
                                              colorizationColor: previewRoot.cfg_page.cfg_indicatorProgressColor
                                              colorization: 1.0
                                          }
                                      }
                                  }

                                  // Styles 3, 4, 5, 6: Edge Strips (Rectangle based)
                                  Rectangle {
                                      id: previewProgressStrip
                                      visible: progressOverlay.pStyle >= 3 && progressOverlay.pStyle <= 6
                                      color: previewRoot.cfg_page.cfg_indicatorProgressColor
                                      
                                      readonly property int thick: previewRoot.cfg_page.cfg_indicatorProgressThickness
                                      readonly property bool isHoriz: progressOverlay.pStyle === 3 || progressOverlay.pStyle === 4
                                      
                                      // Geometry
                                      width: isHoriz ? (parent.width * progressOverlay.pPosition) : thick
                                      height: !isHoriz ? (parent.height * progressOverlay.pPosition) : thick

                                      // Anchors
                                      anchors.top: (progressOverlay.pStyle === 3 || progressOverlay.pStyle === 5 || progressOverlay.pStyle === 6) ? parent.top : undefined
                                      anchors.bottom: (progressOverlay.pStyle === 4) ? parent.bottom : undefined
                                      anchors.left: (progressOverlay.pStyle === 3 || progressOverlay.pStyle === 4 || progressOverlay.pStyle === 5) ? parent.left : undefined
                                      anchors.right: (progressOverlay.pStyle === 6) ? parent.right : undefined
                                  }
                              }

                             // 4. Icon & Badge Container (AUTHENTIC Task.qml logic)
                             Item {
                                 id: iconBox
                                 
                                 width: previewRoot.isVertical ? (parent.width - adjustMargin(true, parent.width, taskFrame.margins.left) - adjustMargin(true, parent.width, taskFrame.margins.right)) :
                                                                 (showText ? Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium) :
                                                                             (parent.width - adjustMargin(true, parent.width, taskFrame.margins.left) - adjustMargin(true, parent.width, taskFrame.margins.right)))
                                 height: parent.height - adjustMargin(false, parent.height, taskFrame.margins.top) - adjustMargin(false, parent.height, taskFrame.margins.bottom)
                                 
                                 anchors {
                                     left: parent.left
                                     top: parent.top
                                     topMargin: adjustMargin(false, parent.height, taskFrame.margins.top)
                                 }
                                 
                                 // Horizontal Centering for Dock Mode (Icons Only)
                                 anchors.horizontalCenter: (showText || previewRoot.isVertical) ? undefined : parent.horizontalCenter
                                 anchors.leftMargin: (showText && !previewRoot.isVertical) ? adjustMargin(true, parent.width, taskFrame.margins.left) : (anchors.horizontalCenter ? 0 : (parent.width - width) / 2)

                                 // Main Icon (Inside Container)
                                 Kirigami.Icon {
                                     id: taskIcon
                                     readonly property bool sizeOverride: mockTask.cfgReady && previewRoot.cfg_page.cfg_iconSizeOverride
                                     readonly property int fixedSize: mockTask.cfgReady ? previewRoot.cfg_page.cfg_iconSizePx : 32
                                     readonly property real iconScale: mockTask.cfgReady ? previewRoot.cfg_page.cfg_iconScale / 100 : 1.0
                                     readonly property int growSize: (mockTask.isHovered && previewRoot.cfg_page.cfg_iconOnly === 1 && previewRoot.cfg_page.cfg_taskHoverEffect) ? previewRoot.cfg_page.cfg_iconZoomFactor : 0

                                     readonly property bool scaleFromEdge: mockTask.cfgReady && previewRoot.cfg_page.cfg_iconScaleFromEdge
                                     readonly property int edgeOffset: mockTask.cfgReady ? previewRoot.cfg_page.cfg_iconEdgeOffset : 0

                                     readonly property int baseWidth: (sizeOverride ? fixedSize : (iconBox.width * iconScale))
                                     readonly property int baseHeight: (sizeOverride ? fixedSize : (iconBox.height * iconScale))
                                     
                                     readonly property real edgeMarginH: scaleFromEdge ? edgeOffset : (parent.width - baseWidth) / 2
                                     readonly property real edgeMarginV: scaleFromEdge ? edgeOffset : (parent.height - baseHeight) / 2

                                     width: baseWidth + growSize
                                     height: baseHeight + growSize
                                     
                                     // Default anchors (fallback/bottom edge)
                                     anchors.horizontalCenter: parent.horizontalCenter
                                     anchors.bottom: parent.bottom
                                     anchors.bottomMargin: edgeMarginV

                                     states: [
                                         State {
                                             name: "top"
                                             when: previewRoot.simulatedLocation === PlasmaCore.Types.TopEdge
                                             AnchorChanges { target: taskIcon; anchors.top: parent.top; anchors.bottom: undefined; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: undefined; anchors.left: undefined; anchors.right: undefined }
                                             PropertyChanges { target: taskIcon; anchors.topMargin: taskIcon.edgeMarginV; anchors.bottomMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                                         },
                                         State {
                                             name: "left"
                                             when: previewRoot.simulatedLocation === PlasmaCore.Types.LeftEdge
                                             AnchorChanges { target: taskIcon; anchors.left: parent.left; anchors.right: undefined; anchors.verticalCenter: parent.verticalCenter; anchors.horizontalCenter: undefined; anchors.top: undefined; anchors.bottom: undefined }
                                             PropertyChanges { target: taskIcon; anchors.leftMargin: taskIcon.edgeMarginH; anchors.rightMargin: 0; anchors.topMargin: 0; anchors.bottomMargin: 0 }
                                         },
                                         State {
                                             name: "right"
                                             when: previewRoot.simulatedLocation === PlasmaCore.Types.RightEdge
                                             AnchorChanges { target: taskIcon; anchors.right: parent.right; anchors.left: undefined; anchors.verticalCenter: parent.verticalCenter; anchors.horizontalCenter: undefined; anchors.top: undefined; anchors.bottom: undefined }
                                             PropertyChanges { target: taskIcon; anchors.rightMargin: taskIcon.edgeMarginH; anchors.leftMargin: 0; anchors.topMargin: 0; anchors.bottomMargin: 0 }
                                         },
                                         State {
                                             name: "bottom"
                                             when: previewRoot.simulatedLocation === PlasmaCore.Types.BottomEdge
                                             AnchorChanges { target: taskIcon; anchors.bottom: parent.bottom; anchors.top: undefined; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: undefined; anchors.left: undefined; anchors.right: undefined }
                                             PropertyChanges { target: taskIcon; anchors.bottomMargin: taskIcon.edgeMarginV; anchors.topMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                                         }
                                     ]

                                     source: previewRoot.getIconName(mockTask.index)
                                     roundToIconSize: false
                                 }

                                 // Badge Overlay Simulator (Task 1 only)
                                 Item {
                                     id: badgeOverlay
                                     anchors.fill: taskIcon
                                     visible: mockTask.index === 1 && mockTask.cfgReady && previewRoot.cfg_page.cfg_showBadges
                                     z: 10

                                     FancyUI.Badge {
                                         anchors.right: parent.right
                                         anchors.top: parent.top
                                         anchors.rightMargin: 0
                                         anchors.topMargin: 0
                                         height: Math.round(parent.height * 0.4)
                                         number: 3
                                         isRound: true
                                         hovered: mockTask.isHovered
                                     }
                                 }

                                 // Audio Indicator Demo (Task 0 only)
                                 FancyUI.Badge {
                                     visible: mockTask.index === 0 && mockTask.cfgReady && previewRoot.cfg_page.cfg_indicateAudioStreams
                                     anchors.left: taskIcon.left
                                     anchors.top: taskIcon.top
                                     
                                     height: Math.round(iconBox.height * 0.4 * (taskIcon.width / taskIcon.baseWidth))
                                     z: 10
                                     
                                     iconSource: "audio-volume-muted-symbolic"
                                     highlightColor: Kirigami.Theme.negativeTextColor
                                     hovered: mockTask.isHovered
                                     
                                     anchors.leftMargin: -Math.max(Kirigami.Units.smallSpacing / 2, width / 32)
                                     anchors.topMargin: -Math.max(Kirigami.Units.smallSpacing / 2, height / 32)
                                 }
                             }

                             // 2.5 Text label
                             PlasmaComponents3.Label {
                                 id: label
                                 visible: mockTask.showText
                                 text: previewRoot.fakeNames[mockTask.index]
                                 
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
                                 horizontalAlignment: previewRoot.isVertical ? Text.AlignHCenter : Text.AlignLeft
                                 maximumLineCount: 1
                                 // Force white text if simulating a panel in a Light KCM, 
                                 // or follow KCM theme if it's already Dark.
                                 color: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark ? Kirigami.Theme.textColor : "#ffffff"
                             }
                            
                            // 3. Indicator
                            Rectangle {
                                id: indicator
                                visible: mockTask.cfgReady && previewRoot.cfg_page.cfg_indicatorsEnabled && mockTask.isRunning
                                
                                readonly property int locMap: (mockTask.cfgReady && previewRoot.cfg_page.cfg_indicatorOverride) ? previewRoot.cfg_page.cfg_indicatorLocation : -1
                                readonly property int effLoc: locMap !== -1 ? locMap : 
                                    (previewRoot.simulatedLocation === PlasmaCore.Types.TopEdge ? 3 :
                                    previewRoot.simulatedLocation === PlasmaCore.Types.LeftEdge ? 1 :
                                    previewRoot.simulatedLocation === PlasmaCore.Types.RightEdge ? 2 : 0) // default bottom
                                    
                                readonly property bool isVerticalIndicator: effLoc === 1 || effLoc === 2
                                
                                readonly property int indStyle: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorStyle : 0
                                readonly property int indLength: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorLength : 8
                                readonly property int indSize: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorSize : 2
                                readonly property int indShrink: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorShrink : 0
                                
                                readonly property real pSize: !isVerticalIndicator ? mockTask.width : mockTask.height
                                readonly property real spaceAdj: 0 
                                
                                readonly property real computedSize: indStyle === 1 /* Dashes */ ? indLength : Math.max(8, pSize + spaceAdj - indShrink)
                                
                                width: isVerticalIndicator ? indSize : computedSize
                                height: isVerticalIndicator ? computedSize : indSize
                                
                                readonly property int edgeOff: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorEdgeOffset : 0
                                
                                states: [
                                    State {
                                        name: "bottom"
                                        when: indicator.effLoc === 0
                                        AnchorChanges { target: indicator; anchors.bottom: mockTask.bottom; anchors.top: undefined; anchors.horizontalCenter: mockTask.horizontalCenter; anchors.verticalCenter: undefined; anchors.left: undefined; anchors.right: undefined }
                                        PropertyChanges { target: indicator; anchors.bottomMargin: indicator.edgeOff; anchors.topMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                                    },
                                    State {
                                        name: "left"
                                        when: indicator.effLoc === 1
                                        AnchorChanges { target: indicator; anchors.bottom: undefined; anchors.top: undefined; anchors.horizontalCenter: undefined; anchors.verticalCenter: mockTask.verticalCenter; anchors.left: mockTask.left; anchors.right: undefined }
                                        PropertyChanges { target: indicator; anchors.bottomMargin: 0; anchors.topMargin: 0; anchors.leftMargin: indicator.edgeOff; anchors.rightMargin: 0 }
                                    },
                                    State {
                                        name: "right"
                                        when: indicator.effLoc === 2
                                        AnchorChanges { target: indicator; anchors.bottom: undefined; anchors.top: undefined; anchors.horizontalCenter: undefined; anchors.verticalCenter: mockTask.verticalCenter; anchors.left: undefined; anchors.right: mockTask.right }
                                        PropertyChanges { target: indicator; anchors.bottomMargin: 0; anchors.topMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: indicator.edgeOff }
                                    },
                                    State {
                                        name: "top"
                                        when: indicator.effLoc === 3
                                        AnchorChanges { target: indicator; anchors.bottom: undefined; anchors.top: mockTask.top; anchors.horizontalCenter: mockTask.horizontalCenter; anchors.verticalCenter: undefined; anchors.left: undefined; anchors.right: undefined }
                                        PropertyChanges { target: indicator; anchors.bottomMargin: 0; anchors.topMargin: indicator.edgeOff; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                                    }
                                ]
                                
                                color: {
                                    if (!mockTask.cfgReady) return "#FFFFFF";
                                    let baseColor = "#FFFFFF"
                                    if (previewRoot.cfg_page.cfg_indicatorDominantColor) {
                                        baseColor = Kirigami.Theme.highlightColor
                                    } else if (previewRoot.cfg_page.cfg_indicatorAccentColor) {
                                        baseColor = Kirigami.Theme.highlightColor
                                    } else {
                                        baseColor = previewRoot.cfg_page.cfg_indicatorCustomColor
                                    }
                                    
                                    if (previewRoot.cfg_page.cfg_indicatorDesaturate && mockTask.isMinimized) {
                                        let c = Qt.color(baseColor)
                                        return Qt.hsla(c.hslHue, 0.0, c.hslLightness, c.a * 0.5)
                                    }
                                    return baseColor
                                }
                                
                                radius: Math.min(width, height) * ((mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorRadius : 0) / 200)
                            }

                            
                            // 5. Native-style cursor image (Embedded Breeze SVG for stability)
                            Image {
                                id: previewCursor
                                width: Math.round(Kirigami.Units.gridUnit * 1.5)
                                height: width
                                visible: mockTask.isHovered
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: Kirigami.Units.smallSpacing
                                z: 99
                                
                                // Authentic Breeze Cursor Path
                                source: "data:image/svg+xml;utf8," + 
                                    '<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">' +
                                    '<path d="m3.93 2.75a.9.9 0 0 0 -.362.072.93.93 0 0 0 -.568.73l.002 16.497a1 1 0 0 0 1.299.865l3.076-1.273 1.697 2.27a2.265 2.265 0 0 0 4.092-1.696l-.402-2.805 3.074-1.275q.135-.068.248-.18a1 1 0 0 0 .059-1.35l-11.663-11.665a.92.92 0 0 0 -.552-.189" fill="white"/>' +
                                    '<path d="m4 3.873-.004 15.977 3.352-1.766 2.271 2.73a1.402 1.402 0 0 0 2.389-.988l-.326-3.539 3.619-1.119z" fill="black"/>' +
                                    '</svg>'

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowColor: "black"
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
