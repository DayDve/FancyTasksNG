/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import "code/layoutmetrics.js" as LayoutMetrics

GridLayout {
    required property var tasks
    required property var tasksModel

    property bool animating: false

    rowSpacing: tasks.plasmoid.configuration.taskSpacingSize
    columnSpacing: tasks.plasmoid.configuration.taskSpacingSize

    property int animationsRunning: 0
    onAnimationsRunningChanged: {
        animating = animationsRunning > 0;
    }

    readonly property real minimumWidth: children
        .filter(item => item.visible && item.width > 0)
        .reduce((minimumWidth, item) => Math.min(minimumWidth, item.width), Infinity)

    readonly property int stripeCount: {
        if (tasks.plasmoid.configuration.maxStripes === 1) {
            return 1;
        }

        // The maximum number of stripes allowed by the applet's size
        const stripeSizeLimit = tasks.vertical
            ? Math.floor(tasks.width / children[0].implicitWidth)
            : Math.floor(tasks.height / children[0].implicitHeight)
        const maxStripes = Math.min(tasks.plasmoid.configuration.maxStripes, stripeSizeLimit)

        if (tasks.plasmoid.configuration.forceStripes) {
            return maxStripes;
        }

        // The number of tasks that will fill a "stripe" before starting the next one
        const maxTasksPerStripe = tasks.vertical
            ? Math.ceil(tasks.height / LayoutMetrics.preferredMinHeight())
            : Math.ceil(tasks.width / LayoutMetrics.preferredMinWidth())

        return Math.min(Math.ceil(tasksModel.count / maxTasksPerStripe), maxStripes)
    }

    readonly property int orthogonalCount: {
        return Math.ceil(tasksModel.count / stripeCount);
    }

    rows: tasks.vertical ? orthogonalCount : stripeCount
    columns: tasks.vertical ? stripeCount : orthogonalCount
}
