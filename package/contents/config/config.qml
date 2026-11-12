/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.configuration

ConfigModel {
    // qmllint disable unqualified
    ConfigCategory {
        name: i18nc("Short section name in the settings sidebar", "Quick Setup")
        icon: "speedometer"
        source: "../config/ConfigQuickSetup.qml"
    }
    ConfigCategory {
        name: i18nc("Short section name in the settings sidebar", "Task Layout")
        icon: "distribute-horizontal-x"
        source: "../config/ConfigLayout.qml"
    }
    ConfigCategory {
        name: i18nc("Short section name in the settings sidebar", "Task Styling")
        icon: "preferences-desktop-color"
        source: "../config/ConfigTaskStyle.qml"
    }
    ConfigCategory {
        name: i18nc("Short section name in the settings sidebar", "Window Indicators")
        icon: "preferences-desktop-navigation"
        source: "../config/ConfigWindowIndicators.qml"
    }
    ConfigCategory {
        name: i18nc("Short section name in the settings sidebar", "App Signals")
        icon: "preferences-desktop-notification-bell"
        source: "../config/ConfigAppSignals.qml"
    }
    ConfigCategory {
        name: i18nc("Short section name in the settings sidebar", "Task List")
        icon: "view-list-details"
        source: "../config/ConfigTaskList.qml"
    }
    ConfigCategory {
        name: i18nc("Short section name in the settings sidebar", "Task Actions")
        icon: "input-mouse"
        source: "../config/ConfigTaskActions.qml"
    }
    ConfigCategory {
        name: i18nc("Short section name in the settings sidebar", "Task Tooltips")
        icon: "help-hint"
        source: "../config/ConfigTooltips.qml"
    }
    ConfigCategory {
        name: i18nc("Short section name in the settings sidebar", "Context Menu")
        icon: "application-menu"
        source: "../config/ConfigContextMenu.qml"
    }
    ConfigCategory {
        name: i18n("Advanced")
        icon: "preferences-other"
        source: "../config/ConfigAdvanced.qml"
    }
    ConfigCategory {
        name: i18nc("Short section name in the settings sidebar", "Pinned Applications")
        icon: "window-pin"
        source: "../config/ConfigPinnedApps.qml"
    }
}
