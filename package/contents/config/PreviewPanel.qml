/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
// Not used by name: without it, child.Layout below reads as undefined and a
// classic panel's content width comes out as 0.
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.core as PlasmaCore

import "../ui" as FancyUI
import "../ui/code/layoutmetrics.js" as LayoutMetrics
import "../ui/code/tools.js" as TaskTools

// A stand-in for the widget's root (main.qml) that the real TaskList and
// Task delegates can be put in: it has the members they read, fed from the
// settings being edited instead of the applied ones, and a mock task model.
// The tasks don't take input; the hovered one is fixed.
KSvg.FrameSvgItem {
    id: panel

    // The settings page; its cfg_<name> values are read as config.<name>.
    required property var cfgPage
    required property int location
    // The mock tasks, with TasksModel role names plus the mock* ones below.
    required property ListModel previewModel
    // Row of the task shown as hovered (with its tooltip open), or -1.
    property int hoveredRow: -1
    // Row of the active task, and its child row when it's a group.
    property int activeRow: -1
    property int activeChildRow: 0

    imagePath: "widgets/panel-background"
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Kirigami.Theme.inherit: false

    // --- What the task delegates read from main.qml ---

    readonly property var config: new Proxy({}, {
        get: (target, name) => panel.cfgPage["cfg_" + String(name)]
    })
    readonly property bool vertical: location === PlasmaCore.Types.LeftEdge || location === PlasmaCore.Types.RightEdge
    readonly property bool iconsOnly: config.iconOnly === 1
    readonly property int effectiveLocation: location
    readonly property alias taskFrame: taskFrame
    readonly property alias taskList: taskList

    // Set as the delegates come and go (itemAt() in a binding isn't
    // re-evaluated when they do).
    property Item currentHoveredTask: null
    property Item instantHoveredTask: null
    // The "cursor" is over the hovered task, for the zoom of its neighbors.
    readonly property int instantHoveredIndex: currentHoveredTask ? hoveredRow : -1
    property real instantHoveredFraction: 0.5
    readonly property bool isTooltipHovered: false
    readonly property QtObject mouseHandler: QtObject {
        readonly property Item hoveredItem: null
    }
    property Item dragSource: null
    readonly property Item dragHelper: null
    readonly property Component busyIndicator: null
    readonly property QtObject effectWatcher: QtObject {
        readonly property bool registered: false
    }
    readonly property var mediaRegistry: null
    readonly property var filteredTasksModel: null

    // Stands in for TasksModel where the delegates call it; Indicators ask it
    // which task is active.
    readonly property QtObject tasksModel: QtObject {
        readonly property var activeTask: panel.activeRow < 0 ? null : {
            valid: true,
            row: panel.isGroupRow(panel.activeRow) ? panel.activeChildRow : panel.activeRow
        }
        function parent(index): var {
            return {
                valid: panel.isGroupRow(panel.activeRow),
                row: panel.activeRow
            };
        }
        function makeModelIndex(row: int): var {
            return { valid: row >= 0, row: row };
        }
        function requestPublishDelegateGeometry(): void {}
    }

    function isGroupRow(row: int): bool {
        return row >= 0 && row < previewModel.count && previewModel.get(row).IsGroupParent;
    }

    function isForeignStartup(): bool {
        return false;
    }
    function shouldBeMirrored(reverseMode, layoutDirection, vertical): bool {
        if (vertical)
            return layoutDirection === Qt.RightToLeft;
        if (layoutDirection === Qt.LeftToRight)
            return reverseMode;
        return !reverseMode;
    }
    function cancelHighlightWindows(): void {}
    function requestLayout(): void {}
    function showTooltip(): void {}
    function dismissTooltip(): void {}

    KSvg.FrameSvgItem {
        id: taskFrame
        visible: false
        imagePath: "widgets/tasks"
        prefix: TaskTools.taskPrefix("normal", panel.location)
    }

    // Same alignment as the real widget: at the start, or centered with
    // "Fill" and "Center" in icons-only mode.
    readonly property bool centerAlign: iconsOnly && config.fill && config.fillAlignment === 1

    FancyUI.TaskList {
        id: taskList
        tasks: panel
        tasksModel: panel.previewModel
        LayoutMirroring.enabled: panel.shouldBeMirrored(panel.config.reverseMode, Qt.locale().textDirection, panel.vertical)

        readonly property real widthOccupation: taskRepeater.count / columns
        readonly property real heightOccupation: taskRepeater.count / rows
        readonly property real contentWidth: {
            if (widthOccupation <= 0)
                return 0;
            if (panel.iconsOnly)
                return Math.round((taskRepeater.count * LayoutMetrics.preferredMaxWidth(panel)) / widthOccupation);
            return Math.round(children.reduce((acc, child) => (child && child.visible && isFinite(child.Layout.maximumWidth)) ? acc + child.Layout.maximumWidth : acc, 0) / widthOccupation);
        }
        readonly property real contentHeight: {
            if (heightOccupation <= 0)
                return 0;
            if (panel.iconsOnly)
                return Math.round((taskRepeater.count * LayoutMetrics.preferredMaxHeight(panel)) / heightOccupation);
            return Math.round(children.reduce((acc, child) => (child && child.visible && isFinite(child.Layout.maximumHeight)) ? acc + child.Layout.maximumHeight : acc, 0) / heightOccupation);
        }
        width: panel.vertical ? panel.width : Math.min(panel.width, contentWidth)
        height: panel.vertical ? Math.min(panel.height, contentHeight) : panel.height
        x: panel.centerAlign && !panel.vertical ? Math.round((panel.width - width) / 2) : 0
        y: panel.centerAlign && panel.vertical ? Math.round((panel.height - height) / 2) : 0
        flow: panel.vertical ? (panel.config.forceStripes ? Grid.LeftToRight : Grid.TopToBottom) : (panel.config.forceStripes ? Grid.TopToBottom : Grid.LeftToRight)

        Repeater {
            id: taskRepeater
            model: panel.previewModel
            onItemAdded: (index, item) => {
                if (index === panel.hoveredRow)
                    panel.currentHoveredTask = item;
            }
            onItemRemoved: (index, item) => {
                if (panel.currentHoveredTask === item)
                    panel.currentHoveredTask = null;
            }
            delegate: FancyUI.Task {
                id: previewTask
                required property int mockBadgeCount
                required property real mockProgress
                required property bool mockPlaying
                required property bool mockMuted

                tasksRoot: panel
                interactive: false
                badgeCount: mockBadgeCount
                taskProgress: mockProgress
                playingAudio: mockPlaying
                muted: mockMuted
                hasAudioStream: mockPlaying || mockMuted
                winIdList: [index]
            }
        }
    }
}
