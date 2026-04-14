/*
    SPDX-FileCopyrightText: 2024 Vitaliy Elin <daydve@smbit.pro>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library

/**
 * Calculates the effective location of the plasmoid, taking into account
 * the user's direction override if the plasmoid is in floating mode.
 *
 * @param {number} realLocation - The actual Plasmoid.location (from PlasmaCore.Types).
 * @param {object} config - The Plasmoid.configuration object.
 * @param {object} plasmaCoreTypes - The PlasmaCore.Types object containing edge constants.
 * @returns {number} The effective location constant.
 */
function getEffectiveLocation(realLocation, config, plasmaCoreTypes) {
    // SECURITY GUARD: If the widget is on a panel, we return the real location immediately.
    // This ensures that we NEVER interfere with the standard panel behavior.
    if (realLocation !== plasmaCoreTypes.Floating) {
        return realLocation;
    }

    // If the override is disabled, even in floating mode, return the system location.
    if (!config.overridePlasmaButtonDirection) {
        return realLocation;
    }

    // Map the custom direction index (0-3) to PlasmaCore edge constants.
    // Config Indices: 0: North, 1: South, 2: West, 3: East
    switch (config.plasmaButtonDirection) {
        case 0: return plasmaCoreTypes.TopEdge;
        case 1: return plasmaCoreTypes.BottomEdge;
        case 2: return plasmaCoreTypes.LeftEdge;
        case 3: return plasmaCoreTypes.RightEdge;
        default: return realLocation;
    }
}
