/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// A task's icon going up in cartoon flames after Force Quit, in its place
// over the panel: the flames from the sprite engulf the icon, which fades
// under them, then they turn into smoke puffs that break up. Created by
// main.qml, it destroys itself when done.
Item {
    id: root

    property var iconSource
    property int edge: PlasmaCore.Types.BottomEdge
    // Frames are stepped by hand: an AnimatedSprite that runs out of loops
    // shows its first frame again for a moment before it reports finished.
    property real frame: 0

    Kirigami.Icon {
        id: icon
        anchors.fill: parent
        source: root.iconSource
    }
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 120 }
        NumberAnimation { target: icon; property: "opacity"; to: 0; duration: 380; easing.type: Easing.InQuad }
    }

    // The flames rise off the panel edge: turned for top and side panels.
    // Square like the icon, so turning it keeps its place.
    Item {
        anchors.fill: parent
        rotation: root.edge === PlasmaCore.Types.TopEdge ? 180
            : root.edge === PlasmaCore.Types.LeftEdge ? 90
            : root.edge === PlasmaCore.Types.RightEdge ? -90 : 0

        AnimatedSprite {
            id: sprite
            width: root.width * 1.15
            height: width
            x: (root.width - width) / 2
            y: root.height - height + root.height * 0.05
            interpolate: false
            running: true
            paused: true
            currentFrame: Math.min(frameCount - 1, Math.floor(root.frame))
            source: "assets/blaze.png"
            frameCount: 24
            frameWidth: 256
            frameHeight: 256
            frameDuration: 40
        }
    }
    NumberAnimation {
        target: root
        property: "frame"
        from: 0
        to: sprite.frameCount
        duration: sprite.frameCount * sprite.frameDuration
        running: true
        onFinished: root.destroy()
    }
}
