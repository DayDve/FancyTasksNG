/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.volume as PlasmaPa

import "code/singletones"

// One row per stream of a process: a browser plays all its tabs,
// including background and hidden ones, from one process with one MPRIS
// player, so this is the only way to find the tab that's making noise and
// silence just that one. Only mute and volume per row: pausing is MPRIS,
// and that's one session for the whole process.
ColumnLayout {
    id: listRoot

    // Plain properties, not required: this file is loaded by path (see
    // ToolTipStreamListLoader), so it can fail alone when plasma-pa is missing.
    property var mediaRegistry: null
    property var streams: []

    // A row's name was clicked and its tab or window brought up.
    signal streamActivated()

    readonly property var listedStreams: streams.filter(stream => stream)

    spacing: 0

    Repeater {
        model: listRoot.listedStreams

        delegate: RowLayout {
            id: row

            required property var modelData
            required property int index
            readonly property var stream: modelData

            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.ToolButton {
                implicitWidth: Kirigami.Units.gridUnit * 1.2
                implicitHeight: Kirigami.Units.gridUnit * 1.2
                padding: 0
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                icon.name: row.stream.muted ? "audio-volume-muted" : "audio-volume-high"
                text: Wrappers.i18n("Mute")
                display: PlasmaComponents3.AbstractButton.IconOnly
                checkable: true
                checked: row.stream.muted
                onClicked: listRoot.mediaRegistry.setMuted([row.stream], !row.stream.muted)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                PlasmaComponents3.Label {
                    id: nameLabel
                    readonly property bool clickable: listRoot.mediaRegistry !== null && listRoot.mediaRegistry.canActivateStream(row.stream)
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: listRoot.displayName(row.stream)
                    font.underline: clickable && nameMouse.containsMouse
                    elide: Text.ElideRight
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    // Dimmed when muted or paused.
                    opacity: row.stream.muted || row.stream.corked ? 0.5 : 0.85
                    textFormat: Text.PlainText

                    // Pausing a tab other than the one the browser's MPRIS
                    // player follows is only possible in the tab itself.
                    MouseArea {
                        id: nameMouse
                        anchors.fill: parent
                        enabled: nameLabel.clickable
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            listRoot.mediaRegistry.activateStream(row.stream);
                            listRoot.streamActivated();
                        }
                    }

                    PlasmaComponents3.ToolTip.text: Wrappers.i18n("Show where this is playing")
                    PlasmaComponents3.ToolTip.visible: nameLabel.clickable && nameMouse.containsMouse
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                // Level meter: with nameless streams the one that's moving
                // is the one you hear.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 2
                    radius: 1
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * Math.min(1, meter.volume)
                        color: Kirigami.Theme.highlightColor
                        opacity: row.stream.muted ? 0.4 : 1
                        Behavior on width {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    PlasmaPa.VolumeMonitor {
                        id: meter
                        target: listRoot.visible ? row.stream.pulseObject : null
                    }
                }
            }

            PlasmaComponents3.Slider {
                id: slider
                Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                from: listRoot.mediaRegistry ? listRoot.mediaRegistry.minimalVolume : 0
                to: listRoot.mediaRegistry ? listRoot.mediaRegistry.normalVolume : 65536
                stepSize: (to - from) / 100
                onMoved: listRoot.mediaRegistry.setVolume([row.stream], value)

                // Moving the slider replaces a plain value binding; this one
                // keeps following the stream whenever the slider isn't held.
                Binding on value {
                    when: !slider.pressed
                    value: row.stream.volume
                    restoreMode: Binding.RestoreNone
                }
            }
        }
    }

    // Chromium-family browsers name every tab's stream "Playback"; number
    // repeated names so the rows can at least be told apart.
    function displayName(stream): string {
        const name = stream.mediaName || stream.appName || Wrappers.i18n("Audio stream");
        const same = listedStreams.filter(other => (other.mediaName || other.appName || Wrappers.i18n("Audio stream")) === name);
        if (same.length < 2) {
            return name;
        }
        return Wrappers.i18nc("Stream name and its number among streams with the same name", "%1 %2", name, same.indexOf(stream) + 1);
    }
}
