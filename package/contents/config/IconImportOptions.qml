/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../ui/code/singletones"

// How imported icon replacements come in: the icon theme's icons by name
// or from the archive's files, added to the current replacements or in
// place of them. Used by the Icon Replacements tab and the settings import.
ColumnLayout {
    id: options

    // DesktopActionsManager.importIcons()' mode: 0 by name with the same
    // theme, else the file; 1 by name; 2 always the file.
    property int themeMode: 0
    // Off: the imported replacements take the place of the current ones.
    property bool addToCurrent: true

    spacing: Kirigami.Units.smallSpacing

    // Two choices: without groups, all the radio buttons here would be one.
    ButtonGroup { id: themeGroup }
    ButtonGroup { id: mergeGroup }

    Label {
        text: Wrappers.i18n("Icons from the icon theme:")
    }
    RadioButton {
        text: Wrappers.i18n("By name if the icon theme is the same, else from the file")
        ButtonGroup.group: themeGroup
        checked: options.themeMode === 0
        onToggled: if (checked) options.themeMode = 0
    }
    RadioButton {
        text: Wrappers.i18n("By name, following the current icon theme")
        ButtonGroup.group: themeGroup
        checked: options.themeMode === 1
        onToggled: if (checked) options.themeMode = 1
    }
    RadioButton {
        text: Wrappers.i18n("From the file, as when exported")
        ButtonGroup.group: themeGroup
        checked: options.themeMode === 2
        onToggled: if (checked) options.themeMode = 2
    }

    Item { implicitHeight: Kirigami.Units.smallSpacing }

    RadioButton {
        text: Wrappers.i18n("Add to the current replacements")
        ButtonGroup.group: mergeGroup
        checked: options.addToCurrent
        onToggled: if (checked) options.addToCurrent = true
    }
    RadioButton {
        text: Wrappers.i18n("Replace the current replacements")
        ButtonGroup.group: mergeGroup
        checked: !options.addToCurrent
        onToggled: if (checked) options.addToCurrent = false
    }
}
