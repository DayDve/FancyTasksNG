import QtQuick
import QtQuick.Effects
import org.kde.ksvg as KSvg
import org.kde.plasma.plasmoid
import "code/tools.js" as TaskTools

Item {
    id: control
    anchors.fill: parent

    property var task

    readonly property int pStyle: Plasmoid.configuration.indicatorProgressStyle
    readonly property color pColor: Plasmoid.configuration.indicatorProgressColor
    readonly property real pOpacity: Plasmoid.configuration.indicatorProgressOpacity / 100.0
    readonly property int pThick: Plasmoid.configuration.indicatorProgressThickness
    readonly property real pPosition: (task?.smartLauncherItem?.progress ?? 0) / 100.0

    Item {
        id: contentItem
        anchors.fill: parent
        opacity: control.pOpacity

        // Styles 1 & 2: Shape/Background Fill (SVG based)
        // Consolidated into a single clipping container and SVG item
        Item {
            id: fillClip
            visible: control.pStyle === 1 || control.pStyle === 2
            anchors.left: parent.left
            anchors.bottom: parent.bottom // Anchored to bottom for vertical growth
            width: control.pStyle === 1 ? parent.width * control.pPosition : parent.width
            height: control.pStyle === 2 ? parent.height * control.pPosition : parent.height
            clip: true

            KSvg.FrameSvgItem {
                width: control.width
                height: control.height
                anchors.left: parent.left
                anchors.bottom: parent.bottom // Ensure content stays full-size
                imagePath: "widgets/tasks"
                prefix: TaskTools.taskPrefix("progress", Plasmoid.location)
                enabledBorders: KSvg.FrameSvg.NoBorder
                layer.enabled: true
                layer.effect: MultiEffect {
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: control.pColor
                }
            }
        }

        // Styles 3, 4, 5, 6: Edge Strips (Rectangle based)
        Rectangle {
            id: progressStrip
            visible: control.pStyle >= 3 && control.pStyle <= 6
            color: control.pColor

            states: [
                State {
                    name: "top"
                    when: control.pStyle === 3
                    AnchorChanges { target: progressStrip; anchors.top: parent.top; anchors.left: parent.left; anchors.bottom: undefined; anchors.right: undefined }
                    PropertyChanges { target: progressStrip; width: parent.width * control.pPosition; height: control.pThick }
                },
                State {
                    name: "bottom"
                    when: control.pStyle === 4
                    AnchorChanges { target: progressStrip; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.top: undefined; anchors.right: undefined }
                    PropertyChanges { target: progressStrip; width: parent.width * control.pPosition; height: control.pThick }
                },
                State {
                    name: "left"
                    when: control.pStyle === 5
                    AnchorChanges { target: progressStrip; anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.right: undefined; anchors.top: undefined }
                    PropertyChanges { target: progressStrip; height: parent.height * control.pPosition; width: control.pThick }
                },
                State {
                    name: "right"
                    when: control.pStyle === 6
                    AnchorChanges { target: progressStrip; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.left: undefined; anchors.top: undefined }
                    PropertyChanges { target: progressStrip; height: parent.height * control.pPosition; width: control.pThick }
                }
            ]
        }
    }
}
