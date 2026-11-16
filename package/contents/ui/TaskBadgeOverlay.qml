/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Marco Martin <notmart@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// Audio and notification badges of a task, in the corners of the button on
// the side away from the panel edge, so they use the button's free space
// whatever the icon size. On hover they grow with the icon in place: the
// corner facing the button's center and the panel edge stays put.
//
//   Panel    Audio         Count
//   Bottom   top left      top right
//   Top      bottom left   bottom right
//   Left     top right     bottom right
//   Right    top left      bottom left
Item {
    id: root

    // Inputs, so the settings preview can drive it with mock data.
    property rect button      // the button's content area, in this item's coordinates
    property real zoom: 1     // the icon's current hover zoom
    property real maxZoom: 1  // and its zoom when fully hovered
    property bool vertical: false
    property int location: PlasmaCore.Types.BottomEdge
    property bool highlighted: false
    property int dotMode: 2
    property int dotThreshold: 10
    property int colorMode: 0       // Badge.colorMode
    property color customColor: "transparent"

    property bool audioVisible: false
    property bool muted: false
    property bool countVisible: false
    property int count: 0
    property bool urgent: false
    // Progress as a ring around the count; without a count, a ring alone
    // where it would be.
    property bool progressVisible: false
    property real progress: 0
    property color progressColor: Kirigami.Theme.highlightColor
    property real progressOpacity: 1

    // Badges stick out of the task over its neighbours; pointing at them must
    // keep their own task hovered, or the icon unzooms under the cursor.
    readonly property bool hovered: audioHover.hovered || countHover.hovered
    signal muteToggled()

    // Edge of the button away from the panel edge; badges hug it.
    readonly property int farEdge: {
        if (location === PlasmaCore.Types.TopEdge) return Qt.BottomEdge;
        if (location === PlasmaCore.Types.LeftEdge) return Qt.RightEdge;
        if (location === PlasmaCore.Types.RightEdge) return Qt.LeftEdge;
        if (location === PlasmaCore.Types.BottomEdge) return Qt.TopEdge;
        return vertical ? Qt.RightEdge : Qt.TopEdge; // Floating
    }

    // ── Size ───────────────────────────────────────────────────────
    readonly property real restDiameter: Math.round(Math.min(button.width, button.height) / 3)
    // When a dot grows into a badge on hover, the badge must be big enough to read.
    readonly property real readableDiameter: Math.round(Kirigami.Units.gridUnit * 0.7)
    // 0 = never dots, 1 = dots at rest, 2 = dots when the badge is smaller than the threshold
    readonly property bool dotsAtRest: dotMode === 1 || (dotMode === 2 && restDiameter < dotThreshold)
    // Badges grow a bit less than the icon, or they cover too much of it.
    function grown(z: real): real {
        return Math.max(restDiameter * (1 + (z - 1) * 0.8), dotsAtRest ? readableDiameter : 0);
    }
    readonly property real dotDiameter: Math.max(4, Math.round(restDiameter * 0.5))

    // 0..1: how far a dot has grown into a badge.
    property real expansion: dotsAtRest && highlighted ? 1 : 0
    Behavior on expansion {
        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }
    readonly property real diameter: dotsAtRest ? dotDiameter + (grown(zoom) - dotDiameter) * expansion : grown(zoom)
    readonly property bool showContent: !dotsAtRest || expansion > 0.6

    // Badges are laid out once at their biggest size and scaled down from
    // there: resizing them as the zoom animates re-rounds the text and the
    // pill width every frame, and they wobble.
    readonly property real layoutDiameter: grown(maxZoom)
    readonly property real badgeScale: diameter / layoutDiameter

    // ── Position ───────────────────────────────────────────────────
    // Each badge grows from its corner facing the button's center and the
    // panel edge. Along the panel that corner sits a bit inside the button's
    // corner; across it, so that a badge at rest pokes a little past the
    // button's far edge.
    readonly property real nearOffset: (vertical ? button.height : button.width) / 2 - restDiameter * 1.35
    readonly property real restLift: restDiameter * 0.1

    function growsLeft(isCount: bool): bool {
        return vertical ? farEdge === Qt.LeftEdge : !isCount;
    }
    function growsUp(isCount: bool): bool {
        return vertical ? !isCount : farEdge === Qt.TopEdge;
    }
    function anchorX(isCount: bool): real {
        if (!vertical) return button.x + button.width / 2 + (isCount ? nearOffset : -nearOffset);
        return farEdge === Qt.LeftEdge ? button.x - restLift + restDiameter
                                       : button.x + button.width + restLift - restDiameter;
    }
    function anchorY(isCount: bool): real {
        if (vertical) return button.y + button.height / 2 + (isCount ? nearOffset : -nearOffset);
        return farEdge === Qt.TopEdge ? button.y - restLift + restDiameter
                                      : button.y + button.height + restLift - restDiameter;
    }
    function origin(isCount: bool): int {
        const left = growsLeft(isCount), up = growsUp(isCount);
        return up ? (left ? Item.BottomRight : Item.BottomLeft)
                  : (left ? Item.TopRight : Item.TopLeft);
    }

    // ── Audio ──────────────────────────────────────────────────────
    Item {
        id: audioBadge
        width: root.layoutDiameter
        height: width
        x: root.anchorX(false) - (root.growsLeft(false) ? width : 0)
        y: root.anchorY(false) - (root.growsUp(false) ? height : 0)
        transformOrigin: root.origin(false)
        scale: root.badgeScale
        visible: root.audioVisible

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.muted ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            opacity: root.showContent ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }

        SpeakerGlyph {
            anchors.fill: parent
            muted: root.muted
            opacity: root.showContent ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
            // A soft halo keeps the glyph readable on any icon.
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.4
                shadowColor: Qt.rgba(0, 0, 0, 0.75)
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        MouseArea {
            id: audioMouseArea
            // Small badges get a bigger target than they look.
            anchors.fill: parent
            anchors.margins: -Math.max(0, (Kirigami.Units.iconSizes.small - root.diameter) / 2) / Math.max(0.01, root.badgeScale)
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: root.muteToggled()

            HoverHandler {
                id: audioHover
                enabled: root.audioVisible
                blocking: true
            }
        }
    }

    // ── Notification count ─────────────────────────────────────────
    // The circle widens into a pill away from its fixed corner.
    Badge {
        id: notificationBadge
        colorMode: root.colorMode
        customColor: root.customColor
        height: root.layoutDiameter
        x: root.anchorX(true) - (root.growsLeft(true) ? width : 0)
        y: root.anchorY(true) - (root.growsUp(true) ? height : 0)
        transformOrigin: root.origin(true)
        scale: root.badgeScale
        // A ring scaled with the badge goes blurry; keep it one pixel thick.
        border.width: 1 / Math.max(0.01, root.badgeScale)
        visible: root.countVisible
        number: root.count
        showNumber: root.showContent
        isUrgent: root.urgent

        HoverHandler {
            id: countHover
            enabled: root.countVisible
            blocking: true
        }
    }

    // ── Progress ring ──────────────────────────────────────────────
    // Follows the count's outline, a circle or a pill, at a small gap, and
    // scales with it. The drawn part is a dash as long as the progress share
    // of the outline, starting at the top center and going clockwise.
    Item {
        id: progressRing
        width: root.countVisible ? notificationBadge.width : root.layoutDiameter
        height: root.layoutDiameter
        x: root.anchorX(true) - (root.growsLeft(true) ? width : 0)
        y: root.anchorY(true) - (root.growsUp(true) ? height : 0)
        transformOrigin: root.origin(true)
        scale: root.badgeScale
        visible: root.progressVisible
        opacity: root.progressOpacity

        readonly property real gap: Math.max(1, height * 0.08)
        readonly property real stroke: Math.max(1.5, height * 0.14)
        // The outline the stroke runs along, around the badge.
        readonly property real outerW: width + 2 * gap + stroke
        readonly property real outerH: height + 2 * gap + stroke
        readonly property real arcRadius: outerH / 2
        readonly property real perimeter: 2 * (outerW - outerH) + Math.PI * outerH
        readonly property real dashUnits: perimeter / stroke
        // The outline's corners, in the Shape's coordinates.
        readonly property real topY: stroke / 2
        readonly property real bottomY: topY + outerH
        readonly property real midX: stroke / 2 + outerW / 2
        readonly property real leftArcX: stroke / 2 + arcRadius
        readonly property real rightArcX: stroke / 2 + outerW - arcRadius

        Shape {
            id: ringShape
            anchors.fill: parent
            anchors.margins: -(progressRing.gap + progressRing.stroke)
            antialiasing: true
            layer.enabled: true
            layer.samples: 4

            // The whole outline, faint, as the track.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(root.progressColor, 0.3)
                strokeWidth: progressRing.stroke
                startX: progressRing.midX
                startY: progressRing.topY
                PathLine { x: progressRing.rightArcX; y: progressRing.topY }
                PathArc { x: progressRing.rightArcX; y: progressRing.bottomY; radiusX: progressRing.arcRadius; radiusY: progressRing.arcRadius }
                PathLine { x: progressRing.leftArcX; y: progressRing.bottomY }
                PathArc { x: progressRing.leftArcX; y: progressRing.topY; radiusX: progressRing.arcRadius; radiusY: progressRing.arcRadius }
                PathLine { x: progressRing.midX; y: progressRing.topY }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.progressColor
                strokeWidth: progressRing.stroke
                capStyle: ShapePath.FlatCap
                strokeStyle: ShapePath.DashLine
                // In stroke widths: the done part, then a gap longer than
                // the rest of the outline.
                dashPattern: [Math.max(0.001, progressRing.dashUnits * Math.min(1, root.progress)), progressRing.dashUnits + 1]
                startX: progressRing.midX
                startY: progressRing.topY
                PathLine { x: progressRing.rightArcX; y: progressRing.topY }
                PathArc { x: progressRing.rightArcX; y: progressRing.bottomY; radiusX: progressRing.arcRadius; radiusY: progressRing.arcRadius }
                PathLine { x: progressRing.leftArcX; y: progressRing.bottomY }
                PathArc { x: progressRing.leftArcX; y: progressRing.topY; radiusX: progressRing.arcRadius; radiusY: progressRing.arcRadius }
                PathLine { x: progressRing.midX; y: progressRing.topY }
            }
        }
    }
}
