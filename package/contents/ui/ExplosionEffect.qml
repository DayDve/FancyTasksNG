/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

Item {
    id: root
    
    // Width and height should match the task icon size
    width: 64
    height: 64
    
    // Center the explosion
    property real centerX: 0
    property real centerY: 0
    
    x: centerX - width / 2
    y: centerY - height / 2

    AnimatedSprite {
        id: sprite
        anchors.fill: parent
        interpolate: false
        running: true
        
        source: "assets/smoke_explosion.png"
        frameCount: 24
        frameWidth: 312 // 1877 / 6 columns
        frameHeight: 256 // 1024 / 4 rows
        frameDuration: 30 
        loops: 1
        
        onFinished: {
            root.destroy();
        }
    }
}
