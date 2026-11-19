/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A row of AnimationCard, each with its name under it: one choice of a
// list of animations.
RowLayout {
    id: cards

    // [{ text, effect }], in the order of the setting's values.
    property var choices: []
    property int currentIndex: 0
    // Unpinning: each icon is first dragged off.
    property bool dragOff: false
    signal activated(int index)

    spacing: Kirigami.Units.largeSpacing

    Repeater {
        model: cards.choices
        ColumnLayout {
            id: choice
            required property var modelData
            required property int index
            spacing: Kirigami.Units.smallSpacing
            AnimationCard {
                Layout.alignment: Qt.AlignHCenter
                title: choice.modelData.text
                effect: choice.modelData.effect
                dragOff: cards.dragOff
                checked: cards.currentIndex === choice.index
                // A click toggles `checked` and breaks its binding: picked
                // stays picked, and the binding is put back.
                onClicked: {
                    cards.activated(choice.index);
                    checked = Qt.binding(() => cards.currentIndex === choice.index);
                }
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: choice.modelData.text
            }
        }
    }
}
