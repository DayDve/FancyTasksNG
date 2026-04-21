/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

Item {
    id: manager
    visible: false

    /**
     * Spawns a removal effect for the given task item.
     * All geometry and property capture happens here.
     */
    function spawn(container, taskItem, isExplosion) {
        if (!taskItem) {
            return;
        }

        let pos = taskItem.mapToItem(container, 0, 0);
        
        effectComponent.createObject(container, {
            iconSource: taskItem.model.decoration,
            shouldExplode: isExplosion,
            panelLocation: container.effectiveLocation,
            originalX: pos.x,
            originalY: pos.y,
            originalWidth: taskItem.width,
            originalHeight: taskItem.height
        });
    }

    Component {
        id: effectComponent
        
        Item {
            id: root
            property string iconSource: ""
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
                source: root.iconSource
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
                visible: root.shouldExplode
                width: root.width + 10
                height: root.height + 10
                x: (root.width - width) / 2
                y: (root.height - height) / 2
                
                Component.onCompleted: {
                    if (root.panelLocation === PlasmaCore.Types.BottomEdge) {
                        y = root.height - height;
                    } else if (root.panelLocation === PlasmaCore.Types.TopEdge) {
                        y = 0;
                    } else if (root.panelLocation === PlasmaCore.Types.LeftEdge) {
                        x = 0;
                    } else if (root.panelLocation === PlasmaCore.Types.RightEdge) {
                        x = root.width - width;
                    }
                }

                interpolate: false
                running: root.shouldExplode
                source: "assets/smoke_explosion.png"
                frameCount: 24
                frameWidth: 312
                frameHeight: 256
                frameDuration: 30 
                loops: 1
                onFinished: if (ghost.opacity === 0) root.destroy();
            }

            Timer {
                interval: 450
                running: true
                onTriggered: if (!sprite.running) root.destroy();
            }
        }
    }
}
