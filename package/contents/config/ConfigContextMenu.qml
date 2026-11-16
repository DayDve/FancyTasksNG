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

            Label {
                text: Wrappers.i18n("Show in a task's menu:")
            }
            RowLayout {
                CheckBox {
                    text: Wrappers.i18n("App actions")
                    checked: menuPage.cfg_menuAppActions
                    onToggled: menuPage.cfg_menuAppActions = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Actions the app itself offers, such as New Private Window or Compose Message.")
                }
            }
            RowLayout {
                CheckBox {
                    text: Wrappers.i18n("Places")
                    checked: menuPage.cfg_menuPlaces
                    onToggled: menuPage.cfg_menuPlaces = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("In the menu of file managers.")
                }
            }
            RowLayout {
                CheckBox {
                    text: Wrappers.i18n("Recent files and folders")
                    checked: menuPage.cfg_menuRecentFiles
                    onToggled: menuPage.cfg_menuRecentFiles = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Files and folders recently opened with the app.")
                }
            }
            RowLayout {
                CheckBox {
                    id: showBrowserHistory
                    text: Wrappers.i18n("Browsing history")
                    checked: menuPage.cfg_showBrowserHistory
                    onToggled: menuPage.cfg_showBrowserHistory = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("In the menu of web browsers.")
                }
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
            RowLayout {
                CheckBox {
                    text: Wrappers.i18n("Media controls")
                    checked: menuPage.cfg_menuMediaControls
                    onToggled: menuPage.cfg_menuMediaControls = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Previous, play/pause, next and stop, for media players.")
                }
            }
            RowLayout {
                CheckBox {
                    text: Wrappers.i18nc("Context menu item to show", "Mute")
                    checked: menuPage.cfg_menuMute
                    onToggled: menuPage.cfg_menuMute = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("For apps that play audio.")
                }
            }

            Item { height: Kirigami.Units.largeSpacing }

            CheckBox {
                text: Wrappers.i18n("Hide 'Move to Desktop' if only one virtual desktop is used")
                checked: menuPage.cfg_hideMoveToDesktopMenuWithOneDesktop
                onToggled: menuPage.cfg_hideMoveToDesktopMenuWithOneDesktop = checked
            }
        }
    }
}
