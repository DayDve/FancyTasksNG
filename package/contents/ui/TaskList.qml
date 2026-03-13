/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

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
        const configMaxStripes = (tasks && tasks.plasmoid && tasks.plasmoid.configuration) ? tasks.plasmoid.configuration.maxStripes : 1;
        if (configMaxStripes === 1) {
            return 1;
        }

        // The maximum number of stripes allowed by the applet's size
        const firstChild = (children.length > 0) ? children[0] : null;

        if (!firstChild || !tasksModel) {
            return 1;
        }

        // Use a minimum of 1 for dimensions to avoid division by zero or Infinity
        const effectiveWidth = Math.max(1, tasks.width);
        const effectiveHeight = Math.max(1, tasks.height);

        const stripeSizeLimit = tasks.vertical
            ? Math.floor(effectiveWidth / firstChild.implicitWidth)
            : Math.floor(effectiveHeight / firstChild.implicitHeight)
        const maxStripes = Math.min(configMaxStripes, Math.max(1, stripeSizeLimit))

        if (tasks.plasmoid.configuration.forceStripes) {
            return maxStripes;
        }

        // The number of tasks that will fill a "stripe" before starting the next one
        const maxTasksPerStripe = Math.max(1, tasks.vertical
            ? Math.ceil(effectiveHeight / LayoutMetrics.preferredMinHeight())
            : Math.ceil(effectiveWidth / LayoutMetrics.preferredMinWidth()))

        const taskCount = tasksModel ? tasksModel.count : 0;
        return Math.max(1, Math.min(Math.ceil(taskCount / maxTasksPerStripe), maxStripes))
    }

    readonly property int orthogonalCount: {
        const taskCount = tasksModel ? tasksModel.count : 0;
        return Math.max(1, Math.ceil(taskCount / stripeCount));
    }

    rows: tasks.vertical ? orthogonalCount : stripeCount
    columns: tasks.vertical ? stripeCount : orthogonalCount
}
