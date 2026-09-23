/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../ui/code/singletones"

// A single row in ConfigPinnedApps.qml's pinned-launchers ListView: icon,
// name, drag-to-reorder, and remove button. Extracted out of the page file
// since it was the single largest, most self-contained chunk of it.
Item {
    id: pinnedAppDelegate

    required property var model
    required property int index

    required property var pageRoot
    required property var cardStyle
    required property var pinnedModel

    width: ListView.view.width
    height: beingDragged ? 0 : dragContent.implicitHeight
    clip: true

    property bool beingDragged: index === pinnedAppDelegate.pageRoot.dragItemIndex

    // Drop insertion indicator (arrows + line), shown above/below a row
    // while dragging.
    Component {
        id: dropIndicatorComponent
        Item {
            height: 2
            Canvas {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 10
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = pinnedAppDelegate.pageRoot.themeHighlightColor;
                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    ctx.lineTo(width, height / 2);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    ctx.fill();
                }
            }
            Canvas {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 10
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = pinnedAppDelegate.pageRoot.themeHighlightColor;
                    ctx.beginPath();
                    ctx.moveTo(width, 0);
                    ctx.lineTo(0, height / 2);
                    ctx.lineTo(width, height);
                    ctx.closePath();
                    ctx.fill();
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: 2
                color: pinnedAppDelegate.pageRoot.themeHighlightColor
            }
        }
    }

    // Top insertion indicator
    Loader {
        active: pinnedAppDelegate.pageRoot.isDragging && pinnedAppDelegate.pageRoot.dropItemIndex === pinnedAppDelegate.index && !pinnedAppDelegate.beingDragged
        anchors.left: parent.left
        anchors.right: parent.right
        y: -1
        z: 20
        sourceComponent: dropIndicatorComponent
    }

    // Bottom insertion indicator (insert at end of list)
    Loader {
        active: {
            if (!pinnedAppDelegate.pageRoot.isDragging || pinnedAppDelegate.beingDragged) return false;
            if (pinnedAppDelegate.pageRoot.dropItemIndex !== pinnedAppDelegate.pinnedModel.count) return false;
            var lastIdx = pinnedAppDelegate.pageRoot.dragItemIndex === pinnedAppDelegate.pinnedModel.count - 1
                ? pinnedAppDelegate.pinnedModel.count - 2
                : pinnedAppDelegate.pinnedModel.count - 1;
            return pinnedAppDelegate.index === lastIdx;
        }
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 20
        sourceComponent: dropIndicatorComponent
    }

    Item {
        id: dragContent
        width: pinnedAppDelegate.width
        implicitHeight: contentRow.implicitHeight + pinnedAppDelegate.cardStyle.padding * 2

        Drag.active: dragMouseArea.drag.active
        Drag.source: pinnedAppDelegate
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        states: [
            State {
                when: pinnedAppDelegate.beingDragged
                ParentChange {
                    target: dragContent
                    parent: pinnedAppDelegate.pageRoot
                }
                PropertyChanges {
                    dragContent.z: 100
                    dragContent.opacity: 0.8
                }
            }
        ]

        HoverHandler {
            id: rowHoverHandler
        }

        ToolTip.text: pinnedAppDelegate.model.comment || pinnedAppDelegate.model.name || ""
        ToolTip.visible: rowHoverHandler.hovered && !removeMouseArea.containsMouse && !pinnedAppDelegate.pageRoot.isDragging && ToolTip.text !== ""
        ToolTip.delay: 1000

        Rectangle {
            anchors.fill: parent
            color: rowHoverHandler.hovered ? pinnedAppDelegate.pageRoot.themeHoverColor : "transparent"
            opacity: 0.3
            radius: 3
            visible: !pinnedAppDelegate.pageRoot.isDragging
        }

        MouseArea {
            id: dragMouseArea
            anchors.fill: parent
            z: -1
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor

            drag.target: dragContent
            drag.axis: Drag.YAxis

            onPressed: {
                pinnedAppDelegate.pageRoot.dragItemIndex = pinnedAppDelegate.index;
                pinnedAppDelegate.pageRoot.isDragging = true;
            }

            onReleased: {
                pinnedAppDelegate.pageRoot.isDragging = false;

                var dropIdx = pinnedAppDelegate.pageRoot.dropItemIndex;
                var dragIdx = pinnedAppDelegate.pageRoot.dragItemIndex;

                pinnedAppDelegate.pageRoot.dragItemIndex = -1;
                pinnedAppDelegate.pageRoot.dropItemIndex = -1;

                var targetIndex = dropIdx <= dragIdx ? dropIdx : dropIdx - 1;
                if (targetIndex < 0) targetIndex = 0;
                if (targetIndex >= pinnedAppDelegate.pinnedModel.count) targetIndex = pinnedAppDelegate.pinnedModel.count - 1;

                if (dragIdx !== -1 && targetIndex !== dragIdx) {
                    pinnedAppDelegate.pageRoot.moveItem(dragIdx, targetIndex);
                } else {
                    pinnedAppDelegate.pageRoot.refreshPinnedAppsModel();
                }
            }
        }

        RowLayout {
            id: contentRow
            anchors.fill: parent
            anchors.margins: pinnedAppDelegate.cardStyle.padding
            spacing: pinnedAppDelegate.cardStyle.spacing

            Kirigami.Icon {
                source: pinnedAppDelegate.model.icon
                Layout.preferredWidth: pinnedAppDelegate.cardStyle.iconSize
                Layout.preferredHeight: pinnedAppDelegate.cardStyle.iconSize
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                Label {
                    Layout.fillWidth: true
                    text: pinnedAppDelegate.model.name
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: pinnedAppDelegate.model.genericName || ""
                    elide: Text.ElideRight
                    font.pointSize: pinnedAppDelegate.pageRoot.themeSmallFont.pointSize
                    opacity: 0.7
                }
            }

            Item {
                id: removeButtonContainer
                Layout.preferredWidth: pinnedAppDelegate.cardStyle.iconSize
                Layout.preferredHeight: pinnedAppDelegate.cardStyle.iconSize
                visible: !pinnedAppDelegate.beingDragged

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: pinnedAppDelegate.pageRoot.iconSizeSmall
                    height: pinnedAppDelegate.pageRoot.iconSizeSmall
                    source: "user-trash"
                    isMask: true
                    color: removeMouseArea.containsMouse ? pinnedAppDelegate.pageRoot.themeNegativeTextColor : pinnedAppDelegate.pageRoot.themeTextColor
                }

                MouseArea {
                    id: removeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        let currentLaunchers = Array.from(pinnedAppDelegate.pageRoot.pinnedLaunchers);
                        currentLaunchers.splice(pinnedAppDelegate.index, 1);
                        pinnedAppDelegate.pageRoot.cfg_launchers = currentLaunchers;
                        pinnedAppDelegate.pageRoot.refreshPinnedAppsModel();
                    }
                }

                ToolTip.text: Wrappers.i18n("Remove")
                ToolTip.visible: removeMouseArea.containsMouse
                ToolTip.delay: 1000
            }
        }
    }
}
