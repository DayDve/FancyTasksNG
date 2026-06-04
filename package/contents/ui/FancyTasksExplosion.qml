/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

Item {
    id: manager
    visible: false

    /**
     * Spawns a removal effect for the given task item.
     * All geometry and property capture happens here.
     */
    function spawn(container, taskItem, isExplosion) {
        if (!taskItem || !taskItem.model) {
            return;
        }

        var pos = taskItem.mapToItem(container, 0, 0);
        
        // Creating object without initial properties to avoid 'Could not set initial property' errors
        // and then assigning them manually.
        var obj = effectComponent.createObject(container);
        if (obj) {
            obj.effectIcon = taskItem.model.decoration;
            obj.shouldExplode = isExplosion;
            obj.panelLocation = container.effectiveLocation;
            obj.originalX = pos.x;
            obj.originalY = pos.y;
            obj.originalWidth = taskItem.width;
            obj.originalHeight = taskItem.height;
        }
    }

    Component {
        id: effectComponent
        
        Item {
            id: effectRoot
            // Using 'var' to be flexible with icon types (strings, URLs, or icon objects)
            property var effectIcon
            property int panelLocation: PlasmaCore.Types.BottomEdge
            property bool shouldExplode: false
            property real originalX: 0
            property real originalY: 0
            property real originalWidth: 64
            property real originalHeight: 64

            x: originalX
            y: originalY
            width: originalWidth
            height: originalHeight

            // Ghost icon
            Kirigami.Icon {
                id: ghost
                anchors.fill: parent
                source: effectRoot.effectIcon
                opacity: 1
                Timer {
                    interval: 200
                    running: true
                    onTriggered: ghost.opacity = 0
                }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // Explosion animation
            AnimatedSprite {
                id: sprite
                visible: effectRoot.shouldExplode
                width: effectRoot.width + 10
                height: effectRoot.height + 10
                x: (effectRoot.width - width) / 2
                y: (effectRoot.height - height) / 2
                
                Component.onCompleted: {
                    if (effectRoot.panelLocation === PlasmaCore.Types.BottomEdge) {
                        y = effectRoot.height - height;
                    } else if (effectRoot.panelLocation === PlasmaCore.Types.TopEdge) {
                        y = 0;
                    } else if (effectRoot.panelLocation === PlasmaCore.Types.LeftEdge) {
                        x = 0;
                    } else if (effectRoot.panelLocation === PlasmaCore.Types.RightEdge) {
                        x = effectRoot.width - width;
                    }
                }

                interpolate: false
                running: effectRoot.shouldExplode
                source: "assets/smoke_explosion.png"
                frameCount: 24
                frameWidth: 312
                frameHeight: 256
                frameDuration: 30 
                loops: 1
                onFinished: if (ghost.opacity === 0) effectRoot.destroy();
            }

            Timer {
                interval: 450
                running: true
                onTriggered: if (!sprite.running) effectRoot.destroy();
            }
        }
    }
}
