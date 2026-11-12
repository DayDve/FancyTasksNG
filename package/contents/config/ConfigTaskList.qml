/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../ui/code/singletones"

// Task list: which tasks are shown, how they're grouped and in what order,
// in the order TasksModel applies them.
ConfigPage {
    id: listPage
    fullTitle: Wrappers.i18n("Task List")

    ConfigTabbedPage {
        cfg_page: listPage

        ConfigTab {
            title: Wrappers.i18n("Filters")
            iconName: "view-filter"

            Label {
                text: Wrappers.i18n("Show only tasks:")
            }
            CheckBox {
                id: showOnlyCurrentScreen
                text: Wrappers.i18n("From current screen")
                checked: listPage.cfg_showOnlyCurrentScreen
                onToggled: listPage.cfg_showOnlyCurrentScreen = checked
            }
            CheckBox {
                id: showOnlyCurrentDesktop
                text: Wrappers.i18n("From current desktop")
                checked: listPage.cfg_showOnlyCurrentDesktop
                onToggled: listPage.cfg_showOnlyCurrentDesktop = checked
            }
            CheckBox {
                id: showOnlyCurrentActivity
                text: Wrappers.i18n("From current activity")
                checked: listPage.cfg_showOnlyCurrentActivity
                onToggled: listPage.cfg_showOnlyCurrentActivity = checked
            }
            RowLayout {
                CheckBox {
                    id: reverseFilters
                    enabled: showOnlyCurrentScreen.checked || showOnlyCurrentDesktop.checked || showOnlyCurrentActivity.checked
                    text: Wrappers.i18n("Invert selected filters")
                    checked: listPage.cfg_reverseFilters
                    onToggled: listPage.cfg_reverseFilters = checked
                }
                ConfigHint {
                    target: reverseFilters
                    info: Wrappers.i18n("Hide matching tasks instead of showing them.")
                    reason: Wrappers.i18n("Turn on one of the filters above first.")
                }
            }

            Item { height: listPage.largeSpacing }

            ButtonGroup {
                id: minimizedFilterGroup
            }
            RadioButton {
                text: Wrappers.i18n("In any state")
                checked: listPage.cfg_minimizedFilter === 0
                ButtonGroup.group: minimizedFilterGroup
                onToggled: if (checked) listPage.cfg_minimizedFilter = 0
            }
            RadioButton {
                text: Wrappers.i18n("Only minimized")
                checked: listPage.cfg_minimizedFilter === 1
                ButtonGroup.group: minimizedFilterGroup
                onToggled: if (checked) listPage.cfg_minimizedFilter = 1
            }
            RadioButton {
                text: Wrappers.i18n("Only not minimized")
                checked: listPage.cfg_minimizedFilter === 2
                ButtonGroup.group: minimizedFilterGroup
                onToggled: if (checked) listPage.cfg_minimizedFilter = 2
            }
        }

        ConfigTab {
            title: Wrappers.i18n("Grouping")
            iconName: "object-group"

            Label {
                text: Wrappers.i18n("Grouping of tasks:")
            }
            RadioButton {
                text: Wrappers.i18nc("State", "Disabled")
                checked: listPage.cfg_groupingStrategy === 0
                onToggled: if (checked) listPage.cfg_groupingStrategy = 0
            }
            RadioButton {
                text: Wrappers.i18n("Place windows of one application side-by-side")
                checked: listPage.cfg_groupingStrategy === 1 && !listPage.cfg_groupPopups
                onToggled: {
                    if (checked) {
                        listPage.cfg_groupingStrategy = 1;
                        listPage.cfg_groupPopups = false;
                    }
                }
            }
            RadioButton {
                text: Wrappers.i18n("Combine into one button by application name")
                checked: listPage.cfg_groupingStrategy === 1 && listPage.cfg_groupPopups
                onToggled: {
                    if (checked) {
                        listPage.cfg_groupingStrategy = 1;
                        listPage.cfg_groupPopups = true;
                    }
                }
            }
        }

        ConfigTab {
            title: Wrappers.i18n("Sorting")
            iconName: "view-sort"

            Label {
                text: Wrappers.i18n("Sort tasks:")
            }
            // Shown like Plasma's own Task Manager: "Do not sort" (0) and
            // "Manually" (1) are both manual ordering, told apart by "Keep
            // launchers separate", so the combo starts at 1 and the checkbox
            // picks between 0 and 1.
            ComboBox {
                Layout.fillWidth: true
                Layout.minimumWidth: listPage.gridUnit * 14
                model: [Wrappers.i18n("Manually"), Wrappers.i18n("Alphabetically"), Wrappers.i18n("By desktop"), Wrappers.i18n("By activity"), Wrappers.i18n("By horizontal window position")]
                currentIndex: Math.max(0, listPage.cfg_sortingStrategy - 1)
                onActivated: (index) => listPage.cfg_sortingStrategy = index === 0 ? (keepLaunchersSeparate.checked ? 0 : 1) : index + 1
            }

            RowLayout {
                CheckBox {
                    id: keepLaunchersSeparate
                    enabled: listPage.cfg_sortingStrategy <= 1
                    text: Wrappers.i18n("Keep launchers separate")
                    checked: listPage.cfg_sortingStrategy === 0
                    onToggled: listPage.cfg_sortingStrategy = checked ? 0 : 1
                }
                ConfigHint {
                    target: keepLaunchersSeparate
                    reason: Wrappers.i18n("Only for manual sorting.")
                }
            }
            Label {
                enabled: keepLaunchersSeparate.enabled
                Layout.fillWidth: true
                // A wrapping label still reports its unwrapped text width as
                // implicit width, which would stretch the whole form column.
                Layout.preferredWidth: listPage.gridUnit * 14
                wrapMode: Text.WordWrap
                font: listPage.themeSmallFont
                opacity: 0.7
                text: keepLaunchersSeparate.checked
                    ? Wrappers.i18n("Pinned apps always come first and stay in place when launched. Pinned apps can be dragged among themselves, other tasks among themselves.")
                    : Wrappers.i18n("Drag any task anywhere. A newly opened window of a pinned app goes to the end of the list.")
            }
        }
    }
}
