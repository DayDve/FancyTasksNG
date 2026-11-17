/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A check box whose label has keys drawn as keyboard keys: `key` before the
// text, or `keys` in place of the %1, %2… placeholders in it. A CheckBox's
// own contentItem can't be used: the style leaves no room for the indicator
// when the box has no text.
RowLayout {
    id: keyCheckBox

    property string key
    property var keys: [key]
    property string text
    property alias checked: box.checked
    signal toggled()

    // [{key: bool, text}], in the order shown.
    readonly property var parts: {
        if (!/%\d/.test(text))
            return [{ key: true, text: key }].concat(text !== "" ? [{ key: false, text: " " + text }] : []);
        const result = [];
        const re = /%(\d)/g;
        let last = 0, m;
        while ((m = re.exec(text)) !== null) {
            if (m.index > last)
                result.push({ key: false, text: text.slice(last, m.index) });
            result.push({ key: true, text: keys[Number(m[1]) - 1] ?? "" });
            last = re.lastIndex;
        }
        if (last < text.length)
            result.push({ key: false, text: text.slice(last) });
        return result;
    }

    spacing: Kirigami.Units.smallSpacing

    CheckBox {
        id: box
        Accessible.name: keyCheckBox.parts.map(part => part.text).join("")
        onToggled: keyCheckBox.toggled()
    }
    RowLayout {
        spacing: 1
        Repeater {
            model: keyCheckBox.parts
            delegate: Loader {
                id: part
                required property var modelData
                sourceComponent: modelData.key ? keyCapPart : textPart
                Component {
                    id: keyCapPart
                    KeyCap { text: part.modelData.text }
                }
                Component {
                    id: textPart
                    Label { text: part.modelData.text }
                }
            }
        }
    }

    // Clicking the key or the label toggles the box, as with a plain
    // CheckBox's text. A tap on the box itself reaches this handler too
    // (it only holds a passive grab); the box has toggled already.
    TapHandler {
        onTapped: (eventPoint) => {
            if (box.contains(box.mapFromItem(keyCheckBox, eventPoint.position)))
                return;
            box.toggle();
            box.toggled();
        }
    }
}
