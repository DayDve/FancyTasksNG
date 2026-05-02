/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Marco Martin <notmart@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

Item {
    id: root
    property var parentTask: null
    anchors.fill: parent

    // ── Core geometry ──────────────────────────────────────────────
    readonly property bool iconsOnly: parentTask && parentTask.tasksRoot.iconsOnly
    readonly property var icon: parentTask ? parentTask.taskIcon : null

    // R is based on the iconBox (parent) size — the "square minus margins"
    // This equals the icon at 100% scale, and shrinks with icon scale.
    readonly property real boxW: parent ? parent.width : 0
    readonly property real boxH: parent ? parent.height : 0
    readonly property real iconCX: icon ? (icon.x + icon.width / 2) : (boxW / 2)
    readonly property real iconCY: icon ? (icon.y + icon.height / 2) : (boxH / 2)

    readonly property real iconR: Math.min(boxW, boxH) / 2
    readonly property real badgeR: iconR / 3
    readonly property real badgeDiam: badgeR * 2

    // Dot mode only for tiny panels (< 30px effective icon area)
    readonly property bool dotMode: badgeDiam < 10
    readonly property real effectiveBadgeDiam: Math.max(6, badgeDiam)

    // Audio badge is symbol-only (no background), needs larger area
    readonly property real audioBadgeDiam: effectiveBadgeDiam * 1.4

    // ── Panel location ─────────────────────────────────────────────
    readonly property int loc: Plasmoid.location
    readonly property bool isVertPanel: loc === PlasmaCore.Types.LeftEdge
                                        || loc === PlasmaCore.Types.RightEdge

    readonly property real innerSign: {
        if (loc === PlasmaCore.Types.TopEdge) return 1;
        if (loc === PlasmaCore.Types.LeftEdge) return 1;
        if (loc === PlasmaCore.Types.RightEdge) return -1;
        return -1; // BottomEdge / Floating
    }

    // ── Ideal badge centers on the inscribed circle ──────────────
    readonly property real spreadFactor: 0.97   // near-edge horizontal placement
    readonly property real depthFactor:  0.35   // shallow inward offset

    readonly property real audioCX: isVertPanel
        ? (iconCX + innerSign * iconR * depthFactor) : (iconCX - iconR * spreadFactor)
    readonly property real notifCX: isVertPanel
        ? (iconCX + innerSign * iconR * depthFactor) : (iconCX + iconR * spreadFactor)

    // How much to raise the badges at rest (so they sit slightly higher)
    readonly property real restRaise: badgeR * 0.65

    // Shared top Y — both badges aligned by their top edge
    readonly property real rawTopY: isVertPanel
        ? (iconCY - effectiveBadgeDiam / 2 - restRaise) 
        : (iconCY + innerSign * iconR * depthFactor - effectiveBadgeDiam / 2 - restRaise)
    readonly property real badgeTopY: clamp(rawTopY, 0, boxH - audioBadgeDiam)

    // ── Dive offset when zoomed ────────────────────────────────────
    // qmllint disable missing-property
    readonly property real parentGrow: (iconsOnly && parent && parent.growSize !== undefined) ? parent.growSize : 0
    // qmllint enable missing-property

    readonly property real _diveTarget: {
        if (!iconsOnly || !parentTask || !parentTask.highlighted) return 0;
        if (parentGrow <= 0) return 0;
        return parentGrow * 0.35;
    }
    property real diveOffset: _diveTarget
    property real raiseCompensation: _diveTarget > 0 ? restRaise : 0

    Behavior on diveOffset {
        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }
    Behavior on raiseCompensation {
        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }

    on_DiveTargetChanged: {
        diveOffset = _diveTarget;
        raiseCompensation = _diveTarget > 0 ? restRaise : 0;
    }

    readonly property real diveDx: isVertPanel ? (-innerSign * diveOffset) : 0
    readonly property real diveDy: isVertPanel ? raiseCompensation : (-innerSign * diveOffset + raiseCompensation)

    // Helper: clamp value to [min, max]
    function clamp(val, lo, hi) { return Math.max(lo, Math.min(hi, val)); }

    // ── Audio Badge ────────────────────────────────────────────────
    Badge {
        id: audioBadge
        // Shift left significantly to clear the icon center, 
        // Shift left, but clamp to -width/3 so it doesn't overflow into the left neighbor
        readonly property real idealX: root.audioCX - width / 2 + root.diveDx

        x: root.iconsOnly ? Math.max(-width / 3, idealX) : 0
        y: root.iconsOnly ? (root.badgeTopY + root.diveDy) : 0

        Behavior on x {
            enabled: root.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: root.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }

        height: root.iconsOnly ? root.audioBadgeDiam : Math.round(Kirigami.Units.gridUnit * 0.85)
        visible: root.parentTask ? (root.parentTask.playingAudio || root.parentTask.muted) : false

        textSource: "🕪"
        mirrorText: true
        overlaySource: root.parentTask?.muted ? "⦸" : ""
        opacity: root.parentTask?.muted ? 0.7 : 1.0
        hovered: !!audioMouseArea.containsMouse

        textIconColor: Kirigami.Theme.textColor
        showBackground: false
        shadowEnabled: true
        isRound: true
        fontFactor: 0.85
        isBold: false

        MouseArea {
            id: audioMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            onContainsMouseChanged: {
                if (root.parentTask) {
                    root.parentTask.isAudioHovered = audioMouseArea.containsMouse;
                }
            }
            onExited: {
                if (root.parentTask) root.parentTask.isAudioHovered = false;
            }
            onClicked: (mouse) => {
                mouse.accepted = true;
                if (root.parentTask) root.parentTask.toggleMuted();
            }
        }
    }

    // ── Notification Badge ─────────────────────────────────────────
    Badge {
        id: notificationBadge

        // When wider than circle, shift left by half the extra width
        readonly property real idealLeftX: root.notifCX - root.badgeR + root.diveDx
        readonly property real extraWidth: Math.max(0, width - height)

        x: root.iconsOnly
            ? Math.max(0, idealLeftX - extraWidth / 2)
            : (root.boxW - width)
        y: root.iconsOnly
            ? (root.badgeTopY + root.diveDy)
            : 0

        Behavior on x {
            enabled: root.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: root.iconsOnly
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }

        height: root.iconsOnly
            ? (root.dotMode ? Math.round(root.effectiveBadgeDiam * 0.5) : root.effectiveBadgeDiam)
            : Math.round(Kirigami.Units.gridUnit * 0.85)

        visible: !!root.parentTask?.badgeVisible
        appId: root.parentTask?.model?.AppId || ""

        isUrgent: (Plasmoid.configuration.badgeHighlightNew && !!root.parentTask?.hasUnseenNotifications)
                  || !!root.parentTask?.model?.DemandsAttention
        isRound: true
        isBold: false
        fontFactor: 0.7
        showNumber: !root.dotMode
    }
}
