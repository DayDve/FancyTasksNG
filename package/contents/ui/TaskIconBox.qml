import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import QtQuick.Effects

import "code/layoutmetrics.js" as LayoutMetrics

Item {
    id: iconBox

    property var taskItem: null
    property var tasksRootContext: null
    property bool labelVisible: false
    property alias icon: innerIcon
    property bool active: innerIcon.active

    readonly property bool _iconsOnly: iconBox.tasksRootContext ? iconBox.tasksRootContext.iconsOnly : true
    readonly property real _trHeight: iconBox.tasksRootContext ? iconBox.tasksRootContext.height : 0
    readonly property var _trTaskFrame: iconBox.tasksRootContext ? iconBox.tasksRootContext.taskFrame : null
    
    // Protection for task context
    readonly property bool _taskHovered: iconBox.taskItem ? iconBox.taskItem.containsMouse : false
    readonly property bool _contextMenuOpen: (iconBox.taskItem && iconBox.taskItem.contextMenu) ? (iconBox.taskItem.contextMenu.status === PlasmaExtras.Menu.Open) : false
    readonly property bool _iconOverflows: iconBox.taskItem ? iconBox.taskItem.iconOverflows : false
    readonly property bool _taskHighlighted: iconBox.taskItem ? iconBox.taskItem.highlighted : false
    readonly property bool _taskHasModel: iconBox.taskItem ? !!iconBox.taskItem.model : false

    anchors.centerIn: iconBox._iconsOnly ? parent : undefined
    anchors.fill: iconBox._iconsOnly ? undefined : parent
    anchors.left: iconBox._iconsOnly ? undefined : parent.left
    
    anchors.topMargin: iconBox._iconsOnly ? 0 : adjustMargin(false, parent.height, LayoutMetrics.topMargin())
    anchors.bottomMargin: iconBox._iconsOnly ? 0 : adjustMargin(false, parent.height, LayoutMetrics.bottomMargin())
    anchors.leftMargin: iconBox._iconsOnly ? 0 : adjustMargin(true, parent.height, LayoutMetrics.leftMargin())

    width: iconBox._iconsOnly ? (parent.width - 2 * Math.max(LayoutMetrics.leftMargin(), LayoutMetrics.rightMargin())) : height
    height: iconBox._iconsOnly ? (parent.height - 2 * Math.max(LayoutMetrics.topMargin(), LayoutMetrics.bottomMargin())) : parent.height

    property int growSize: (iconBox._iconsOnly && Plasmoid.configuration.taskHoverEffect && (iconBox._taskHovered || (iconBox.tasksRootContext && iconBox.tasksRootContext.currentHoveredTask === iconBox.taskItem && iconBox.tasksRootContext.isTooltipHovered) || iconBox._contextMenuOpen)) ?
        Plasmoid.configuration.iconZoomFactor : 0

    Behavior on growSize {
        NumberAnimation {
            duration: Plasmoid.configuration.iconZoomDuration
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
                if (Plasmoid.configuration.iconScaleFromEdge) {
                    if (Plasmoid.location === PlasmaCore.Types.LeftEdge) return iconBox.icon.anchors.leftMargin;
                    if (Plasmoid.location === PlasmaCore.Types.RightEdge) return iconBox.width - iconBox.icon.anchors.rightMargin;
                }
                return iconBox.width / 2;
            }
            origin.y: {
                if (Plasmoid.configuration.iconScaleFromEdge) {
                    if (Plasmoid.location === PlasmaCore.Types.TopEdge) return iconBox.icon.anchors.topMargin;
                    if (Plasmoid.location === PlasmaCore.Types.BottomEdge) return iconBox.height - iconBox.icon.anchors.bottomMargin;
                }
                return iconBox.height / 2;
            }
            xScale: 1 + (iconBox.growSize / Math.max(1, iconBox.height))
            yScale: xScale
        }
    ]

    SequentialAnimation {
        id: attentionAnimation
        running: iconBox._taskHasModel && iconBox.taskItem.model.IsDemandingAttention && iconBox._iconsOnly && Plasmoid.configuration.animateAttentionStatus && !iconBox._taskHighlighted
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
        
        property bool sizeOverride: Plasmoid.configuration.iconSizeOverride
        property int fixedSize: Plasmoid.configuration.iconSizePx
        property real iconScale: Plasmoid.configuration.iconScale / 100
        property bool scaleFromEdge: Plasmoid.configuration.iconScaleFromEdge
        property int edgeOffset: Plasmoid.configuration.iconEdgeOffset

        readonly property int baseWidth: (sizeOverride ? fixedSize : (parent.width * iconScale))
        readonly property int baseHeight: (sizeOverride ? fixedSize : (parent.height * iconScale))
        readonly property real edgeMarginH: scaleFromEdge ? edgeOffset : (parent.width - baseWidth) / 2
        readonly property real edgeMarginV: scaleFromEdge ? edgeOffset : (parent.height - baseHeight) / 2

        width: baseWidth
        height: baseHeight

        x: {
            if (Plasmoid.location === PlasmaCore.Types.LeftEdge) return edgeMarginH;
            if (Plasmoid.location === PlasmaCore.Types.RightEdge) return parent.width - width - edgeMarginH;
            return (parent.width - width) / 2;
        }

        y: {
            if (Plasmoid.location === PlasmaCore.Types.TopEdge) return edgeMarginV;
            if (Plasmoid.location === PlasmaCore.Types.BottomEdge) return parent.height - height - edgeMarginV;
            return (parent.height - height) / 2;
        }

        roundToIconSize: false
        active: iconBox._taskHighlighted
        enabled: true

        source: iconBox._taskHasModel ? iconBox.taskItem.model.decoration : ""
        layer.enabled: iconBox._iconOverflows
    }

    MultiEffect {
        anchors.fill: innerIcon
        source: innerIcon
        visible: iconBox._iconOverflows
        shadowEnabled: true
        shadowBlur: 1.0
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        shadowColor: Qt.rgba(0, 0, 0, 0.5)
        autoPaddingEnabled: true
    }

    Loader {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        active: !!(iconBox._taskHasModel && iconBox.taskItem.model.IsStartup)
        sourceComponent: iconBox.tasksRootContext ? iconBox.tasksRootContext.busyIndicator : null
    }

    states: [
        State {
            name: "standalone"
            when: !iconBox.labelVisible && iconBox.taskItem && iconBox.taskItem.parent
            PropertyChanges {
                target: iconBox; anchors.leftMargin: 0
                width: (iconBox._taskHasModel && iconBox.taskItem.model.IsLauncher && !iconBox._iconsOnly) ? iconBox.taskItem.parent.minimumWidth :
                    Math.min(iconBox.taskItem.parent.minimumWidth, iconBox._trHeight) - adjustMargin(true, iconBox.taskItem.width, iconBox._trTaskFrame ? iconBox._trTaskFrame.margins.left : 0) - adjustMargin(true, iconBox.taskItem.width, iconBox._trTaskFrame ? iconBox._trTaskFrame.margins.right : 0)
            }
        }
    ]
}


