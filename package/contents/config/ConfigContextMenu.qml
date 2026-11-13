/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import QtQuick.Layouts

import "../ui/code/singletones"

// Context menu: what a task's menu shows. A tab for the widget's own menu
// may join it later.
ConfigPage {
    id: menuPage
    fullTitle: Wrappers.i18n("Context Menu")

    ConfigTabbedPage {
        cfg_page: menuPage

        ConfigTab {
            title: Wrappers.i18n("Task Menu")
            iconName: "application-menu"

            CheckBox {
                text: Wrappers.i18n("Hide 'Move to Desktop' if only one virtual desktop is used")
                checked: menuPage.cfg_hideMoveToDesktopMenuWithOneDesktop
                onToggled: menuPage.cfg_hideMoveToDesktopMenuWithOneDesktop = checked
            }
            CheckBox {
                id: showBrowserHistory
                text: Wrappers.i18n("Show browsing history in the context menu of web browsers")
                checked: menuPage.cfg_showBrowserHistory
                onToggled: menuPage.cfg_showBrowserHistory = checked
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Item { implicitWidth: Kirigami.Units.gridUnit }
                RowLayout {
                    id: browserHistoryLimit
                    enabled: showBrowserHistory.checked
                    spacing: Kirigami.Units.smallSpacing
                    Label {
                        text: Wrappers.i18n("Number of browser history items:")
                    }
                    SpinBox {
                        from: 1
                        to: 50
                        value: menuPage.cfg_browserHistoryLimit
                        onValueModified: menuPage.cfg_browserHistoryLimit = value
                    }
                }
            }
        }
    }
}
