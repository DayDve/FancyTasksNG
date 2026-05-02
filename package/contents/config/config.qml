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
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "../config/ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Behavior")
        icon: "preferences-desktop"
        source: "../config/ConfigBehavior.qml"
    }
    ConfigCategory {
        name: i18n("Indicators")
        icon: "preferences-desktop-navigation"
        source: "../config/ConfigIndicators.qml"
    }
    ConfigCategory {
        name: i18n("Advanced")
        icon: "preferences-other"
        source: "../config/ConfigAdvanced.qml"
    }
    ConfigCategory {
        name: i18n("Pinned Applications")
        icon: "window-pin"
        source: "../config/ConfigPinnedApps.qml"
    }
}
