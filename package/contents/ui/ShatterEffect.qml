/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Particles
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// A closed task's icon bursting in its place over the panel: a short swell
// and flash, then it breaks into ragged pieces that fly off and fade, with a
// fireball, sparks and a puff of smoke. Created by main.qml, it destroys
// itself when done.
Item {
    id: root

    property var iconSource
    property int edge: PlasmaCore.Types.BottomEdge
    // Free space in the panel's window past the icon's far side: the pieces
    // and particles stay within the icon and this, the window clips the rest.
    property real room: 0
    property int duration: 650
    property real progress: 0
    // A still frame for the settings: nothing runs, `progress` is set from
    // outside and the item stays.
    property bool still: false

    // Particles are laid out for "up" and turned, like in BurnEffect.
    readonly property int turn: edge === PlasmaCore.Types.TopEdge ? 180
        : edge === PlasmaCore.Types.LeftEdge ? 90
        : edge === PlasmaCore.Types.RightEdge ? -90 : 0
    readonly property bool horizontal: edge === PlasmaCore.Types.TopEdge || edge === PlasmaCore.Types.BottomEdge

    // How far the pieces may go: away from the panel edge, along the panel,
    // and toward the panel edge.
    readonly property real awayPad: Math.min(room, width * 1.2)
    readonly property real sidePad: width * 1.0
    readonly property real edgePad: width * 0.4
    // From the icon's center, away from the panel edge.
    readonly property real reach: awayPad + height / 2

    // A particle at `speed` px/s lives no longer than it takes to reach the
    // window's edge (ms), and no longer than `maximum`.
    function lifeFor(speed, maximum) {
        return Math.max(60, Math.min(maximum, reach / Math.max(1, speed) * 1000 * 0.9));
    }

    Kirigami.Icon {
        id: icon
        anchors.fill: parent
        source: root.iconSource
        visible: false
    }

    ShaderEffect {
        id: shader
        x: root.horizontal ? -root.sidePad : (root.edge === PlasmaCore.Types.LeftEdge ? -root.edgePad : -root.awayPad)
        y: root.horizontal ? (root.edge === PlasmaCore.Types.TopEdge ? -root.edgePad : -root.awayPad) : -root.sidePad
        width: root.horizontal ? root.width + root.sidePad * 2 : root.width + root.awayPad + root.edgePad
        height: root.horizontal ? root.height + root.awayPad + root.edgePad : root.height + root.sidePad * 2
        property var source: ShaderEffectSource {
            sourceItem: icon
            hideSource: true
        }
        property real progress: root.progress
        property real seed: Math.random() * 50
        // The icon's place in this quad, 0..1 (see shatter.frag).
        property real iconX: -x / width
        property real iconY: -y / height
        property real iconW: root.width / width
        property real iconH: root.height / height
        property real awayX: root.edge === PlasmaCore.Types.LeftEdge ? 1 : root.edge === PlasmaCore.Types.RightEdge ? -1 : 0
        property real awayY: root.edge === PlasmaCore.Types.TopEdge ? 1 : root.edge === PlasmaCore.Types.BottomEdge ? -1 : 0
        fragmentShader: Qt.resolvedUrl("shaders/shatter.frag.qsb")
    }

    NumberAnimation {
        target: root
        property: "progress"
        from: 0; to: 1
        running: !root.still
        duration: root.duration
        onFinished: root.destroy(800)
    }

    // The particles burst a moment in, when the icon breaks.
    Timer {
        running: !root.still
        interval: root.duration * 0.06
        onTriggered: {
            flash.burst(1);
            fire.burst(28);
            sparks.burst(36);
        }
    }
    Timer {
        running: !root.still
        interval: root.duration * 0.15
        onTriggered: smoke.burst(12)
    }

    // Square like the icon, so turning it keeps its place.
    Item {
        anchors.fill: parent
        rotation: root.turn

        ParticleSystem {
            anchors.fill: parent

            Emitter {
                id: smoke
                group: "smoke"
                enabled: false
                x: root.width * 0.3; y: root.height * 0.3
                width: root.width * 0.4; height: root.height * 0.4
                lifeSpan: root.lifeFor(root.height * 1.0, 800)
                lifeSpanVariation: lifeSpan / 4
                size: root.width * 0.45
                endSize: Math.min(root.width * 1.1, root.width * 0.45 + root.reach * 0.6)
                velocity: AngleDirection {
                    angle: 270; angleVariation: 70
                    magnitude: root.height * 0.7; magnitudeVariation: root.height * 0.3
                }
            }
            Emitter {
                id: flash
                group: "flash"
                enabled: false
                x: root.width / 2; y: root.height / 2
                lifeSpan: 200
                size: root.width * 1.2
                endSize: root.width * 2.2
            }
            Emitter {
                id: fire
                group: "fire"
                enabled: false
                x: root.width * 0.25; y: root.height * 0.25
                width: root.width * 0.5; height: root.height * 0.5
                lifeSpan: root.lifeFor(root.height * 2.6, 260)
                lifeSpanVariation: lifeSpan / 3
                size: root.width * 0.4
                sizeVariation: root.width * 0.1
                endSize: root.width * 0.05
                velocity: AngleDirection {
                    angle: 270; angleVariation: 110
                    magnitude: root.height * 1.8; magnitudeVariation: root.height * 0.8
                }
            }
            Emitter {
                id: sparks
                group: "spark"
                enabled: false
                x: root.width * 0.35; y: root.height * 0.35
                width: root.width * 0.3; height: root.height * 0.3
                lifeSpan: root.lifeFor(root.height * 5, 550)
                lifeSpanVariation: lifeSpan / 3
                size: Math.max(2, root.width * 0.07)
                endSize: 1
                velocity: AngleDirection {
                    angle: 270; angleVariation: 120
                    magnitude: root.height * 3.5; magnitudeVariation: root.height * 1.5
                }
                acceleration: PointDirection { y: root.height * 5 }
            }

            ImageParticle {
                groups: ["smoke"]
                source: "qrc:///particleresources/glowdot.png"
                color: "#60383230"
                colorVariation: 0.05
            }
            ImageParticle {
                groups: ["flash"]
                source: "qrc:///particleresources/glowdot.png"
                color: "#c0fff4d0"
            }
            ImageParticle {
                groups: ["fire"]
                source: "qrc:///particleresources/glowdot.png"
                color: "#ffff6a18"
                greenVariation: 0.2
                alpha: 0.7
            }
            ImageParticle {
                groups: ["spark"]
                source: "qrc:///particleresources/glowdot.png"
                color: "#ffffe080"
            }
        }
    }
}
