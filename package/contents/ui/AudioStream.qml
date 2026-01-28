/*
    SPDX-FileCopyrightText: 2017 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

import "code/singletones"

Item {
    id: audioStreamIconBox

    required property Item iconBox
    required property var task
    required property Item frame

    width: Math.min(Math.min(audioStreamIconBox.iconBox.width, audioStreamIconBox.iconBox.height) * 0.4, Kirigami.Units.iconSizes.smallMedium)
    height: width
    anchors {
        top: audioStreamIconBox.frame.top
        right: audioStreamIconBox.frame.right
        rightMargin: audioStreamIconBox.task.tasksRoot.taskFrame.margins.right
        topMargin: Math.round(audioStreamIconBox.task.tasksRoot.taskFrame.margins.top * indicatorScale)
    }

    readonly property real indicatorScale: 1.2

    activeFocusOnTab: true

    // Using States rather than a simple Behavior we can apply different transitions,
    // which allows us to delay showing the icon but hide it instantly still.
    states: [
        State {
            name: "playing"
            when: audioStreamIconBox.task.playingAudio && !audioStreamIconBox.task.muted
            PropertyChanges {
                target: audioStreamIconBox
                opacity: 1
            }
            PropertyChanges {
                target: audioStreamIcon
                source: "audio-volume-high-symbolic"
            }
        },
        State {
            name: "muted"
            when: audioStreamIconBox.task.muted
            PropertyChanges {
                target: audioStreamIconBox
                opacity: 1
            }
            PropertyChanges {
                target: audioStreamIcon
                source: "audio-volume-muted-symbolic"
            }
        }
    ]

    transitions: [
        Transition {
             from: ""
             to: "playing"
             SequentialAnimation {
                 // Delay showing the play indicator so we don't flash it for brief sounds.
                 PauseAnimation {
                     duration: !audioStreamIconBox.task.delayAudioStreamIndicator || audioStreamIconBox.task.inPopup ? 0 : 2000
                 }
                 NumberAnimation {
                     property: "opacity"
                     duration: Kirigami.Units.longDuration
                 }
             }
        },
        Transition {
             from: ""
             to: "muted"
             SequentialAnimation {
                 NumberAnimation {
                     property: "opacity"
                     duration: Kirigami.Units.longDuration
                 }
             }
        },
        Transition {
             to: ""
             NumberAnimation {
                 property: "opacity"
                 duration: Kirigami.Units.longDuration
             }
        }
    ]

    opacity: 0
    visible: opacity > 0

    Keys.onReturnPressed: event => audioStreamIconBox.task.toggleMuted()
    Keys.onEnterPressed: event => Keys.returnPressed(event);
    Keys.onSpacePressed: event => Keys.returnPressed(event);

    Accessible.checkable: true
    Accessible.checked: audioStreamIconBox.task.muted
    Accessible.name: audioStreamIconBox.task.muted ? Wrappers.i18nc("@action:button", "Unmute") : Wrappers.i18nc("@action:button", "Mute")
    Accessible.description: audioStreamIconBox.task.muted ? Wrappers.i18nc("@info:tooltip %1 is the window title", "Unmute %1", audioStreamIconBox.task.model.display) : Wrappers.i18nc("@info:tooltip %1 is the window title", "Mute %1", audioStreamIconBox.task.model.display)
    Accessible.role: Accessible.Button

    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        id: tapHandler
        gesturePolicy: TapHandler.ReleaseWithinBounds // Exclusive grab
        onTapped: (eventPoint, button) => audioStreamIconBox.task.toggleMuted()
    }

    PlasmaExtras.Highlight {
        anchors.fill: audioStreamIcon
        hovered: hoverHandler.hovered || parent.activeFocus
        pressed: tapHandler.pressed
    }

    Kirigami.Icon {
        id: audioStreamIcon

        // Need audio indicator twice, to keep iconBox in the center.
        readonly property real requiredSpace: Math.min(audioStreamIconBox.iconBox.width, audioStreamIconBox.iconBox.height)
            + Math.min(Math.min(audioStreamIconBox.iconBox.width, audioStreamIconBox.iconBox.height), Kirigami.Units.iconSizes.smallMedium) * 2

        source: "audio-volume-high-symbolic"
        selected: tapHandler.pressed

        height: Math.round(Math.min(parent.height * audioStreamIconBox.indicatorScale, Kirigami.Units.iconSizes.smallMedium))
        width: height

        anchors {
            verticalCenter: parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
        }

        states: [
            State {
                name: "verticalIconsOnly"
                when: audioStreamIconBox.task.tasksRoot.vertical && audioStreamIconBox.frame.width < audioStreamIcon.requiredSpace

                PropertyChanges {
                    target: audioStreamIconBox
                    anchors.rightMargin: Math.round(audioStreamIconBox.task.tasksRoot.taskFrame.margins.right * indicatorScale)
                }
            },

            State {
                name: "horizontal"
                when: audioStreamIconBox.frame.width > audioStreamIcon.requiredSpace

                AnchorChanges {
                    target: audioStreamIconBox

                    anchors.top: undefined
                    anchors.verticalCenter: audioStreamIconBox.frame.verticalCenter
                }

                PropertyChanges {
                    target: audioStreamIconBox
                    width: Kirigami.Units.iconSizes.roundedIconSize(Math.min(Math.min(audioStreamIconBox.iconBox.width, audioStreamIconBox.iconBox.height), Kirigami.Units.iconSizes.smallMedium))
                }

                PropertyChanges {
                    target: audioStreamIcon

                    height: parent.height
                    width: parent.width
                }
            },

            State {
                name: "vertical"
                when: audioStreamIconBox.frame.height > audioStreamIcon.requiredSpace

                AnchorChanges {
                    target: audioStreamIconBox

                    anchors.right: undefined
                    anchors.horizontalCenter: audioStreamIconBox.frame.horizontalCenter
                }

                PropertyChanges {
                    target: audioStreamIconBox

                    anchors.topMargin: audioStreamIconBox.task.tasksRoot.taskFrame.margins.top
                    width: Kirigami.Units.iconSizes.roundedIconSize(Math.min(Math.min(audioStreamIconBox.iconBox.width, audioStreamIconBox.iconBox.height), Kirigami.Units.iconSizes.smallMedium))
                }

                PropertyChanges {
                    target: audioStreamIcon

                    height: parent.height
                    width: parent.width
                }
            }
        ]
    }
}
