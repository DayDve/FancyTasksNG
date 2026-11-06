/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

// Loads ToolTipStreamList by path, so a missing plasma-pa (its level
// meter) only drops the list instead of breaking the whole tooltip.
Loader {
    id: loader

    property var mediaRegistry: null
    property var streams: []
    // Whether the process's MPRIS player is playing. A browser's player
    // follows only its most recently started media, so with that one paused
    // whatever else is still playing has no other indication.
    property bool playerPlaying: false
    // Without a player the media bar's volume slider already stands for a
    // lone stream; listing it too just doubles the slider and mute button.
    property bool hasPlayer: false

    signal streamActivated()

    readonly property bool anyPlaying: streams.some(stream => stream && !stream.corked)

    // Paused streams stay around (Firefox keeps them corked), so with two
    // or more the list stays up while any of them plays.
    active: mediaRegistry !== null && mediaRegistry.audio !== null && anyPlaying
        && (streams.length > 1 || (hasPlayer && !playerPlaying))
    visible: active && status === Loader.Ready
    source: "ToolTipStreamList.qml"

    Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onStreamActivated(): void {
            loader.streamActivated();
        }
    }

    Binding {
        target: loader.item
        property: "mediaRegistry"
        value: loader.mediaRegistry
    }
    Binding {
        target: loader.item
        property: "streams"
        value: loader.streams
    }
}
