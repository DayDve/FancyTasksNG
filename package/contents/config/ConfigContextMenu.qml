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
        // Nothing here changes the task buttons.
        showPreview: false

        ConfigTab {
            title: Wrappers.i18n("Task Menu")
            iconName: "application-menu"

            Label {
                text: Wrappers.i18n("Show in a task's menu:")
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    text: Wrappers.i18n("App actions")
                    checked: menuPage.cfg_menuAppActions
                    onToggled: menuPage.cfg_menuAppActions = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Actions listed in the app's .desktop file, such as New Private Window in a browser or Compose Message in a mail client.")
                }
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    text: Wrappers.i18n("Places")
                    checked: menuPage.cfg_menuPlaces
                    onToggled: menuPage.cfg_menuPlaces = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("A Places submenu with the places from Dolphin's Places panel: Home, Downloads, Trash, added folders. Only in Dolphin's menu.")
                }
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    text: Wrappers.i18n("Recent files and folders")
                    checked: menuPage.cfg_menuRecentFiles
                    onToggled: menuPage.cfg_menuRecentFiles = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Recent Documents and Recent Folders: what was opened with the app in the current activity, as Plasma records it. Forget Recent Files clears the list.")
                }
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    id: showBrowserHistory
                    text: Wrappers.i18n("Browsing history")
                    checked: menuPage.cfg_showBrowserHistory
                    onToggled: menuPage.cfg_showBrowserHistory = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Recent Pages: the latest pages from the browser's history, with their icons. Firefox, Chrome, Chromium, Brave, Vivaldi, Edge and Opera, including Flatpak and Snap versions.")
                }
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Item { implicitWidth: Kirigami.Units.gridUnit * 2 }
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
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    text: Wrappers.i18n("Media controls")
                    checked: menuPage.cfg_menuMediaControls
                    onToggled: menuPage.cfg_menuMediaControls = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Previous Track, Play/Pause, Next Track and Stop, for media players (MPRIS). Quit and Restore of such players stay in the menu.")
                }
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    text: Wrappers.i18nc("Context menu item to show", "Mute")
                    checked: menuPage.cfg_menuMute
                    onToggled: menuPage.cfg_menuMute = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Mute/Unmute all the app's sound. For apps with an audio stream open, even a silent one.")
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
