import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg

import "../ui/code/singletones"
import "../ui" as FancyUI

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
                
                GridLayout {
                    id: mockTasksLayout
                    anchors.centerIn: parent
                    
                    columns: previewRoot.isVertical ? 1 : -1
                    rows: previewRoot.isVertical ? -1 : 1
                    rowSpacing: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_iconSpacing : 0
                    columnSpacing: previewRoot.cfg_page ? previewRoot.cfg_page.cfg_iconSpacing : 0
                    
                    Repeater {
                        model: 2
                        
                        Item {
                            id: mockTask
                            
                            // Task 0: Not Hovered, Minimized, Running, Progess Demo, Badge Demo
                            // Task 1: Hovered, Active, Running
                            readonly property bool isPinned: false
                            readonly property bool isRunning: true
                            readonly property bool isMinimized: index === 0
                            readonly property bool isActive: index === 1
                            readonly property bool isHovered: index === 1
                            readonly property bool cfgReady: previewRoot.cfg_page !== null
                            
                            // Sizing
                            readonly property bool iconOnly: mockTask.cfgReady ? previewRoot.cfg_page.cfg_iconOnly === 1 : true
                            readonly property bool showText: !mockTask.iconOnly && (!previewRoot.isVertical || previewRoot.simulatedThickness > 80)
                            
                            readonly property real cellWidth: previewRoot.isVertical ? (dummyPanel.width - 4) : (showText ? 140 : dummyPanel.height - 4)
                            readonly property real cellHeight: previewRoot.isVertical ? (showText ? 50 : dummyPanel.width - 4) : (dummyPanel.height - 4)
                            
                            Layout.preferredWidth: cellWidth
                            Layout.preferredHeight: cellHeight
                            
                            // 1. Frame background
                            KSvg.FrameSvgItem {
                                anchors.fill: parent
                                imagePath: (mockTask.cfgReady && previewRoot.cfg_page.cfg_disableButtonSvg) ? "" : "widgets/tasks"
                                enabledBorders: (mockTask.cfgReady && previewRoot.cfg_page.cfg_useBorders) ? (1 | 2 | 4 | 8) : 0
                                prefix: mockTask.isHovered ? 
                                        ((mockTask.cfgReady && previewRoot.cfg_page.cfg_iconOnly && previewRoot.cfg_page.cfg_taskHoverEffect) ? "normal" : "hover") : 
                                        (mockTask.isMinimized && !(previewRoot.cfg_page.cfg_buttonColorize && previewRoot.cfg_page.cfg_buttonColorizeInactive) ? "minimized" : "normal")

                                opacity: 1.0
                                visible: mockTask.cfgReady && !previewRoot.cfg_page.cfg_disableButtonSvg && 
                                        (mockTask.isHovered || previewRoot.cfg_page.cfg_useBorders || mockTask.isMinimized)
                            }
                            
                            // 2. Icon Wrapper
                            Item {
                                id: iconBox
                                width: Math.min(parent.width, parent.height) - 4
                                height: width
                                
                                states: [
                                    State {
                                        name: "standalone"
                                        when: !mockTask.showText
                                        AnchorChanges {
                                            target: iconBox
                                            anchors.left: undefined
                                            anchors.horizontalCenter: mockTask.horizontalCenter
                                            anchors.verticalCenter: mockTask.verticalCenter
                                            anchors.top: undefined
                                        }
                                        PropertyChanges { target: iconBox; anchors.leftMargin: 0; anchors.topMargin: 0 }
                                    },
                                    State {
                                        name: "classic_horizontal"
                                        when: mockTask.showText && !previewRoot.isVertical
                                        AnchorChanges {
                                            target: iconBox
                                            anchors.left: mockTask.left
                                            anchors.horizontalCenter: undefined
                                            anchors.verticalCenter: mockTask.verticalCenter
                                            anchors.top: undefined
                                        }
                                        PropertyChanges { target: iconBox; anchors.leftMargin: Kirigami.Units.smallSpacing; anchors.topMargin: 0 }
                                    },
                                    State {
                                        name: "classic_vertical"
                                        when: mockTask.showText && previewRoot.isVertical
                                        AnchorChanges {
                                            target: iconBox
                                            anchors.top: mockTask.top
                                            anchors.horizontalCenter: mockTask.horizontalCenter
                                            anchors.verticalCenter: undefined
                                            anchors.left: undefined
                                        }
                                        PropertyChanges { target: iconBox; anchors.topMargin: Kirigami.Units.smallSpacing; anchors.leftMargin: 0 }
                                    }
                                ]
                                
                                Kirigami.Icon {
                                    id: taskIcon
                                    roundToIconSize: false
                                    
                                    readonly property bool sizeOverride: mockTask.cfgReady ? previewRoot.cfg_page.cfg_iconSizeOverride : false
                                    readonly property int fixedSize: mockTask.cfgReady ? previewRoot.cfg_page.cfg_iconSizePx : 22
                                    readonly property real iconScalePct: mockTask.cfgReady ? previewRoot.cfg_page.cfg_iconScale / 100 : 1.0
                                    readonly property bool scaleFromEdge: mockTask.cfgReady ? previewRoot.cfg_page.cfg_iconScaleFromEdge : false
                                    readonly property int edgeOffset: mockTask.cfgReady ? previewRoot.cfg_page.cfg_iconEdgeOffset : 0
                                    
                                    readonly property int baseWidth: sizeOverride ? fixedSize : Math.round(parent.width * iconScalePct)
                                    readonly property int baseHeight: sizeOverride ? fixedSize : Math.round(parent.height * iconScalePct)
                                    readonly property real edgeMarginH: scaleFromEdge ? edgeOffset : (parent.width - baseWidth) / 2
                                    readonly property real edgeMarginV: scaleFromEdge ? edgeOffset : (parent.height - baseHeight) / 2
                                    
                                    readonly property int zoom: (mockTask.isHovered && mockTask.cfgReady && previewRoot.cfg_page.cfg_iconOnly && previewRoot.cfg_page.cfg_taskHoverEffect) ? previewRoot.cfg_page.cfg_iconZoomFactor : 0
                                    
                                    width: baseWidth + zoom
                                    height: baseHeight + zoom
                                    source: previewRoot.getIconName(index)
                                    
                                    states: [
                                        State {
                                            name: "center"
                                            when: !taskIcon.scaleFromEdge
                                            AnchorChanges { target: taskIcon; anchors.verticalCenter: iconBox.verticalCenter; anchors.horizontalCenter: iconBox.horizontalCenter; anchors.top: undefined; anchors.bottom: undefined; anchors.left: undefined; anchors.right: undefined }
                                            PropertyChanges { target: taskIcon; anchors.topMargin: 0; anchors.bottomMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                                        },
                                        State {
                                            name: "bottom"
                                            when: taskIcon.scaleFromEdge && previewRoot.simulatedLocation === PlasmaCore.Types.BottomEdge
                                            AnchorChanges { target: taskIcon; anchors.verticalCenter: undefined; anchors.horizontalCenter: iconBox.horizontalCenter; anchors.top: undefined; anchors.bottom: iconBox.bottom; anchors.left: undefined; anchors.right: undefined }
                                            PropertyChanges { target: taskIcon; anchors.bottomMargin: taskIcon.edgeMarginV; anchors.topMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                                        },
                                        State {
                                            name: "top"
                                            when: taskIcon.scaleFromEdge && previewRoot.simulatedLocation === PlasmaCore.Types.TopEdge
                                            AnchorChanges { target: taskIcon; anchors.verticalCenter: undefined; anchors.horizontalCenter: iconBox.horizontalCenter; anchors.top: iconBox.top; anchors.bottom: undefined; anchors.left: undefined; anchors.right: undefined }
                                            PropertyChanges { target: taskIcon; anchors.bottomMargin: 0; anchors.topMargin: taskIcon.edgeMarginV; anchors.leftMargin: 0; anchors.rightMargin: 0 }
                                        },
                                        State {
                                            name: "left"
                                            when: taskIcon.scaleFromEdge && previewRoot.simulatedLocation === PlasmaCore.Types.LeftEdge
                                            AnchorChanges { target: taskIcon; anchors.verticalCenter: iconBox.verticalCenter; anchors.horizontalCenter: undefined; anchors.top: undefined; anchors.bottom: undefined; anchors.left: iconBox.left; anchors.right: undefined }
                                            PropertyChanges { target: taskIcon; anchors.bottomMargin: 0; anchors.topMargin: 0; anchors.leftMargin: taskIcon.edgeMarginH; anchors.rightMargin: 0 }
                                        },
                                        State {
                                            name: "right"
                                            when: taskIcon.scaleFromEdge && previewRoot.simulatedLocation === PlasmaCore.Types.RightEdge
                                            AnchorChanges { target: taskIcon; anchors.verticalCenter: iconBox.verticalCenter; anchors.horizontalCenter: undefined; anchors.top: undefined; anchors.bottom: undefined; anchors.left: undefined; anchors.right: iconBox.right }
                                            PropertyChanges { target: taskIcon; anchors.bottomMargin: 0; anchors.topMargin: 0; anchors.leftMargin: 0; anchors.rightMargin: taskIcon.edgeMarginH }
                                        }
                                    ]
                                    
                                    // Badge Demo (Task 0 only)
                                    FancyUI.Badge {
                                        visible: index === 0 && mockTask.cfgReady && previewRoot.cfg_page.cfg_showBadges
                                        anchors.right: parent.right
                                        anchors.rightMargin: -Math.max(Kirigami.Units.smallSpacing / 2, width / 32)
                                        y: Math.max(0, (parent.height / 2))
                                        height: Math.round(parent.height * 0.4)
                                        number: 3
                                    }
                                    
                                    // Audio Indicator Demo (Task 1 only)
                                    Kirigami.Icon {
                                        visible: index === 1 && mockTask.cfgReady && previewRoot.cfg_page.cfg_indicateAudioStreams
                                        source: "audio-volume-high-symbolic"
                                        width: Math.min(Math.min(parent.width, parent.height) * 0.4, Kirigami.Units.iconSizes.smallMedium)
                                        height: width
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                    }
                                }
                            }

                            // 2.5 Text label
                            Label {
                                id: label
                                visible: mockTask.showText
                                text: previewRoot.fakeNames[index]
                                
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

                            // 4. Progress Overlay (Moved to Index 0)
                            Item {
                                id: progressWrapper
                                anchors.fill: parent
                                visible: mockTask.cfgReady && index === 0
                                
                                readonly property int pStyle: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorProgressStyle : 0
                                readonly property real pProgress: 0.6 // Mock 60% progress

                                // Background filling progress (Style 1)
                                Rectangle {
                                    id: progressBg
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: parent.height * progressWrapper.pProgress
                                    color: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorProgressColor : "transparent"
                                    opacity: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorProgressOpacity / 100.0 : 0
                                    visible: progressWrapper.pStyle === 1
                                }

                                // Edge progress (Style 2, 3)
                                Rectangle {
                                    id: edgeProgress
                                    color: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorProgressColor : "transparent"
                                    opacity: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorProgressOpacity / 100.0 : 0
                                    visible: progressWrapper.pStyle === 2 || progressWrapper.pStyle === 3

                                    readonly property int lineThickness: mockTask.cfgReady ? previewRoot.cfg_page.cfg_indicatorProgressThickness : 2

                                    width: !previewRoot.isVertical ? parent.width * progressWrapper.pProgress : edgeProgress.lineThickness
                                    height: previewRoot.isVertical ? parent.height * progressWrapper.pProgress : edgeProgress.lineThickness

                                    states: [
                                        State {
                                            name: "top"
                                            when: progressWrapper.pStyle === 2 && !previewRoot.isVertical
                                            AnchorChanges { target: edgeProgress; anchors.top: parent.top; anchors.bottom: undefined; anchors.left: parent.left; anchors.right: undefined }
                                        },
                                        State {
                                            name: "bottom"
                                            when: progressWrapper.pStyle === 3 && !previewRoot.isVertical
                                            AnchorChanges { target: edgeProgress; anchors.top: undefined; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: undefined }
                                        },
                                        State {
                                            name: "left"
                                            when: progressWrapper.pStyle === 2 && previewRoot.isVertical
                                            AnchorChanges { target: edgeProgress; anchors.left: parent.left; anchors.right: undefined; anchors.top: undefined; anchors.bottom: parent.bottom }
                                        },
                                        State {
                                            name: "right"
                                            when: progressWrapper.pStyle === 3 && previewRoot.isVertical
                                            AnchorChanges { target: edgeProgress; anchors.left: undefined; anchors.right: parent.right; anchors.top: undefined; anchors.bottom: parent.bottom }
                                        }
                                    ]
                                }
                            }
                            
                            // 5. Mouse Pointer Canvas (Dark variant)
                            Canvas {
                                width: 18
                                height: 28
                                visible: mockTask.isHovered
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: previewRoot.isVertical ? 4 : -4
                                z: 99
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.beginPath();
                                    ctx.moveTo(2, 2);
                                    ctx.lineTo(2, 16);
                                    ctx.lineTo(5, 12);
                                    ctx.lineTo(8, 19);
                                    ctx.lineTo(11, 18);
                                    ctx.lineTo(8, 11);
                                    ctx.lineTo(14, 11);
                                    ctx.closePath();
                                    
                                    // Dark variant with white outline
                                    ctx.fillStyle = "rgba(40,40,40,1.0)";
                                    ctx.fill();
                                    ctx.lineWidth = 1.0;
                                    ctx.strokeStyle = "rgba(255,255,255,1.0)";
                                    ctx.stroke();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
