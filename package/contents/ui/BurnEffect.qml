/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Particles
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// A task's icon burning away after Force Quit, in its place over the panel:
// a ragged glowing front eats it from the panel edge on, the part ahead of
// the front chars, flames, sparks and a little smoke go off the front.
// Created by main.qml, it destroys itself when done.
Item {
    id: root

    property var iconSource
    property int edge: PlasmaCore.Types.BottomEdge
    // Free space in the panel's window past the icon's far side: the
    // particles stay within the icon and this, the window clips the rest.
    property real room: 0
    property int duration: 950
    property real progress: 0

    // Fire goes off the panel edge into the screen, where the window has
    // room: up from a bottom panel, down from a top one, sideways from the
    // side ones. Particles are laid out for "up" and turned.
    readonly property int turn: edge === PlasmaCore.Types.TopEdge ? 180
        : edge === PlasmaCore.Types.LeftEdge ? 90
        : edge === PlasmaCore.Types.RightEdge ? -90 : 0

    // The front's speed, px/s: flames must outrun it or they trail behind
    // the front.
    readonly property real frontSpeed: height * 1.3 / 0.7 / (duration / 1000)
    // Distance from the front to the icon's far side, as the shader moves
    // it (on average over its noise).
    readonly property real frontDistance: {
        const front = progress * 1.3 - 0.05;
        return Math.max(0, Math.min(1, 1 - (front - 0.2) / 0.7)) * height;
    }
    // How far a particle may travel from the front before it would be cut.
    readonly property real reach: frontDistance + room

    // A particle at `speed` px/s lives no longer than it takes to reach the
    // window's edge (ms), and no longer than `maximum`.
    function lifeFor(speed, maximum) {
        return Math.max(0, Math.min(maximum, reach / Math.max(1, speed) * 1000 * 0.85));
    }

    Kirigami.Icon {
        id: icon
        anchors.fill: parent
        source: root.iconSource
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent
        property var source: ShaderEffectSource {
            sourceItem: icon
            hideSource: true
        }
        property real progress: root.progress
        property real time: 0
        property real seed: Math.random() * 50
        // t = 0 at the panel edge, 1 at the far side (see burn.frag).
        property real axisX: root.edge === PlasmaCore.Types.LeftEdge ? 1 : root.edge === PlasmaCore.Types.RightEdge ? -1 : 0
        property real axisY: root.edge === PlasmaCore.Types.TopEdge ? 1
            : (root.edge === PlasmaCore.Types.LeftEdge || root.edge === PlasmaCore.Types.RightEdge) ? 0 : -1
        property real axisC: (root.edge === PlasmaCore.Types.TopEdge || root.edge === PlasmaCore.Types.LeftEdge) ? 0 : 1
        fragmentShader: Qt.resolvedUrl("shaders/burn.frag.qsb")
    }

    NumberAnimation {
        target: shader
        property: "time"
        from: 0; to: 1000; duration: 1000000
        running: true
    }
    NumberAnimation {
        id: burnAnim
        target: root
        property: "progress"
        from: 0; to: 1
        running: true
        duration: root.duration
        onFinished: root.destroy(900)
    }

    // Square like the icon, so turning it keeps its place.
    Item {
        anchors.fill: parent
        rotation: root.turn

        ParticleSystem {
            id: particles
            anchors.fill: parent

            Emitter {
                group: "smoke"
                enabled: burnAnim.running && root.progress > 0.25
                x: root.width * 0.2
                width: root.width * 0.6
                y: root.frontDistance - root.height * 0.15
                height: root.height * 0.1
                emitRate: 18
                lifeSpan: root.lifeFor(root.height * 0.85, 900)
                lifeSpanVariation: lifeSpan / 4
                size: root.width * 0.35
                endSize: Math.min(root.width * 0.8, root.width * 0.35 + root.reach * 0.5)
                velocity: AngleDirection {
                    angle: 270; angleVariation: 15
                    magnitude: root.height * 0.7; magnitudeVariation: root.height * 0.15
                }
            }
            Emitter {
                group: "flame"
                enabled: burnAnim.running && root.progress < 0.92
                x: root.width * 0.1
                width: root.width * 0.8
                y: root.frontDistance - root.height * 0.05
                height: root.height * 0.08
                emitRate: 320
                lifeSpan: root.lifeFor(root.frontSpeed * 1.5, 150)
                lifeSpanVariation: lifeSpan / 3
                size: root.width * 0.2
                sizeVariation: root.width * 0.05
                endSize: root.width * 0.02
                velocity: AngleDirection {
                    angle: 270; angleVariation: 8
                    magnitude: root.frontSpeed * 1.25; magnitudeVariation: root.frontSpeed * 0.25
                }
            }
            // The hot core, right on the front.
            Emitter {
                group: "core"
                enabled: burnAnim.running && root.progress < 0.9
                x: root.width * 0.15
                width: root.width * 0.7
                y: root.frontDistance - root.height * 0.03
                height: root.height * 0.05
                emitRate: 200
                lifeSpan: root.lifeFor(root.frontSpeed * 1.2, 90)
                lifeSpanVariation: lifeSpan / 3
                size: root.width * 0.11
                endSize: root.width * 0.02
                velocity: AngleDirection {
                    angle: 270; angleVariation: 6
                    magnitude: root.frontSpeed * 1.05; magnitudeVariation: root.frontSpeed * 0.15
                }
            }
            Emitter {
                group: "spark"
                enabled: burnAnim.running && root.progress < 0.95
                x: root.width * 0.1
                width: root.width * 0.8
                y: root.frontDistance - root.height * 0.04
                height: root.height * 0.08
                emitRate: 30
                lifeSpan: root.lifeFor(root.frontSpeed * 2, 700)
                lifeSpanVariation: lifeSpan / 3
                size: Math.max(2, root.width * 0.06)
                endSize: 1
                velocity: AngleDirection {
                    angle: 270; angleVariation: 35
                    magnitude: root.frontSpeed * 1.4; magnitudeVariation: root.frontSpeed * 0.6
                }
            }

            ImageParticle {
                groups: ["smoke"]
                source: "qrc:///particleresources/glowdot.png"
                color: "#55302a26"
                colorVariation: 0.05
            }
            ImageParticle {
                groups: ["flame"]
                source: "qrc:///particleresources/glowdot.png"
                color: "#ffff5a10"
                greenVariation: 0.15
                alpha: 0.55
            }
            ImageParticle {
                groups: ["core"]
                source: "qrc:///particleresources/glowdot.png"
                color: "#ffffd060"
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
