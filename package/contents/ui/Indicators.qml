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
    required property var task
    required property var frame
    required property var tasksRoot

    // Max possible cross-axis thickness across all indicator states
    readonly property int maxIndicatorThickness: Math.max(
        Plasmoid.configuration.indicatorSize,
        Plasmoid.configuration.indicatorActiveSize,
        Plasmoid.configuration.indicatorHoverSize,
        Plasmoid.configuration.indicatorGroupSize
    )

    function getActiveChildIndex() {
        if (!indicatorsFlow.task || !indicatorsFlow.task.model) {
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
        let index = indicatorsFlow.task.modelIndex();
        if (!index || !index.valid) {
            return -1;
        }

        if (!indicatorsFlow.task.model.IsGroupParent) {
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
            if(!Plasmoid.configuration.indicatorsEnabled)
            return 0;
            if(indicatorsFlow.task.isSubTask)//Target only the main task items.
            return 0;
            if(indicatorsFlow.task.taskState === 'launcher') {
                return 0;
            }
            return Math.min((indicatorsFlow.taskCount === 0) ? 1 : indicatorsFlow.taskCount, maxStates);
        }
        readonly property int maxStates: Plasmoid.configuration.indicatorMaxLimit
        
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
            readonly property color decoColor: indicatorsFlow.frame.indicatorColor
            readonly property int maxStates: Plasmoid.configuration.indicatorMaxLimit
            readonly property bool isFirst: index === 0
            readonly property int adjust: Plasmoid.configuration.indicatorShrink
            readonly property int indicatorLength: Plasmoid.configuration.indicatorLength
            readonly property int spacing: Kirigami.Units.smallSpacing
            readonly property bool isVertical: {
                if (indicatorsFlow.tasksRoot.vertical && !Plasmoid.configuration.indicatorOverride) {
                    return true;
                }
                if (Plasmoid.configuration.indicatorOverride && (Plasmoid.configuration.indicatorLocation === 1 || Plasmoid.configuration.indicatorLocation === 2)) {
                    return true;
                }
                return false;
            }

            readonly property var computedVar: {
                var colorCalc;
                var colorEval;
                var parentSize = !isVertical ? indicatorsFlow.frame.width : indicatorsFlow.frame.height;
                var indicatorComputedSize;
                var adjustment = isFirst ? adjust : 0
                var parentSpacingAdjust = indicatorsFlow.taskCount >= 1 && maxStates >= 2 ? (spacing * 2.5) : 0

                colorEval = TaskTools.resolveIndicatorBaseColor(
                    Plasmoid.configuration.indicatorAccentColor,
                    Plasmoid.configuration.indicatorDominantColor,
                    Kirigami.Theme.highlightColor,
                    decoColor,
                    Plasmoid.configuration.indicatorCustomColor
                );

                let segLength = indicatorLength;
                let segSize = Plasmoid.configuration.indicatorSize;

                // 1. Active styling
                if (isActiveWindow) {
                    if (Plasmoid.configuration.indicatorResize) {
                        if (indicatorsFlow.taskCount > 1 && Plasmoid.configuration.indicatorGroupSeparate) {
                            segLength = Plasmoid.configuration.indicatorGroupLength;
                            segSize = Plasmoid.configuration.indicatorGroupSize;
                        } else {
                            segLength = Plasmoid.configuration.indicatorActiveLength;
                            segSize = Plasmoid.configuration.indicatorActiveSize;
                        }
                    }
                }

                // 2. Hover styling
                if (indicatorsFlow.task.containsMouse || indicatorsFlow.task.isHovered) {
                    if (Plasmoid.configuration.indicatorResize) {
                        if (Plasmoid.configuration.indicatorHoverSeparate) {
                            segLength = Plasmoid.configuration.indicatorHoverLength;
                            segSize = Plasmoid.configuration.indicatorHoverSize;
                        } else {
                            if (indicatorsFlow.taskCount > 1 && Plasmoid.configuration.indicatorGroupSeparate) {
                                segLength = Plasmoid.configuration.indicatorGroupLength;
                                segSize = Plasmoid.configuration.indicatorGroupSize;
                            } else {
                                segLength = Plasmoid.configuration.indicatorActiveLength;
                                segSize = Plasmoid.configuration.indicatorActiveSize;
                            }
                        }
                    }
                }

                // If overflow '+' icon is shown, make the last segment a perfect square of size segSize
                if (Plasmoid.configuration.indicatorShowPlus && index === (maxStates - 1) && indicatorsFlow.taskCount > maxStates) {
                    segLength = segSize;
                }

                if(isFirst){
                    let mainSize = (parentSize + parentSpacingAdjust);
                    switch(Plasmoid.configuration.indicatorStyle){
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

                if(Plasmoid.configuration.indicatorDesaturate && indicatorsFlow.task.taskState === "minimized") {
                    colorCalc = Qt.hsla(baseColor.hslHue, 0.0, baseColor.hslLightness, baseColor.a * 0.5)
                } else {
                    colorCalc = baseColor
                }

                // If there are multiple segments (grouped task) and highlight is enabled, apply 40% opacity to non-active segments to highlight the active one
                if (indicatorsFlow.taskCount > 1 && Plasmoid.configuration.indicatorHighlightActive && !isActiveWindow) {
                    colorCalc = Qt.rgba(colorCalc.r, colorCalc.g, colorCalc.b, colorCalc.a * 0.4)
                }

                return {length: indicatorComputedSize, thickness: segSize, colorCalc: colorCalc}
            }

            // Wrapper = base indicatorSize; visual rect overflows when active/hovered
            width: isVertical ? Plasmoid.configuration.indicatorSize : computedVar.length
            height: isVertical ? computedVar.length : Plasmoid.configuration.indicatorSize
            clip: false

            Behavior on height { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
            Behavior on width { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }

            Rectangle {
                id: stateRect

                width: segmentWrapper.isVertical ? segmentWrapper.computedVar.thickness : parent.width
                height: segmentWrapper.isVertical ? parent.height : segmentWrapper.computedVar.thickness

                Behavior on height { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on width { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on color { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on radius { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on y { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on x { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }

                // Cross-axis positioning: 0=top/left, 1=center, 2=bottom/right
                x: {
                    if (!segmentWrapper.isVertical) return 0;
                    let diff = Plasmoid.configuration.indicatorSize - width;
                    let isGroupActive = indicatorsFlow.taskCount > 1 && segmentWrapper.isActiveWindow && Plasmoid.configuration.indicatorResize;
                    if (!isGroupActive) return 0;
                    let a = Plasmoid.configuration.indicatorAlignment;
                    return a === 0 ? 0 : a === 1 ? diff / 2 : diff;
                }
                y: {
                    if (segmentWrapper.isVertical) return 0;
                    let diff = Plasmoid.configuration.indicatorSize - height;
                    let isGroupActive = indicatorsFlow.taskCount > 1 && segmentWrapper.isActiveWindow && Plasmoid.configuration.indicatorResize;
                    if (!isGroupActive) return 0;
                    let a = Plasmoid.configuration.indicatorAlignment;
                    return a === 0 ? 0 : a === 1 ? diff / 2 : diff;
                }

                color: (Plasmoid.configuration.indicatorShowPlus && (segmentWrapper.index === (segmentWrapper.maxStates - 1)) && (indicatorsFlow.taskCount > segmentWrapper.maxStates)) ? "transparent" : segmentWrapper.computedVar.colorCalc
                radius: Math.min(width, height) * (Plasmoid.configuration.indicatorRadius / 200)

                Item {
                    id: plusIcon
                    anchors.fill: parent
                    visible: Plasmoid.configuration.indicatorShowPlus && (segmentWrapper.index === (segmentWrapper.maxStates - 1)) && (indicatorsFlow.taskCount > segmentWrapper.maxStates)

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
            when: (Plasmoid.configuration.indicatorOverride && Plasmoid.configuration.indicatorLocation === 0)
                || (!Plasmoid.configuration.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.BottomEdge && !Plasmoid.configuration.indicatorReverse)
                || (!Plasmoid.configuration.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge && Plasmoid.configuration.indicatorReverse)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorLocation === 0)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && !Plasmoid.configuration.indicatorOverride && !Plasmoid.configuration.indicatorReverse)

            AnchorChanges {
                target: indicatorsFlow
                anchors{ top:undefined; bottom:parent.bottom; left:undefined; right:undefined;
                    horizontalCenter:parent.horizontalCenter; verticalCenter:undefined}
                }
            PropertyChanges {
                target: indicatorsFlow
                width: undefined
                height: Plasmoid.configuration.indicatorSize
                
                anchors.topMargin: 0;
                anchors.bottomMargin: Plasmoid.configuration.indicatorEdgeOffset;
                anchors.leftMargin: 0;
                anchors.rightMargin: 0;
            }
        },
        State {
            name: "left"
            when: (Plasmoid.configuration.indicatorOverride && Plasmoid.configuration.indicatorLocation === 1)
                || (!Plasmoid.configuration.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge && !Plasmoid.configuration.indicatorReverse)
                || (!Plasmoid.configuration.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge && Plasmoid.configuration.indicatorReverse)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorLocation === 1 && Plasmoid.configuration.indicatorOverride)

            AnchorChanges {
                target: indicatorsFlow
                anchors{ top:undefined; bottom:undefined; left:parent.left; right:undefined;
                    horizontalCenter:undefined; verticalCenter:parent.verticalCenter}
            }
            PropertyChanges {
                target: indicatorsFlow
                height: undefined
                width: Plasmoid.configuration.indicatorSize
                anchors.topMargin: 0;
                anchors.bottomMargin: 0;
                anchors.leftMargin: Plasmoid.configuration.indicatorEdgeOffset;
                anchors.rightMargin: 0;
            }
        },
        State {
            name: "right"
            when: (Plasmoid.configuration.indicatorOverride && Plasmoid.configuration.indicatorLocation === 2)
                || (!Plasmoid.configuration.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge && !Plasmoid.configuration.indicatorReverse)
                || (!Plasmoid.configuration.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge && Plasmoid.configuration.indicatorReverse)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorLocation === 2 && Plasmoid.configuration.indicatorOverride)

            AnchorChanges {
                target: indicatorsFlow
                anchors{ top:undefined; bottom:undefined; left:undefined; right:parent.right;
                    horizontalCenter:undefined; verticalCenter:parent.verticalCenter}
            }
            PropertyChanges {
                target: indicatorsFlow
                height: undefined
                width: Plasmoid.configuration.indicatorSize
                anchors.topMargin: 0;
                anchors.bottomMargin: 0;
                anchors.leftMargin: 0;
                anchors.rightMargin: Plasmoid.configuration.indicatorEdgeOffset;
            }
        },
        State {
            name: "top"
            when: (Plasmoid.configuration.indicatorOverride && Plasmoid.configuration.indicatorLocation === 3)
                || (!Plasmoid.configuration.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge && !Plasmoid.configuration.indicatorReverse)
                || (!Plasmoid.configuration.indicatorOverride && indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.BottomEdge && Plasmoid.configuration.indicatorReverse)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorLocation === 3 && Plasmoid.configuration.indicatorOverride)
                || (indicatorsFlow.tasksRoot.effectiveLocation === PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorReverse && !Plasmoid.configuration.indicatorOverride)

            AnchorChanges {
                target: indicatorsFlow
                anchors{ top:parent.top; bottom:undefined; left:undefined; right:undefined;
                    horizontalCenter:parent.horizontalCenter; verticalCenter:undefined}
            }
            PropertyChanges {
                target: indicatorsFlow
                width: undefined
                height: Plasmoid.configuration.indicatorSize
                anchors.topMargin: Plasmoid.configuration.indicatorEdgeOffset;
                anchors.bottomMargin: 0;
                anchors.leftMargin: 0;
                anchors.rightMargin: 0;
            }
        }
    ]
}
