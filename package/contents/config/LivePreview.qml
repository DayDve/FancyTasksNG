/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtCore as QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import "../ui/code/singletones"
import org.kde.plasma.core as PlasmaCore

Item {
    id: previewRoot
    Layout.fillWidth: true
    Layout.maximumWidth: 650
    Layout.alignment: Qt.AlignLeft
    implicitHeight: previewSettings.showLivePreview ? 290 : titleLayout.height
    clip: false

    required property var cfg_page
    property int location: PlasmaCore.Types.BottomEdge

    // How the preview itself is shown, not a widget setting: kept out of
    // main.xml so toggling it doesn't ask to Apply.
    QtCore.Settings {
        id: previewSettings
        category: "FancyTasksNGLivePreview"
        property bool showLivePreview: true
        property int previewSize: 48
    }

    readonly property bool cfg_showToolTips: cfg_page.cfg_showToolTips

    // Mock tasks for the real delegates, with TasksModel role names; the
    // mock* roles stand for what the delegates otherwise get from the app
    // (notification count, progress, audio).
    ListModel {
        id: taskModel
    }

    readonly property int groupMode: cfg_page.cfg_groupingStrategy
    readonly property bool groupPopups: cfg_page.cfg_groupPopups

    onGroupModeChanged: rebuildTaskModel()
    onGroupPopupsChanged: rebuildTaskModel()
    Component.onCompleted: rebuildTaskModel()

    function mockTask(icon, name, extra) {
        return Object.assign({
            decoration: icon, display: name, AppId: "",
            IsWindow: true, IsLauncher: false, IsStartup: false,
            IsActive: false, IsMinimized: false, IsDemandingAttention: false,
            IsGroupParent: false, ChildCount: 0,
            mockBadgeCount: 0, mockProgress: -1, mockPlaying: false, mockMuted: false
        }, extra);
    }

    function rebuildTaskModel() {
        taskModel.clear();
        const grouped = groupMode !== 0 && groupPopups;
        const sideBySide = groupMode !== 0 && !groupPopups;
        taskModel.append(mockTask("plasmadiscover", "Discover", { IsMinimized: true, mockProgress: 0.7 }));
        taskModel.append(mockTask("org.kde.dolphin", "Dolphin", grouped
            ? { IsActive: true, IsGroupParent: true, ChildCount: 2, mockBadgeCount: 3 }
            : { IsActive: true, mockBadgeCount: 3 }));
        if (sideBySide) {
            taskModel.append(mockTask("org.kde.dolphin", "Dolphin", {}));
        }
        taskModel.append(mockTask("utilities-terminal", "Konsole", { mockBadgeCount: 12 }));
        taskModel.append(mockTask("internet-web-browser", "Browser", { mockPlaying: true }));
        if (groupMode === 0) {
            taskModel.append(mockTask("org.kde.dolphin", "Dolphin", {}));
        }
    }

    readonly property bool isVertical: location === PlasmaCore.Types.LeftEdge || location === PlasmaCore.Types.RightEdge
    readonly property int simulatedThickness: previewSettings.previewSize


    RowLayout {
        id: titleLayout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: 0
        z: 10
        spacing: Kirigami.Units.smallSpacing

        CheckBox {
            id: headerToggle
            leftPadding: 0
            checked: previewSettings.showLivePreview
            onToggled: previewSettings.showLivePreview = checked
        }

        Label {
            text: Wrappers.i18n("Preview")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.textColor
        }
    }

 
    GroupBox {
        id: groupBox
        anchors.top: titleLayout.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        padding: Kirigami.Units.smallSpacing
        topPadding: Kirigami.Units.mediumSpacing
        visible: previewSettings.showLivePreview
    }

    ColumnLayout {
        anchors.fill: groupBox
        anchors.margins: Kirigami.Units.smallSpacing
        visible: groupBox.visible
        spacing: Kirigami.Units.largeSpacing

        // Inner workspace area
        Rectangle {
            id: innerPreviewArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1
            radius: Kirigami.Units.smallSpacing
            clip: true

            // 1. Controls Overlay (Space-saving & Context-aware)
            Kirigami.ShadowedRectangle {
                id: controlsOverlay
                z: 100
                anchors {
                    top: previewRoot.location === PlasmaCore.Types.TopEdge ? undefined : parent.top
                    bottom: previewRoot.location === PlasmaCore.Types.TopEdge ? parent.bottom : undefined
                    right: previewRoot.location === PlasmaCore.Types.RightEdge ? undefined : parent.right
                    left: previewRoot.location === PlasmaCore.Types.RightEdge ? parent.left : undefined
                    margins: Kirigami.Units.largeSpacing
                }
                
                width: overlayLayout.implicitWidth + Kirigami.Units.mediumSpacing * 2
                height: overlayLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
                
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.backgroundColor
                opacity: 0.85
                
                shadow {
                    size: Kirigami.Units.smallSpacing
                    color: Qt.rgba(0, 0, 0, 0.3)
                }

                RowLayout {
                    id: overlayLayout
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.mediumSpacing

                    Label {
                        text: Wrappers.i18n("Panel thickness (preview):")
                        opacity: 0.7
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                    SpinBox {
                        id: localSizeSpinner
                        from: 24
                        to: 128
                        value: previewSettings.previewSize
                        onValueModified: { previewSettings.previewSize = value }
                        stepSize: 2
                        editable: true

                        ToolTip.text: Wrappers.i18n("This setting only changes the appearance of this preview and does not affect your actual system panel.")
                        ToolTip.visible: hovered
                        ToolTip.delay: Kirigami.Units.toolTipDelay

                        // Smaller SpinBox for overlay
                        contentItem: TextInput {
                            z: 2
                            text: localSizeSpinner.textFromValue(localSizeSpinner.value, localSizeSpinner.locale)
                            font: localSizeSpinner.font
                            color: Kirigami.Theme.textColor
                            selectionColor: Kirigami.Theme.highlightColor
                            selectedTextColor: Kirigami.Theme.highlightedTextColor
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !localSizeSpinner.editable
                            validator: localSizeSpinner.validator
                            inputMethodHints: Qt.ImhDigitsOnly
                        }
                    }
                    Label {
                        text: "px"
                        opacity: 0.5
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

                // Desktop Workspace Background (Local Asset)
                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: Qt.resolvedUrl("../ui/assets/preview_background.png")
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.9 // Vibrant and "Next-gen" look
                    z: -1 // Behind the panel

                    // Safety fallback: Color if image fails to load
                    Rectangle {
                        anchors.fill: parent
                        color: Kirigami.Theme.backgroundColor
                        opacity: 0.2
                        visible: parent.status !== Image.Ready
                    }
                }

                // The panel, with the widget's real task delegates in it.
                PreviewPanel {
                    id: dummyPanel
                    cfgPage: previewRoot.cfg_page
                    location: previewRoot.location
                    previewModel: taskModel
                    hoveredRow: 1
                    activeRow: 1

                    width: previewRoot.isVertical ? previewRoot.simulatedThickness : parent.width
                    height: previewRoot.isVertical ? parent.height : previewRoot.simulatedThickness
                    x: previewRoot.isVertical
                        ? (previewRoot.location === PlasmaCore.Types.LeftEdge ? 0 : parent.width - width)
                        : 0
                    y: !previewRoot.isVertical
                        ? (previewRoot.location === PlasmaCore.Types.TopEdge ? 0 : parent.height - height)
                        : 0
                }
            }
    }

    // --- Mock tooltip ---
    // Placed like the real one: beside the hovered task's tooltipAnchor,
    // which already accounts for its zoomed icon.
    Kirigami.ShadowedRectangle {
        id: mockToolTip
        z: 999
        parent: innerPreviewArea

        readonly property var targetTask: dummyPanel.currentHoveredTask
        visible: targetTask !== null

        Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
        Kirigami.Theme.inherit: false

        color: Kirigami.Theme.backgroundColor
        radius: 4
        shadow.size: 12
        shadow.color: Qt.rgba(0, 0, 0, 0.3)
        shadow.yOffset: 2

        implicitWidth: mainLayout.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: mainLayout.implicitHeight + Kirigami.Units.smallSpacing * 2

        readonly property var anchorItem: targetTask ? targetTask.tooltipAnchor : null
        readonly property real anchorX: anchorItem ? dummyPanel.x + dummyPanel.taskList.x + targetTask.x + anchorItem.x : 0
        readonly property real anchorY: anchorItem ? dummyPanel.y + dummyPanel.taskList.y + targetTask.y + anchorItem.y : 0
        readonly property real anchorW: anchorItem ? anchorItem.width : 0
        readonly property real anchorH: anchorItem ? anchorItem.height : 0

        x: {
            if (previewRoot.location === PlasmaCore.Types.LeftEdge)
                return anchorX + anchorW + Kirigami.Units.smallSpacing;
            if (previewRoot.location === PlasmaCore.Types.RightEdge)
                return anchorX - width - Kirigami.Units.smallSpacing;
            return Math.max(Kirigami.Units.smallSpacing,
                            Math.min(anchorX + anchorW / 2 - width / 2, parent.width - width - Kirigami.Units.smallSpacing));
        }
        y: {
            if (previewRoot.location === PlasmaCore.Types.TopEdge)
                return anchorY + anchorH + Kirigami.Units.smallSpacing;
            if (!previewRoot.isVertical)
                return anchorY - height - Kirigami.Units.smallSpacing;
            return Math.max(Kirigami.Units.smallSpacing,
                            Math.min(anchorY + anchorH / 2 - height / 2, parent.height - height - Kirigami.Units.smallSpacing));
        }

        ColumnLayout {
            id: mainLayout
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            // MODE 1: Thumbnail + Overlays (cfg_showToolTips === true)
            ColumnLayout {
                visible: previewRoot.cfg_showToolTips
                spacing: Kirigami.Units.smallSpacing
                
                // 1. App Name Header
                Label {
                    text: Wrappers.i18n("App name")
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    color: Kirigami.Theme.textColor
                    opacity: 1.0
                }

                // 2. Thumbnail Container with Overlays
                Item {
                    id: thumbnailArea
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    Layout.preferredHeight: Math.round(Layout.preferredWidth / 1.6)
                    
                    Rectangle {
                        anchors.fill: parent
                        color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.15)
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
                        radius: 4
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: Qt.resolvedUrl("../ui/assets/preview_thumbnail.png")
                            fillMode: Image.PreserveAspectCrop
                        }
                    }

                    // Overlay Title (Top-Left)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: Kirigami.Units.smallSpacing
                        
                        height: overlayText.implicitHeight + Kirigami.Units.smallSpacing
                        width: Math.min(overlayText.implicitWidth + Kirigami.Units.mediumSpacing * 2, parent.width - Kirigami.Units.gridUnit * 3)
                        
                        color: Qt.rgba(0, 0, 0, 0.45)
                        radius: 3

                        Label {
                            id: overlayText
                            anchors.centerIn: parent
                            text: Wrappers.i18n("Window title")
                            color: "white"
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                            elide: Text.ElideRight
                            width: parent.width - Kirigami.Units.smallSpacing
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Overlay Close Button (Top-Right)
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Kirigami.Units.smallSpacing
                        width: Kirigami.Units.gridUnit * 1.2
                        height: width
                        color: Qt.rgba(0, 0, 0, 0.45)
                        radius: 3
                        
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.small
                            height: width
                            source: "window-close"
                            opacity: 0.9
                            color: "white"
                        }
                    }
                }
            }

            // MODE 2: List/Text-only (cfg_showToolTips === false)
            RowLayout {
                visible: !previewRoot.cfg_showToolTips
                spacing: Kirigami.Units.mediumSpacing
                
                Kirigami.Icon {
                    source: "system-file-manager"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Layout.preferredWidth
                }

                Label {
                    text: Wrappers.i18n("%1 — %2", Wrappers.i18n("Window title"), Wrappers.i18n("App name"))
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                }
            }
        }
    }
}
