/*
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2020 Tranter Madi <trmdi@yandex.com>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

MouseArea {
    id: root

    required property Text textItem

    onTextItemChanged: {
        textItem.parent = this;
        textItem.width = Qt.binding(() => width);
    }

    clip: textItem.elide === Text.ElideNone
    hoverEnabled: true

    onContainsMouseChanged: {
        if (!containsMouse) {
            state = "";
        }
    }

    Timer {
        id: timer
        interval: 500
        running: root.containsMouse
        onTriggered: {
            if (root.width < root.textItem.implicitWidth) {
                root.state = "ShowRight";
            }
        }
    }

    onStateChanged: {
        if (state === "ShowRight") {
            scrollAnimation.restart();
        } else {
            scrollAnimation.stop();
            if (textItem) {
                textItem.x = 0;
            }
        }
    }

    NumberAnimation {
        id: scrollAnimation
        target: root.textItem
        property: "x"
        to: root.width - (root.textItem ? root.textItem.implicitWidth : 0)
        duration: Math.abs((root.textItem ? root.textItem.implicitWidth : 0) - root.width) * 25
        easing.type: Easing.Linear
    }
}
