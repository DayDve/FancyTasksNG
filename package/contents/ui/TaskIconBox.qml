/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import QtQuick.Effects

import "code/layoutmetrics.js" as LayoutMetrics
import "code/tools.js" as TaskTools

Item {
    id: iconBox

    property var taskItem: null
    property var tasksRootContext: null
    property bool labelVisible: false
    property alias icon: innerIcon
    property bool active: innerIcon.active

    // Local cached properties for optimization
    readonly property var config: Plasmoid.configuration
    readonly property var tasksRoot: iconBox.tasksRootContext
    readonly property int location: Plasmoid.location

    readonly property bool _iconsOnly: iconBox.tasksRoot ? iconBox.tasksRoot.iconsOnly : true
    readonly property real _trHeight: iconBox.tasksRoot ? iconBox.tasksRoot.height : 0
    readonly property var _trTaskFrame: iconBox.tasksRoot ? iconBox.tasksRoot.taskFrame : null
    
    // Protection for task context
    readonly property bool _taskHovered: iconBox.taskItem ? iconBox.taskItem.containsMouse : false
    readonly property bool _contextMenuOpen: (iconBox.taskItem && iconBox.taskItem.contextMenu) ? (iconBox.taskItem.contextMenu.status === PlasmaExtras.Menu.Open) : false
    readonly property bool _iconOverflows: iconBox.taskItem ? iconBox.taskItem.iconOverflows : false
    readonly property bool _taskHighlighted: iconBox.taskItem ? iconBox.taskItem.highlighted : false
    readonly property bool _taskHasModel: iconBox.taskItem ? !!iconBox.taskItem.model : false
    readonly property var _iconMask: iconMask

    anchors.centerIn: iconBox._iconsOnly ? parent : undefined
    anchors.top: iconBox._iconsOnly ? undefined : parent.top
    anchors.bottom: iconBox._iconsOnly ? undefined : parent.bottom
    anchors.left: iconBox._iconsOnly ? undefined : parent.left
    
    anchors.topMargin: iconBox._iconsOnly ? 0 : adjustMargin(false, parent.height, LayoutMetrics.topMargin())
    anchors.bottomMargin: iconBox._iconsOnly ? 0 : adjustMargin(false, parent.height, LayoutMetrics.bottomMargin())
    anchors.leftMargin: iconBox._iconsOnly ? 0 : adjustMargin(true, parent.height, LayoutMetrics.leftMargin())

    width: iconBox._iconsOnly ? (parent.width - 2 * Math.max(LayoutMetrics.leftMargin(), LayoutMetrics.rightMargin())) : height
    height: iconBox._iconsOnly ? (parent.height - 2 * Math.max(LayoutMetrics.topMargin(), LayoutMetrics.bottomMargin())) : undefined

    readonly property int hoveredIndex: iconBox.tasksRoot ? iconBox.tasksRoot.instantHoveredIndex : -1
    readonly property int myIndex: iconBox.taskItem ? iconBox.taskItem.index : -1
    readonly property real hoveredFraction: iconBox.tasksRoot ? iconBox.tasksRoot.instantHoveredFraction : 0.5
    readonly property real virtualCursorIndex: (hoveredIndex !== -1) ? (hoveredIndex + hoveredFraction - 0.5) : -1
    readonly property real distanceToCursor: (virtualCursorIndex !== -1 && myIndex !== -1) ? Math.abs(myIndex - virtualCursorIndex) : -1

    readonly property real zoomMultiplier: {
        if (iconBox._contextMenuOpen) {
            return 1.0;
        }
        if (iconBox.tasksRoot && iconBox.tasksRoot.currentHoveredTask === iconBox.taskItem) {
            if (iconBox.tasksRoot.isTooltipHovered || iconBox.tasksRoot.instantHoveredIndex === -1) {
                return 1.0;
            }
        }
        if (hoveredIndex === -1 || myIndex === -1 || !iconBox._iconsOnly || !iconBox.config.taskHoverEffect) {
            return 0.0;
        }

        if (iconBox.config.taskHoverEffectStyle !== 1) {
            return (hoveredIndex === myIndex) ? 1.0 : 0.0;
        }

        if (distanceToCursor <= 0.5) {
            return 1.0 - distanceToCursor;
        } else if (distanceToCursor < 1.5) {
            return 0.5 * (1.5 - distanceToCursor);
        }
        return 0.0;
    }

    property int growSize: Math.round(iconBox.zoomMultiplier * iconBox.config.iconZoomFactor)

    readonly property bool isParabolicTracking: iconBox.config.taskHoverEffectStyle === 1 && iconBox.tasksRoot && iconBox.tasksRoot.instantHoveredIndex !== -1 && iconBox.myIndex !== -1 && !(iconBox._taskHasModel && iconBox.taskItem.model.IsStartup)

    Behavior on growSize {
        NumberAnimation {
            duration: iconBox.isParabolicTracking ? 30 : iconBox.config.iconZoomDuration
            easing.type: Easing.InOutQuad
        }
    }

    transform: [
        Translate {
            id: attentionTranslate
            y: 0
        },
        Scale {
            id: zoomScale
            origin.x: {
                if (iconBox.config.iconScaleFromEdge) {
                    if (iconBox.location === PlasmaCore.Types.LeftEdge) return iconBox.icon.anchors.leftMargin;
                    if (iconBox.location === PlasmaCore.Types.RightEdge) return iconBox.width - iconBox.icon.anchors.rightMargin;
                }
                return iconBox.width / 2;
            }
            origin.y: {
                if (iconBox.config.iconScaleFromEdge) {
                    if (iconBox.location === PlasmaCore.Types.TopEdge) return iconBox.icon.anchors.topMargin;
                    if (iconBox.location === PlasmaCore.Types.BottomEdge) return iconBox.height - iconBox.icon.anchors.bottomMargin;
                }
                return iconBox.height / 2;
            }
            xScale: 1 + (iconBox.growSize / Math.max(1, iconBox.height))
            yScale: xScale
        }
    ]

    SequentialAnimation {
        id: attentionAnimation
        running: iconBox._taskHasModel && iconBox.taskItem.model.IsDemandingAttention && iconBox._iconsOnly && iconBox.config.animateAttentionStatus && !iconBox._taskHighlighted
        loops: Animation.Infinite
        onRunningChanged: if (!running) attentionTranslate.y = 0

        NumberAnimation {
            target: attentionTranslate
            property: "y"
            to: -Kirigami.Units.gridUnit / 3.5
            duration: 300
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: attentionTranslate
            property: "y"
            to: 0
            duration: 400
            easing.type: Easing.OutBounce
        }
        PauseAnimation {
            duration: 1500
        }
    }

    function adjustMargin(isVertical: bool, size: real, margin: real): real {
        if (!size) {
            return margin;
        }

        var margins = isVertical ? LayoutMetrics.horizontalMargins() : LayoutMetrics.verticalMargins();
        if ((size - margins) < Kirigami.Units.iconSizes.small) {
            return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
        }

        return margin;
    }

    Kirigami.Icon {
        id: innerIcon
        
        property bool sizeOverride: iconBox.config.iconSizeOverride
        property int fixedSize: iconBox.config.iconSizePx
        property real iconScale: iconBox.config.iconScale / 100
        property bool scaleFromEdge: iconBox.config.iconScaleFromEdge
        property int edgeOffset: iconBox.config.iconEdgeOffset

        readonly property int baseWidth: (sizeOverride ? fixedSize : (parent.width * iconScale))
        readonly property int baseHeight: (sizeOverride ? fixedSize : (parent.height * iconScale))
        readonly property int iconSize: Math.min(baseWidth, baseHeight)
        readonly property real edgeMarginH: scaleFromEdge ? edgeOffset : (parent.width - iconSize) / 2
        readonly property real edgeMarginV: scaleFromEdge ? edgeOffset : (parent.height - iconSize) / 2

        width: iconSize
        height: iconSize

        x: {
            if (iconBox.location === PlasmaCore.Types.LeftEdge) return edgeMarginH;
            if (iconBox.location === PlasmaCore.Types.RightEdge) return parent.width - width - edgeMarginH;
            return (parent.width - width) / 2;
        }

        y: {
            if (iconBox.location === PlasmaCore.Types.TopEdge) return edgeMarginV;
            if (iconBox.location === PlasmaCore.Types.BottomEdge) return parent.height - height - edgeMarginV;
            return (parent.height - height) / 2;
        }

        roundToIconSize: false
        active: iconBox._taskHighlighted
        enabled: true

        source: iconBox._taskHasModel ? iconBox.taskItem.model.decoration : ""
        opacity: 1.0
        Behavior on opacity {
            NumberAnimation { duration: 250 }
        }

        layer.enabled: iconBox._iconOverflows || iconBox.config.clipIconToShape
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: iconBox.config.clipIconToShape
            maskSource: iconBox._iconMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0

            shadowEnabled: iconBox._iconOverflows
            shadowBlur: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            autoPaddingEnabled: true
        }
    }

    Rectangle {
        id: iconMask
        x: -9999
        y: -9999
        width: innerIcon.width
        height: innerIcon.height
        radius: (iconBox.config.iconClipRadius / 200) * Math.min(innerIcon.width, innerIcon.height)
        color: "black"
        visible: true
        antialiasing: true
        layer.enabled: true
        layer.smooth: true
    }

    Loader {
        id: iconColorsLoader
        // ImageColors is a heavy C++ component that parses the icon. To prevent memory and CPU waste,
        // we only activate this Loader when shape clipping is enabled, background card is enabled,
        // and a dynamic color extraction mode (dominant or average) is selected.
        active: iconBox.config.clipIconToShape && iconBox.config.clipIconBackgroundEnabled && (iconBox.config.clipIconBackgroundColorMode === 1 || iconBox.config.clipIconBackgroundColorMode === 2)
        sourceComponent: Kirigami.ImageColors {
            source: innerIcon.source
        }
    }

    Rectangle {
        id: iconBackgroundCard
        anchors.fill: innerIcon
        radius: (iconBox.config.iconClipRadius / 200) * Math.min(innerIcon.width, innerIcon.height)
        antialiasing: true
        color: {
            const mode = iconBox.config.clipIconBackgroundColorMode;
            if (mode === 1) {
                const domColor = iconColorsLoader.item ? (iconColorsLoader.item as Kirigami.ImageColors).dominant : "transparent";
                return TaskTools.harmonizeIconColor(domColor, domColor, Kirigami.Theme.backgroundColor, false);
            } else if (mode === 2) {
                const avgColor = iconColorsLoader.item ? TaskTools.getAveragePaletteColor((iconColorsLoader.item as Kirigami.ImageColors).palette, (iconColorsLoader.item as Kirigami.ImageColors).average) : "transparent";
                const domColor = iconColorsLoader.item ? (iconColorsLoader.item as Kirigami.ImageColors).dominant : "transparent";
                return TaskTools.harmonizeIconColor(avgColor, domColor, Kirigami.Theme.backgroundColor, true);
            } else if (mode === 3) {
                return Kirigami.Theme.highlightColor;
            }
            return iconBox.config.clipIconBackgroundColor;
        }
        opacity: iconBox.config.clipIconBackgroundOpacity / 100
        visible: iconBox.config.clipIconToShape && iconBox.config.clipIconBackgroundEnabled
        z: -1
    }

    Loader {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        active: !!(iconBox._taskHasModel && iconBox.taskItem.model.IsStartup)
        sourceComponent: iconBox.tasksRoot ? iconBox.tasksRoot.busyIndicator : null
    }

    states: [
        State {
            name: "standalone"
            when: !iconBox._iconsOnly && !iconBox.labelVisible && iconBox.taskItem && iconBox.taskItem.parent && iconBox._taskHasModel && !iconBox.taskItem.model.IsLauncher
            PropertyChanges {
                iconBox.anchors.leftMargin: 0
                iconBox.width: Math.min(iconBox.taskItem.parent.minimumWidth, iconBox._trHeight) - adjustMargin(true, iconBox.taskItem.width, iconBox._trTaskFrame ? iconBox._trTaskFrame.margins.left : 0) - adjustMargin(true, iconBox.taskItem.width, iconBox._trTaskFrame ? iconBox._trTaskFrame.margins.right : 0)
            }
        }
    ]
}
