/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

import "previewtasks.js" as PreviewTasks

// A choice drawn as a small panel with the widget's real task buttons:
// the page's settings with this choice's values (overrides, keyed by
// cfg_ name) put over them.
AbstractButton {
    id: card

    required property var cfgPage
    property var overrides: ({})

    checkable: false
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.RadioButton
    Accessible.name: card.text

    readonly property real panelThickness: Kirigami.Units.gridUnit * 2
    implicitWidth: Kirigami.Units.gridUnit * 9
    implicitHeight: frame.height + label.implicitHeight + Kirigami.Units.smallSpacing

    // The page's cfg_ values, with this card's overrides on top.
    // A classic button is far wider than a card by default; there they're
    // cut to share the card, which shows the mode, not the exact panel.
    readonly property var settings: new Proxy({}, {
        get: (target, name) => {
            const key = String(name);
            const value = key in card.overrides ? card.overrides[key] : card.cfgPage[key];
            if (key === "cfg_maxButtonLength")
                return Math.min(value, card.classicButtonLength);
            if (key === "cfg_fitButtonToText")
                return false;
            if (key === "cfg_disableButtonSvg" && !card.buttonBackground)
                return true;
            return value;
        }
    })

    readonly property bool classic: card.settings.cfg_iconOnly === 0
    // How many of the mock tasks to show in each mode; a classic button
    // needs room for its title, so fewer of them. With one, it's the active
    // task (a group when windows are combined).
    property int iconTasks: 3
    property int classicTasks: 2
    // Draw the buttons without their background, to show what's under it.
    property bool buttonBackground: true
    readonly property int maxTasks: card.classic ? card.classicTasks : card.iconTasks
    // A classic button's width here: its share of the card. Worked out
    // from the card's own width, not the panel's, which reads as 0 through
    // the settings proxy when first laid out and isn't re-evaluated.
    readonly property int classicButtonLength: Math.floor((card.implicitWidth - Kirigami.Units.largeSpacing * 2) / Math.max(1, card.maxTasks))

    ListModel {
        id: taskModel
    }
    readonly property int groupMode: card.settings.cfg_groupingStrategy
    readonly property bool groupPopups: card.settings.cfg_groupPopups
    function fillTasks(): void {
        PreviewTasks.fill(taskModel, card.groupMode, card.groupPopups, true);
        if (card.maxTasks === 1) {
            taskModel.remove(0); // Leaves the active task (row 1) first.
        }
        while (taskModel.count > card.maxTasks)
            taskModel.remove(taskModel.count - 1);
    }
    onMaxTasksChanged: fillTasks()
    onGroupModeChanged: fillTasks()
    onGroupPopupsChanged: fillTasks()
    Component.onCompleted: fillTasks()

    Rectangle {
        id: frame
        width: parent.width
        height: card.panelThickness + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.alternateBackgroundColor
        border.width: card.checked || card.visualFocus ? 2 : 1
        border.color: card.checked || card.visualFocus || card.hovered
            ? Kirigami.Theme.highlightColor
            : Qt.alpha(Kirigami.Theme.textColor, 0.25)
        clip: true

        PreviewPanel {
            cfgPage: card.settings
            location: PlasmaCore.Types.BottomEdge
            previewModel: taskModel
            activeRow: card.maxTasks === 1 ? 0 : 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Kirigami.Units.largeSpacing
            height: card.panelThickness
        }
    }

    Label {
        id: label
        anchors.top: frame.bottom
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: card.text
    }

    // The buttons inside only show; the card takes the clicks.
    contentItem: Item {}
    background: Item {}
}
