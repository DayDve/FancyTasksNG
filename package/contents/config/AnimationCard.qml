/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

import "../ui" as FancyUI

// A choice of how a task's icon goes away: a button that shows a key frame
// of that animation, and while hovered or clicked, an icon going away with
// it (the widget's own effects) and coming back.
Button {
    id: card

    // "" for none, or "smoke", "shatter", "burn", "blaze".
    property string effect: ""
    // Unpinning: the icon is first dragged off, then goes away in its place.
    property bool dragOff: false
    // For screen readers; not the button's text, the style would draw it.
    property string title: ""

    // FancyTasksExplosion.spawn() reads the panel's edge from its container.
    readonly property int effectiveLocation: PlasmaCore.Types.BottomEdge

    // The key frames shown while the animation isn't playing: the shader
    // effects' progress, the sprites' frame.
    readonly property real shatterKeyFrame: 0.12
    readonly property real burnKeyFrame: 0.5
    readonly property int smokeKeyFrame: 3
    readonly property int blazeKeyFrame: 9
    // Playing, or about to: the key frame gives way to the icon.
    readonly property bool demoing: card.hovered || dragAnim.running || comeBack.running || fadeIn.running

    // Drawn as a pressed button while picked; AnimationCards keeps
    // `checked` bound to the setting.
    checkable: true
    leftPadding: Kirigami.Units.smallSpacing
    rightPadding: Kirigami.Units.smallSpacing
    topPadding: Kirigami.Units.smallSpacing
    bottomPadding: Kirigami.Units.smallSpacing
    Accessible.role: Accessible.RadioButton
    Accessible.name: card.title

    function play(): void {
        if (demoIcon.opacity < 1 || dragAnim.running)
            return;
        if (card.dragOff)
            dragAnim.start();
        else
            card.goAway();
    }
    function goAway(): void {
        const pos = demoIcon.mapToItem(card, 0, 0);
        const props = {
            x: pos.x, y: pos.y, width: demoIcon.width, height: demoIcon.height,
            iconSource: demoIcon.source, edge: PlasmaCore.Types.BottomEdge
        };
        if (card.effect === "smoke") {
            smoke.spawn(card, demoButton, true);
        } else if (card.effect === "blaze") {
            blazeComponent.createObject(card, props);
        } else if (card.effect !== "") {
            props.room = Kirigami.Units.gridUnit * 2;
            (card.effect === "shatter" ? shatterComponent : burnComponent).createObject(card, props);
        }
        fadeIn.stop();
        demoIcon.opacity = 0;
        comeBack.restart();
    }

    onClicked: card.play()
    onHoveredChanged: {
        if (card.hovered) {
            card.play();
            replay.start();
        } else {
            replay.stop();
        }
    }
    Timer {
        id: replay
        interval: card.dragOff ? 3200 : 2600
        repeat: true
        onTriggered: card.play()
    }
    // The icon is back once the animation is over, for the next go.
    Timer {
        id: comeBack
        interval: 1900
        onTriggered: fadeIn.start()
    }
    NumberAnimation {
        id: fadeIn
        target: demoIcon
        property: "opacity"
        to: 1
        duration: 250
    }

    // The icon dragged up off the panel and let go there.
    SequentialAnimation {
        id: dragAnim
        PropertyAction { target: ghost; property: "visible"; value: true }
        NumberAnimation {
            target: ghost
            property: "lift"
            from: 0
            to: Kirigami.Units.gridUnit * 2
            duration: 500
            easing.type: Easing.InOutQuad
        }
        PauseAnimation { duration: 150 }
        PropertyAction { target: ghost; property: "visible"; value: false }
        ScriptAction { script: card.goAway() }
    }

    FancyUI.FancyTasksExplosion {
        id: smoke
    }
    Component {
        id: shatterComponent
        FancyUI.ShatterEffect {}
    }
    Component {
        id: burnComponent
        FancyUI.BurnEffect {}
    }
    Component {
        id: blazeComponent
        FancyUI.BlazeEffect {}
    }

    Component {
        id: shatterKeyFrame
        FancyUI.ShatterEffect {
            still: true
            progress: card.shatterKeyFrame
            room: card.topPadding
            iconSource: demoIcon.source
        }
    }
    Component {
        id: burnKeyFrame
        FancyUI.BurnEffect {
            still: true
            progress: card.burnKeyFrame
            iconSource: demoIcon.source
        }
    }
    Component {
        id: blazeKeyFrame
        FancyUI.BlazeEffect {
            still: true
            frame: card.blazeKeyFrame
            stillIconOpacity: 0.5
            iconSource: demoIcon.source
        }
    }
    // As in FancyTasksExplosion: the icon fading under the smoke sprite.
    Component {
        id: smokeKeyFrame
        Item {
            Kirigami.Icon {
                anchors.fill: parent
                opacity: 0.4
                source: demoIcon.source
            }
            AnimatedSprite {
                id: smokeSprite
                width: parent.width + 10
                height: parent.height + 10
                x: (parent.width - width) / 2
                y: parent.height - height
                interpolate: false
                running: true
                paused: true
                source: "../ui/assets/smoke_explosion.png"
                frameCount: 24
                frameWidth: 312
                frameHeight: 256
                // Starting the sprite puts it on its first frame: the key
                // frame is set once it has started.
                Component.onCompleted: Qt.callLater(() => smokeSprite.currentFrame = card.smokeKeyFrame)
            }
        }
    }

    // Just the icon, like a task button in the icons-only mode; the name is
    // under the button (AnimationCards).
    contentItem: Item {
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: Kirigami.Units.iconSizes.medium
        Kirigami.Icon {
            id: demoIcon
            anchors.fill: parent
            visible: card.demoing || card.effect === ""
            source: "org.kde.dolphin"
        }
        Loader {
            anchors.fill: parent
            visible: !card.demoing
            sourceComponent: card.effect === "smoke" ? smokeKeyFrame
                : card.effect === "shatter" ? shatterKeyFrame
                : card.effect === "burn" ? burnKeyFrame
                : card.effect === "blaze" ? blazeKeyFrame : null
        }
        // Stands for the task button: the smoke takes its size from it.
        Item {
            id: demoButton
            readonly property var model: ({ decoration: demoIcon.source })
            anchors.fill: parent
        }
    }

    Kirigami.Icon {
        id: ghost
        property real lift: 0
        visible: false
        z: 1
        opacity: 0.7
        width: demoIcon.width
        height: demoIcon.height
        x: card.leftPadding
        y: card.topPadding + (card.availableHeight - height) / 2 - lift
        source: demoIcon.source
    }
}
