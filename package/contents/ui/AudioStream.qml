import QtQuick
import org.kde.kirigami as Kirigami


Item {
    id: audioStreamIconBox

    property Item iconBox
    property var task
    property Item frame

    z: 5000 // Topmost

    // Clamping coordinates to keep the indicator within the task item bounds
    x: (task && iconBox && task.taskIcon) ? Math.max(0, Math.min(task.width - visualSize, iconBox.x + task.taskIcon.x)) : 0
    y: (task && iconBox && task.taskIcon) ? Math.max(0, Math.min(task.height - visualSize, iconBox.y + task.taskIcon.y)) : 0

    width: visualSize
    height: visualSize

    readonly property int visualSize: (task && iconBox && task.taskIcon) ? Math.round(Math.min(Math.min(iconBox.width, iconBox.height) * 0.4, Kirigami.Units.iconSizes.smallMedium)
            * (task.taskIcon.baseWidth > 0 ? (task.taskIcon.width / task.taskIcon.baseWidth) : 1)) : 0
    
    property bool hovered: false

    // Using the project's own Badge component
    Badge {
        id: badge
        anchors.fill: parent
        iconSource: (audioStreamIconBox.task && audioStreamIconBox.task.muted) ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
        hovered: audioStreamIconBox.hovered
        
        // Change color to red if muted for better visibility on small sizes
        highlightColor: (audioStreamIconBox.task && audioStreamIconBox.task.muted) ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor

        Behavior on highlightColor { ColorAnimation { duration: Kirigami.Units.longDuration } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onContainsMouseChanged: {
            audioStreamIconBox.hovered = containsMouse;
            if (audioStreamIconBox.task) {
                audioStreamIconBox.task.isAudioHovered = containsMouse;
            }
        }
        onClicked: (mouse) => {
            mouse.accepted = true;
            if (audioStreamIconBox.task) audioStreamIconBox.task.toggleMuted();
        }
    }

    opacity: 0
    visible: opacity > 0

    states: [
        State {
            name: "visible"
            when: audioStreamIconBox.task && (audioStreamIconBox.task.playingAudio || audioStreamIconBox.task.muted)
            PropertyChanges { target: audioStreamIconBox; opacity: 1 }
        }
    ]

    transitions: [
        Transition {
             from: ""
             to: "visible"
             SequentialAnimation {
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
             to: ""
             NumberAnimation {
                 property: "opacity"
                 duration: Kirigami.Units.longDuration
             }
        }
    ]
}
