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

    readonly property var config: indicatorsFlow.tasksRoot.config

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

            readonly property bool hovered: indicatorsFlow.taskItem.containsMouse || indicatorsFlow.taskItem.isHovered
            // The last segment turns into a "+" when there are more windows than segments.
            readonly property bool showsPlus: indicatorsFlow.config.indicatorShowPlus && index === maxStates - 1 && indicatorsFlow.taskCount > maxStates

            // [length, thickness] of a segment in its state: the hover size if
            // it has its own, else the group or active size, else the base one.
            readonly property var segmentSize: {
                const cfg = indicatorsFlow.config;
                let size = [indicatorLength, cfg.indicatorSize];
                if (cfg.indicatorResize && (isActiveWindow || hovered)) {
                    if (hovered && cfg.indicatorHoverSeparate) {
                        size = [cfg.indicatorHoverLength, cfg.indicatorHoverSize];
                    } else if (indicatorsFlow.taskCount > 1 && cfg.indicatorGroupSeparate) {
                        size = [cfg.indicatorGroupLength, cfg.indicatorGroupSize];
                    } else {
                        size = [cfg.indicatorActiveLength, cfg.indicatorActiveSize];
                    }
                }
                // The "+" sits in a square.
                if (showsPlus) {
                    size[0] = size[1];
                }
                return size;
            }
            readonly property real thickness: segmentSize[1]

            // In the line style the first segment takes up what the others leave.
            readonly property real segmentLength: {
                const length = segmentSize[0];
                if (!isFirst || indicatorsFlow.config.indicatorStyle !== 0) {
                    return length;
                }
                const parentSize = !isVertical ? indicatorsFlow.frameSvgItem.width : indicatorsFlow.frameSvgItem.height;
                const parentSpacingAdjust = indicatorsFlow.taskCount >= 1 && maxStates >= 2 ? (spacing * 2.5) : 0;
                return parentSize + parentSpacingAdjust - (Math.min(indicatorsFlow.taskCount, maxStates === 1 ? 0 : maxStates) * (spacing + length)) - adjust;
            }

            readonly property color segmentColor: {
                const cfg = indicatorsFlow.config;
                let color = TaskTools.resolveIndicatorBaseColor(cfg.indicatorAccentColor, cfg.indicatorDominantColor,
                                                                Kirigami.Theme.highlightColor, decoColor, cfg.indicatorCustomColor);
                if (cfg.indicatorDesaturate && indicatorsFlow.taskItem.taskState === "minimized") {
                    color = Qt.hsla(color.hslHue, 0.0, color.hslLightness, color.a * 0.5);
                }
                if (isActiveWindow) {
                    return color;
                }
                // Inactive windows of a group are dimmed with "highlight active"
                // on, and every inactive indicator with "dim inactive" on.
                let opacity = 1;
                if (indicatorsFlow.taskCount > 1 && cfg.indicatorHighlightActive) {
                    opacity = cfg.indicatorDimInactive ? (cfg.indicatorInactiveOpacity / 100.0) : 0.4;
                } else if (cfg.indicatorDimInactive) {
                    opacity = cfg.indicatorInactiveOpacity / 100.0;
                }
                return Qt.rgba(color.r, color.g, color.b, color.a * opacity);
            }

            // Wrapper = base indicatorSize; visual rect overflows when active/hovered
            width: isVertical ? indicatorsFlow.config.indicatorSize : segmentLength
            height: isVertical ? segmentLength : indicatorsFlow.config.indicatorSize
            clip: false

            Behavior on height { PropertyAnimation {duration: indicatorsFlow.config.indicatorsAnimated ? 250 : 0} }
            Behavior on width { PropertyAnimation {duration: indicatorsFlow.config.indicatorsAnimated ? 250 : 0} }

            Rectangle {
                id: stateRect

                width: segmentWrapper.isVertical ? segmentWrapper.thickness : parent.width
                height: segmentWrapper.isVertical ? parent.height : segmentWrapper.thickness

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

                color: segmentWrapper.showsPlus ? "transparent" : segmentWrapper.segmentColor
                radius: Math.min(width, height) * (indicatorsFlow.config.indicatorRadius / 200)

                Item {
                    id: plusIcon
                    anchors.fill: parent
                    visible: segmentWrapper.showsPlus

                    // Horizontal bar of the plus sign
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: Math.max(1, Math.round(parent.height * 0.25))
                        color: segmentWrapper.segmentColor
                        radius: height / 2
                    }

                    // Vertical bar of the plus sign
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.max(1, Math.round(parent.width * 0.25))
                        height: parent.height
                        color: segmentWrapper.segmentColor
                        radius: width / 2
                    }
                }
            }
        }
    }
    
    // Shared "should this edge's State be active" check for the four states below.
    // isFloatingDefault marks the one edge (bottom) that a floating panel falls
    // back to when the user hasn't set an override at all.
    function edgeMatches(edgeIndex, edgeType, isFloatingDefault) {
        const cfg = indicatorsFlow.config;
        const effectiveLocation = indicatorsFlow.tasksRoot.effectiveLocation;
        if (cfg.indicatorOverride && cfg.indicatorLocation === edgeIndex) return true;
        if (!cfg.indicatorOverride && effectiveLocation === edgeType) return true;
        return isFloatingDefault && effectiveLocation === PlasmaCore.Types.Floating && !cfg.indicatorOverride;
    }

    states:[
        State {
            name: "bottom"
            when: indicatorsFlow.edgeMatches(0, PlasmaCore.Types.BottomEdge, true)

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
            when: indicatorsFlow.edgeMatches(1, PlasmaCore.Types.LeftEdge, false)

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
            when: indicatorsFlow.edgeMatches(2, PlasmaCore.Types.RightEdge, false)

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
            when: indicatorsFlow.edgeMatches(3, PlasmaCore.Types.TopEdge, false)

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
