/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A check box whose label starts with a key drawn as a keyboard key. A
// CheckBox's own contentItem can't be used: the style leaves no room for
// the indicator when the box has no text.
RowLayout {
    id: keyCheckBox

    property string key
    property string text
    property alias checked: box.checked
    signal toggled()

    spacing: Kirigami.Units.smallSpacing

    CheckBox {
        id: box
        Accessible.name: keyCheckBox.key + " " + keyCheckBox.text
        onToggled: keyCheckBox.toggled()
    }
    KeyCap {
        text: keyCheckBox.key
    }
    Label {
        visible: keyCheckBox.text !== ""
        text: keyCheckBox.text
    }

    // Clicking the key or the label toggles the box, as with a plain
    // CheckBox's text.
    TapHandler {
        onTapped: {
            box.toggle();
            box.toggled();
        }
    }
}
