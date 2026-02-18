/*
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

Flow {
    id: indicatorsFlow
    spacing: 10
    property int taskCount: 1
    required property var task
    required property var frame
    Repeater {
        model: {
            if(!Plasmoid.configuration.indicatorsEnabled)
            return 0;
            if(indicatorsFlow.taskCount < Plasmoid.configuration.indicatorMinLimit)
            return 0;
            if(indicatorsFlow.task.isSubTask)//Target only the main task items.
            return 0;
            if(indicatorsFlow.task.state === 'launcher') {
                return 0;
            }
            return Math.min((indicatorsFlow.taskCount === 0) ? 1 : indicatorsFlow.taskCount, maxStates);
        }
        readonly property int maxStates: Plasmoid.configuration.indicatorMaxLimit
        
        Rectangle{
            id: stateRect
            required property int index
            Behavior on height { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
            Behavior on width { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
            Behavior on color { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
            Behavior on radius { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
            readonly property color decoColor: indicatorsFlow.frame.indicatorColor
            readonly property int maxStates: Plasmoid.configuration.indicatorMaxLimit
            readonly property bool isFirst: index === 0
            readonly property int adjust: Plasmoid.configuration.indicatorShrink
            readonly property int indicatorLength: Plasmoid.configuration.indicatorLength
            readonly property int spacing: Kirigami.Units.smallSpacing
            readonly property bool isVertical: {
                if(Plasmoid.formFactor === PlasmaCore.Types.Vertical && !Plasmoid.configuration.indicatorOverride)
                return true;
                if(Plasmoid.formFactor == PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorOverride && (Plasmoid.configuration.indicatorLocation === 1 || Plasmoid.configuration.indicatorLocation === 2))
                return  true;
                if(Plasmoid.configuration.indicatorOverride && (Plasmoid.configuration.indicatorLocation === 1 || Plasmoid.configuration.indicatorLocation === 2))
                return  true;
                else{
                    return false;
                }
            }
            readonly property var computedVar: {
                var height;
                var width;
                var colorCalc;
                var colorEval = '#FFFFFF';
                var parentSize = !isVertical ? indicatorsFlow.frame.width : indicatorsFlow.frame.height;
                var indicatorComputedSize;
                var adjustment = isFirst ? adjust : 0
                var parentSpacingAdjust = indicatorsFlow.taskCount >= 1 && maxStates >= 2 ? (spacing * 2.5) : 0 //Spacing fix for multiple items
                if(Plasmoid.configuration.indicatorDominantColor){
                    colorEval = decoColor
                }
                if(Plasmoid.configuration.indicatorAccentColor){
                    colorEval = Kirigami.Theme.highlightColor
                }
                else if(!Plasmoid.configuration.indicatorDominantColor && !Plasmoid.configuration.indicatorAccentColor){
                    colorEval = Plasmoid.configuration.indicatorCustomColor
                }
                if(isFirst){//compute the size
        
                    var growFactor = Plasmoid.configuration.indicatorGrowFactor / 100
                    if(Plasmoid.configuration.indicatorGrow && indicatorsFlow.task.state === "minimized") {
                        var mainSize = indicatorLength * growFactor;
                    }
                    else{
                        var mainSize = (parentSize + parentSpacingAdjust);
                    }
                    switch(Plasmoid.configuration.indicatorStyle){
                        case 0:
                        indicatorComputedSize = mainSize - (Math.min(indicatorsFlow.taskCount, maxStates === 1 ? 0 : maxStates)  * (spacing + indicatorLength)) - adjust
                        break
                        case 1:
                        indicatorComputedSize = mainSize - (Math.min(indicatorsFlow.taskCount, maxStates === 1 ? 0 : maxStates)  * (spacing + indicatorLength)) - adjust
                        break
                        case 2:
                        indicatorComputedSize = Plasmoid.configuration.indicatorGrow && indicatorsFlow.task.state !== "minimized" ? indicatorLength * growFactor : indicatorLength
                        break
                        default:
                        break
                    }
    
                }
                else {
                    indicatorComputedSize = indicatorLength
                }
                if(!isVertical){
                    width = indicatorComputedSize;
                    height = Plasmoid.configuration.indicatorSize
                }
                else{
                    width = Plasmoid.configuration.indicatorSize
                    height = indicatorComputedSize
                
                }
                if(Plasmoid.configuration.indicatorDesaturate && indicatorsFlow.task.state === "minimized") {
                    var colorHSL = hexToHSL(colorEval)  // qmllint disable unqualified
                    colorCalc = Qt.hsla(colorHSL.h, colorHSL.s*0.5, colorHSL.l*.8, 1)
                }
                else if(!isFirst && Plasmoid.configuration.indicatorStyle ===  0 && indicatorsFlow.task.state !== "minimized") {//Metro specific handling
                    colorCalc = Qt.darker(colorEval, 1.2) 
                }
                else {
                    colorCalc = colorEval
                }
                return {height: height, width: width, colorCalc: colorCalc}
            }
            width: computedVar.width
            height: computedVar.height
            color: computedVar.colorCalc
            radius: Math.min(width, height) * (Plasmoid.configuration.indicatorRadius / 200)

            Rectangle{
                Behavior on height { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on width { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on color { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                Behavior on radius { PropertyAnimation {duration: Plasmoid.configuration.indicatorsAnimated ? 250 : 0} }
                visible:  indicatorsFlow.task.isWindow && indicatorsFlow.task.smartLauncherItem && indicatorsFlow.task.smartLauncherItem.progressVisible && stateRect.isFirst && Plasmoid.configuration.indicatorProgress
                anchors{
                    top: stateRect.isVertical ? undefined : parent.top
                    bottom: stateRect.isVertical ? undefined : parent.bottom
                    left: stateRect.isVertical ? parent.left : undefined
                    right: stateRect.isVertical ? parent.right : undefined
                }
                readonly property var progress: {
                    if(indicatorsFlow.task.smartLauncherItem && indicatorsFlow.task.smartLauncherItem.progressVisible && indicatorsFlow.task.smartLauncherItem.progress){
                        return indicatorsFlow.task.smartLauncherItem.progress / 100
                    }
                    return 0
                }
                width: stateRect.isVertical ? parent.width : parent.width * progress
                height: stateRect.isVertical ? parent.height * progress : parent.height
                radius: parent.radius
                color: Plasmoid.configuration.indicatorProgressColor
            }
        }
    }
    
    states:[
        State {
            name: "bottom"
            when: (Plasmoid.configuration.indicatorOverride && Plasmoid.configuration.indicatorLocation === 0)
                || (!Plasmoid.configuration.indicatorOverride && Plasmoid.location === PlasmaCore.Types.BottomEdge && !Plasmoid.configuration.indicatorReverse)
                || (!Plasmoid.configuration.indicatorOverride && Plasmoid.location === PlasmaCore.Types.TopEdge && Plasmoid.configuration.indicatorReverse)
                || (Plasmoid.location === PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorLocation === 0)
                || (Plasmoid.location === PlasmaCore.Types.Floating && !Plasmoid.configuration.indicatorOverride && !Plasmoid.configuration.indicatorReverse)

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
                || (!Plasmoid.configuration.indicatorOverride && Plasmoid.location === PlasmaCore.Types.LeftEdge && !Plasmoid.configuration.indicatorReverse)
                || (!Plasmoid.configuration.indicatorOverride && Plasmoid.location === PlasmaCore.Types.RightEdge && Plasmoid.configuration.indicatorReverse)
                || (Plasmoid.location === PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorLocation === 1 && Plasmoid.configuration.indicatorOverride)

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
                || (!Plasmoid.configuration.indicatorOverride && Plasmoid.location === PlasmaCore.Types.RightEdge && !Plasmoid.configuration.indicatorReverse)
                || (!Plasmoid.configuration.indicatorOverride && Plasmoid.location === PlasmaCore.Types.LeftEdge && Plasmoid.configuration.indicatorReverse)
                || (Plasmoid.location === PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorLocation === 2 && Plasmoid.configuration.indicatorOverride)

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
                || (!Plasmoid.configuration.indicatorOverride && Plasmoid.location === PlasmaCore.Types.TopEdge && !Plasmoid.configuration.indicatorReverse)
                || (!Plasmoid.configuration.indicatorOverride && Plasmoid.location === PlasmaCore.Types.BottomEdge && Plasmoid.configuration.indicatorReverse)
                || (Plasmoid.location === PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorLocation === 3 && Plasmoid.configuration.indicatorOverride)
                || (Plasmoid.location === PlasmaCore.Types.Floating && Plasmoid.configuration.indicatorReverse && !Plasmoid.configuration.indicatorOverride)

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
