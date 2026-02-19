/*
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
        source: "SettingsWindow/ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Behavior")
        icon: "preferences-desktop"
        source: "SettingsWindow/ConfigBehavior.qml"
    }
    ConfigCategory {
        name: i18n("Indicators")
        icon: "preferences-desktop-navigation"
        source: "SettingsWindow/ConfigIndicators.qml"
    }
    ConfigCategory {
        name: i18n("Pinned Applications")
        icon: "window-pin"
        source: "SettingsWindow/ConfigPinnedApps.qml"
    }
    // qmllint enable unqualified
}
