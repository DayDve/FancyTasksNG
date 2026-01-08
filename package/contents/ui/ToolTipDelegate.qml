/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQml.Models
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

import org.kde.plasma.plasmoid

Loader {
    id: toolTipDelegate

    required property Task parentTask
    required property var rootIndex
    
    // Data properties needed for the inner components
    property string appName
    property int pidParent
    property bool isGroup
    property var windows: []
    readonly property bool isWin: windows.length > 0
    property var icon
    property url launcherUrl
    property bool isLauncher
    property bool isMinimized
    property string display
    property string genericName
    property var virtualDesktops: []
    property bool isOnAllVirtualDesktops
    property list<string> activities: []
    property bool smartLauncherCountVisible
    property int smartLauncherCount

    // Layout helper
    readonly property bool isVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int tooltipInstanceMaximumWidth: Kirigami.Units.gridUnit * 14

    // Mpris data
    readonly property Mpris.PlayerContainer playerData: mpris2Source.playerForLauncherUrl(launcherUrl, pidParent)

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // CLEANUP: Removed old logic checking for containsMouse/Window.visibility.
    // This component is now managed strictly by the main Loader.
    active: rootIndex !== undefined

    // Disable asynchronous loading to prevent size flickering
    asynchronous: false

    sourceComponent: isGroup ? groupToolTip : singleTooltip

    Component {
        id: singleTooltip

        ToolTipInstance {
            index: 0 
            submodelIndex: toolTipDelegate.rootIndex
            appPid: toolTipDelegate.pidParent
            display: toolTipDelegate.display
            isMinimized: toolTipDelegate.isMinimized
            isOnAllVirtualDesktops: toolTipDelegate.isOnAllVirtualDesktops
            virtualDesktops: toolTipDelegate.virtualDesktops
            activities: toolTipDelegate.activities
        }
    }

    Component {
        id: groupToolTip

        PlasmaComponents3.ScrollView {
            // Calculate implicit size based on content
            implicitWidth: leftPadding + rightPadding + Math.min(Screen.desktopAvailableWidth - 2 * Kirigami.Units.smallSpacing, Math.max(delegateModel.estimatedWidth, contentItem.contentItem.childrenRect.width))
            implicitHeight: topPadding + bottomPadding + Math.min(Screen.desktopAvailableHeight - 2 * Kirigami.Units.smallSpacing, Math.max(delegateModel.estimatedHeight, contentItem.contentItem.childrenRect.height))

            ListView {
                id: groupToolTipListView

                model: delegateModel
                orientation: isVerticalPanel ? ListView.Vertical : ListView.Horizontal
                reuseItems: true
                spacing: Kirigami.Units.gridUnit
            }

            DelegateModel {
                id: delegateModel

                readonly property int safeCount: toolTipDelegate.windows.length > 0 ? toolTipDelegate.windows.length : count

                readonly property real estimatedWidth: (toolTipDelegate.isVerticalPanel ? 1 : safeCount) * (toolTipDelegate.tooltipInstanceMaximumWidth + Kirigami.Units.gridUnit) - Kirigami.Units.gridUnit
                readonly property real estimatedHeight: (toolTipDelegate.isVerticalPanel ? safeCount : 1) * (toolTipDelegate.tooltipInstanceMaximumWidth / 2 + Kirigami.Units.gridUnit) - Kirigami.Units.gridUnit

                model: tasksModel
                rootIndex: toolTipDelegate.rootIndex
                onRootIndexChanged: groupToolTipListView.positionViewAtBeginning()

                delegate: ToolTipInstance {
                    required property var model

                    submodelIndex: tasksModel.makeModelIndex(toolTipDelegate.rootIndex.row, index)
                    appPid: model.AppPid
                    isMinimized: model.IsMinimized
                    isOnAllVirtualDesktops: model.IsOnAllVirtualDesktops
                    virtualDesktops: model.VirtualDesktops
                    activities: model.Activities
                }
            }
        }
    }
}
