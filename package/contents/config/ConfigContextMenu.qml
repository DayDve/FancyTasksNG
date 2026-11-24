/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import QtQuick.Layouts

import "../ui" as FancyUI
import "../ui/code/singletones"

// Context menu: what a task's menu and the widget's own menu show.
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

            Item { height: Kirigami.Units.largeSpacing }
            RowLayout {
                CheckBox {
                    id: shiftItems
                    text: Wrappers.i18n("Extra items with Shift")
                    checked: menuPage.cfg_menuShiftItems
                    onToggled: menuPage.cfg_menuShiftItems = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Items for a task's menu, and a window's menu in its tooltip, opened with Shift held.")
                }
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    id: shiftForceQuit
                    enabled: shiftItems.checked
                    text: Wrappers.i18n("Force Quit")
                    checked: menuPage.cfg_menuShiftForceQuit
                    onToggled: menuPage.cfg_menuShiftForceQuit = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Kills the app's process, for an app that no longer responds to Close.")
                }
            }
            // How its icon goes away: only with Force Quit on, greyed out with
            // it; played in the icons-only mode.
            RowLayout {
                visible: shiftForceQuit.checked && menuPage.cfg_iconOnly === 1
                enabled: shiftItems.checked
                Item { implicitWidth: Kirigami.Units.gridUnit * 2 }
                Label {
                    text: Wrappers.i18n("Animation:")
                }
                AnimationCards {
                    choices: [
                        { text: Wrappers.i18nc("No animation", "None"), effect: "" },
                        { text: Wrappers.i18nc("Animation", "Burn"), effect: "burn" },
                        { text: Wrappers.i18nc("Animation", "Blaze"), effect: "blaze" }
                    ]
                    currentIndex: menuPage.cfg_forceQuitAnimation
                    onActivated: (index) => menuPage.cfg_forceQuitAnimation = index
                }
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    enabled: shiftItems.checked
                    text: Wrappers.i18n("Restart")
                    checked: menuPage.cfg_menuShiftRestart
                    onToggled: menuPage.cfg_menuShiftRestart = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Closes the app and starts it again once it has quit.")
                }
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    enabled: shiftItems.checked
                    text: Wrappers.i18nc("Context menu item to show", "Copy")
                    checked: menuPage.cfg_menuShiftCopy
                    onToggled: menuPage.cfg_menuShiftCopy = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("The PID, app ID or .desktop file path, for a bug report.")
                }
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    enabled: shiftItems.checked
                    text: Wrappers.i18n("Edit Application…")
                    checked: menuPage.cfg_menuShiftEditApp
                    onToggled: menuPage.cfg_menuShiftEditApp = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("A pinned app that isn't running: opens it in the Menu Editor.")
                }
            }
        }

        ConfigTab {
            title: Wrappers.i18n("Widget Menu")
            iconName: "configure"

            RowLayout {
                Label {
                    text: Wrappers.i18n("Show in the widget's menu:")
                }
                ConfigHint {
                    info: Wrappers.i18n("The menu on a right-click off the task buttons.")
                }
            }
            RowLayout {
                Item { implicitWidth: Kirigami.Units.gridUnit }
                CheckBox {
                    enabled: systemMonitor.installed
                    text: Wrappers.i18n("System Monitor")
                    checked: menuPage.cfg_systemMonitorMenuItem
                    onToggled: menuPage.cfg_systemMonitorMenuItem = checked
                }
                ConfigHint {
                    visible: !systemMonitor.installed
                    info: Wrappers.i18n("System Monitor isn't installed.")
                }
                FancyUI.InstalledApp {
                    id: systemMonitor
                    desktopId: "org.kde.plasma-systemmonitor.desktop"
                }
            }
        }
    }
}
