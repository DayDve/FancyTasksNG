/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "code/tools.js" as TaskTools

Flow {
    id: indicatorsFlow
    spacing: 10
    property int taskCount: 1
    required property var taskItem
    required property var frameSvgItem
    required property var tasksRoot

    readonly property var config: Plasmoid.configuration

    // Max possible cross-axis thickness across all indicator states
    readonly property int maxIndicatorThickness: Math.max(
        config.indicatorSize,
        config.indicatorActiveSize,
        config.indicatorHoverSize,
        config.indicatorGroupSize
    )

    function getActiveChildIndex() {
        if (!indicatorsFlow.taskItem || !indicatorsFlow.taskItem.model) {
            return -1;
        }
        let model = indicatorsFlow.tasksRoot.tasksModel;
        if (!model) {
            return -1;
        }
        let activeTask = model.activeTask;
        if (!activeTask || !activeTask.valid) {
            return -1;
        }
        let index = indicatorsFlow.taskItem.modelIndex();
        if (!index || !index.valid) {
            return -1;
        }

        if (!indicatorsFlow.taskItem.model.IsGroupParent) {
            // For single windows/launchers: check if it's the active task and has no parent
            let activeParent = model.parent(activeTask);
            return (index.row === activeTask.row && (!activeParent || !activeParent.valid)) ? 0 : -1;
        }

        // For grouped tasks: check if the active task's parent matches this task
        let activeParent = model.parent(activeTask);
        if (activeParent && activeParent.valid && activeParent.row === index.row) {
            return activeTask.row;
        }
        return -1;
    }

    Repeater {
        model: {
            if(!indicatorsFlow.config.indicatorsEnabled)
            return 0;
            if(indicatorsFlow.taskItem.isSubTask)//Target only the main task items.
            return 0;
            if(indicatorsFlow.taskItem.taskState === 'launcher') {
                return 0;
            }
            return Math.min((indicatorsFlow.taskCount === 0) ? 1 : indicatorsFlow.taskCount, maxStates);
        }
        readonly property int maxStates: indicatorsFlow.config.indicatorMaxLimit
        
        Item {
            id: segmentWrapper
            required property int index
            readonly property bool isActiveWindow: {
                let activeIdx = indicatorsFlow.getActiveChildIndex();
                if (activeIdx === -1) return false;
                if (index === activeIdx) return true;
                if (index === (maxStates - 1) && activeIdx >= maxStates) return true;
                return false;
            }
            readonly property color decoColor: indicatorsFlow.frameSvgItem.indicatorColor
            readonly property int maxStates: indicatorsFlow.config.indicatorMaxLimit
            readonly property bool isFirst: index === 0
            readonly property int adjust: indicatorsFlow.config.indicatorShrink
            readonly property int indicatorLength: indicatorsFlow.config.indicatorLength
            readonly property int spacing: Kirigami.Units.smallSpacing
            readonly property bool isVertical: {
                if (indicatorsFlow.tasksRoot.vertical && !indicatorsFlow.config.indicatorOverride) {
                    return true;
                }
                if (indicatorsFlow.config.indicatorOverride && (indicatorsFlow.config.indicatorLocation === 1 || indicatorsFlow.config.indicatorLocation === 2)) {
                    return true;
                }
                return false;
            }

            readonly property var computedVar: {
                var colorCalc;
                var colorEval;
                var parentSize = !isVertical ? indicatorsFlow.frameSvgItem.width : indicatorsFlow.frameSvgItem.height;
                var indicatorComputedSize;
                var adjustment = isFirst ? adjust : 0
                var parentSpacingAdjust = indicatorsFlow.taskCount >= 1 && maxStates >= 2 ? (spacing * 2.5) : 0

                colorEval = TaskTools.resolveIndicatorBaseColor(
                    indicatorsFlow.config.indicatorAccentColor,
                    indicatorsFlow.config.indicatorDominantColor,
                    Kirigami.Theme.highlightColor,
                    decoColor,
                    indicatorsFlow.config.indicatorCustomColor
                );

                let segLength = indicatorLength;
                let segSize = indicatorsFlow.config.indicatorSize;

                // 1. Active styling
                if (isActiveWindow) {
                    if (indicatorsFlow.config.indicatorResize) {
                        if (indicatorsFlow.taskCount > 1 && indicatorsFlow.config.indicatorGroupSeparate) {
                            segLength = indicatorsFlow.config.indicatorGroupLength;
                            segSize = indicatorsFlow.config.indicatorGroupSize;
                        } else {
                            segLength = indicatorsFlow.config.indicatorActiveLength;
                            segSize = indicatorsFlow.config.indicatorActiveSize;
                        }
                    }
                }

                // 2. Hover styling
                if (indicatorsFlow.taskItem.containsMouse || indicatorsFlow.taskItem.isHovered) {
                    if (indicatorsFlow.config.indicatorResize) {
                        if (indicatorsFlow.config.indicatorHoverSeparate) {
                            segLength = indicatorsFlow.config.indicatorHoverLength;
                            segSize = indicatorsFlow.config.indicatorHoverSize;
                        } else {
                            if (indicatorsFlow.taskCount > 1 && indicatorsFlow.config.indicatorGroupSeparate) {
                                segLength = indicatorsFlow.config.indicatorGroupLength;
                                segSize = indicatorsFlow.config.indicatorGroupSize;
                            } else {
                                segLength = indicatorsFlow.config.indicatorActiveLength;
                                segSize = indicatorsFlow.config.indicatorActiveSize;
                            }
                        }
                    }
                }

                // If overflow '+' icon is shown, make the last segment a perfect square of size segSize
                if (indicatorsFlow.config.indicatorShowPlus && index === (maxStates - 1) && indicatorsFlow.taskCount > maxStates) {
                    segLength = segSize;
                }

                if(isFirst){
                    let mainSize = (parentSize + parentSpacingAdjust);
                    switch(indicatorsFlow.config.indicatorStyle){
                        case 0: // Line
                        indicatorComputedSize = mainSize - (Math.min(indicatorsFlow.taskCount, maxStates === 1 ? 0 : maxStates)  * (spacing + segLength)) - adjust
                        break
                        case 1: // Dashes
                        indicatorComputedSize = segLength
                        break
                        default:
                        break
                    }
                }
                else {
                    indicatorComputedSize = segLength
                }

                var baseColor = colorEval;

                if(indicatorsFlow.config.indicatorDesaturate && indicatorsFlow.taskItem.taskState === "minimized") {
                    colorCalc = Qt.hsla(baseColor.hslHue, 0.0, baseColor.hslLightness, baseColor.a * 0.5)
                } else {
                    colorCalc = baseColor
                }

                // 1) Highlight active window in group (applies strictly to grouped tasks)
                if (indicatorsFlow.taskCount > 1 && indicatorsFlow.config.indicatorHighlightActive && !isActiveWindow) {
                    let groupOpacity = indicatorsFlow.config.indicatorDimInactive ? (indicatorsFlow.config.indicatorInactiveOpacity / 100.0) : 0.4;
                    colorCalc = Qt.rgba(colorCalc.r, colorCalc.g, colorCalc.b, colorCalc.a * groupOpacity);
                }
                // 2) Global dimming of inactive indicators
                else if (indicatorsFlow.config.indicatorDimInactive && !isActiveWindow) {
                    let inactiveOpacity = indicatorsFlow.config.indicatorInactiveOpacity / 100.0;
                    colorCalc = Qt.rgba(colorCalc.r, colorCalc.g, colorCalc.b, colorCalc.a * inactiveOpacity);
                }

                return {length: indicatorComputedSize, thickness: segSize, colorCalc: colorCalc}
            }

            // Wrapper = base indicatorSize; visual rect overflows when active/hovered
            width: isVertical ? indicatorsFlow.config.indicatorSize : computedVar.length
            height: isVertical ? computedVar.length : indicatorsFlow.config.indicatorSize
            clip: false

            Behavior on height { PropertyAnimation {duration: indicatorsFlow.config.indicatorsAnimated ? 250 : 0} }
            Behavior on width { PropertyAnimation {duration: indicatorsFlow.config.indicatorsAnimated ? 250 : 0} }

            Rectangle {
                id: stateRect

                width: segmentWrapper.isVertical ? segmentWrapper.computedVar.thickness : parent.width
                height: segmentWrapper.isVertical ? parent.height : segmentWrapper.computedVar.thickness

                Behavior on width {
                    enabled: segmentWrapper.isVertical && indicatorsFlow.config.indicatorsAnimated
                    PropertyAnimation { duration: 250 }
                }
                Behavior on height {
                    enabled: !segmentWrapper.isVertical && indicatorsFlow.config.indicatorsAnimated
                    PropertyAnimation { duration: 250 }
                }
                Behavior on color { PropertyAnimation {duration: indicatorsFlow.config.indicatorsAnimated ? 250 : 0} }
                Behavior on radius { PropertyAnimation {duration: indicatorsFlow.config.indicatorsAnimated ? 250 : 0} }
                Behavior on x {
                    enabled: segmentWrapper.isVertical && indicatorsFlow.config.indicatorsAnimated
                    PropertyAnimation { duration: 250 }
                }
                Behavior on y {
                    enabled: !segmentWrapper.isVertical && indicatorsFlow.config.indicatorsAnimated
                    PropertyAnimation { duration: 250 }
                }

                // Cross-axis positioning: 0=Align Top/Left, 1=Align Center, 2=Align Bottom/Right
                x: {
                    if (!segmentWrapper.isVertical) return 0;
                    let diff = indicatorsFlow.config.indicatorSize - width;
                    let a = indicatorsFlow.config.indicatorAlignment;
                    return a === 0 ? 0 : a === 1 ? diff / 2 : diff;
                }
                y: {
                    if (segmentWrapper.isVertical) return 0;
                    let diff = indicatorsFlow.config.indicatorSize - height;
                    let a = indicatorsFlow.config.indicatorAlignment;
                    return a === 0 ? 0 : a === 1 ? diff / 2 : diff;
                }

                color: (indicatorsFlow.config.indicatorShowPlus && (segmentWrapper.index === (segmentWrapper.maxStates - 1)) && (indicatorsFlow.taskCount > segmentWrapper.maxStates)) ? "transparent" : segmentWrapper.computedVar.colorCalc
                radius: Math.min(width, height) * (indicatorsFlow.config.indicatorRadius / 200)

                Item {
                    id: plusIcon
                    anchors.fill: parent
                    visible: indicatorsFlow.config.indicatorShowPlus && (segmentWrapper.index === (segmentWrapper.maxStates - 1)) && (indicatorsFlow.taskCount > segmentWrapper.maxStates)

                    // Horizontal bar of the plus sign
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: Math.max(1, Math.round(parent.height * 0.25))
                        color: segmentWrapper.computedVar.colorCalc
                        radius: height / 2
                    }

                    // Vertical bar of the plus sign
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.max(1, Math.round(parent.width * 0.25))
                        height: parent.height
                        color: segmentWrapper.computedVar.colorCalc
                        radius: width / 2
                    }
                }
            }
        }
    }
    
    states:[
        State {
            name: "bottom"
            when: (indicatorsFlow.config.indicatorOverride && indicatorsFlow.config.indicatorLocation === 0)
                || (!indicatorsFlow.config.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.BottomEdge && !indicatorsFlow.config.indicatorReverse)
                || (!indicatorsFlow.config.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge && indicatorsFlow.config.indicatorReverse)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && indicatorsFlow.config.indicatorLocation === 0)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && !indicatorsFlow.config.indicatorOverride && !indicatorsFlow.config.indicatorReverse)

            AnchorChanges {
                target: indicatorsFlow
                anchors{ top:undefined; bottom:parent.bottom; left:undefined; right:undefined;
                    horizontalCenter:parent.horizontalCenter; verticalCenter:undefined}
                }
            PropertyChanges {
                target: indicatorsFlow
                width: undefined
                height: indicatorsFlow.config.indicatorSize
                
                anchors.topMargin: 0;
                anchors.bottomMargin: indicatorsFlow.config.indicatorEdgeOffset;
                anchors.leftMargin: 0;
                anchors.rightMargin: 0;
            }
        },
        State {
            name: "left"
            when: (indicatorsFlow.config.indicatorOverride && indicatorsFlow.config.indicatorLocation === 1)
                || (!indicatorsFlow.config.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge && !indicatorsFlow.config.indicatorReverse)
                || (!indicatorsFlow.config.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge && indicatorsFlow.config.indicatorReverse)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && indicatorsFlow.config.indicatorLocation === 1 && indicatorsFlow.config.indicatorOverride)

            AnchorChanges {
                target: indicatorsFlow
                anchors{ top:undefined; bottom:undefined; left:parent.left; right:undefined;
                    horizontalCenter:undefined; verticalCenter:parent.verticalCenter}
            }
            PropertyChanges {
                target: indicatorsFlow
                height: undefined
                width: indicatorsFlow.config.indicatorSize
                anchors.topMargin: 0;
                anchors.bottomMargin: 0;
                anchors.leftMargin: indicatorsFlow.config.indicatorEdgeOffset;
                anchors.rightMargin: 0;
            }
        },
        State {
            name: "right"
            when: (indicatorsFlow.config.indicatorOverride && indicatorsFlow.config.indicatorLocation === 2)
                || (!indicatorsFlow.config.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge && !indicatorsFlow.config.indicatorReverse)
                || (!indicatorsFlow.config.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge && indicatorsFlow.config.indicatorReverse)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && indicatorsFlow.config.indicatorLocation === 2 && indicatorsFlow.config.indicatorOverride)

            AnchorChanges {
                target: indicatorsFlow
                anchors{ top:undefined; bottom:undefined; left:undefined; right:parent.right;
                    horizontalCenter:undefined; verticalCenter:parent.verticalCenter}
            }
            PropertyChanges {
                target: indicatorsFlow
                height: undefined
                width: indicatorsFlow.config.indicatorSize
                anchors.topMargin: 0;
                anchors.bottomMargin: 0;
                anchors.leftMargin: 0;
                anchors.rightMargin: indicatorsFlow.config.indicatorEdgeOffset;
            }
        },
        State {
            name: "top"
            when: (indicatorsFlow.config.indicatorOverride && indicatorsFlow.config.indicatorLocation === 3)
                || (!indicatorsFlow.config.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge && !indicatorsFlow.config.indicatorReverse)
                || (!indicatorsFlow.config.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.BottomEdge && indicatorsFlow.config.indicatorReverse)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && indicatorsFlow.config.indicatorLocation === 3 && indicatorsFlow.config.indicatorOverride)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && indicatorsFlow.config.indicatorReverse && !indicatorsFlow.config.indicatorOverride)

            AnchorChanges {
                target: indicatorsFlow
                anchors{ top:parent.top; bottom:undefined; left:undefined; right:undefined;
                    horizontalCenter:parent.horizontalCenter; verticalCenter:undefined}
            }
            PropertyChanges {
                target: indicatorsFlow
                width: undefined
                height: indicatorsFlow.config.indicatorSize
                anchors.topMargin: indicatorsFlow.config.indicatorEdgeOffset;
                anchors.bottomMargin: 0;
                anchors.leftMargin: 0;
                anchors.rightMargin: 0;
            }
        }
    ]
}
