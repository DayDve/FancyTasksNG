/*
    SPDX-FileCopyrightText: 2020 Aleix Pol Gonzalez <aleixpol@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

PipeWire.PipeWireSourceItem {
    id: pipeWireSourceItem

    readonly property alias hasThumbnail: pipeWireSourceItem.ready

    // Center it in the parent
    anchors.centerIn: parent

    // Maintain aspect ratio with smarter dimension calculation
    width: parent.width
    height: {
        // If we have valid source dimensions, calculate proper height
        if (sourceSize.width > 0 && sourceSize.height > 0) {
            return Math.min(parent.height, parent.width * (sourceSize.height / sourceSize.width));
        } else {
            // Fallback to a reasonable default
            return Math.min(parent.height, parent.width * 0.75);  // 4:3 aspect ratio as fallback
        }
    }

    nodeId: waylandItem.nodeId

    TaskManager.ScreencastingRequest {
        id: waylandItem
        uuid: thumbnailSourceItem.winId
    }
}
