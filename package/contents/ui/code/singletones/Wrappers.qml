/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma Singleton
import QtQuick

QtObject {
    // qmllint disable unqualified
    // Wrappers for the i18nd functions to avoid linter warnings
    function i18n(text, ...args) {
        return i18nd("plasma_applet_io.github.daydve.fancytasksng", text, ...args);
    }

    function i18nc(context, text, ...args) {
        return i18ndc("plasma_applet_io.github.daydve.fancytasksng", context, text, ...args);
    }

    function i18np(singular, plural, n, ...args) {
        return i18ndp("plasma_applet_io.github.daydve.fancytasksng", singular, plural, n, ...args);
    }

    function i18ncp(context, singular, plural, n, ...args) {
        return i18ndcp("plasma_applet_io.github.daydve.fancytasksng", context, singular, plural, n, ...args);
    }
    // qmllint enable unqualified
}