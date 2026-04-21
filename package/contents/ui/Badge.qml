import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "code/singletones"

Rectangle {
    id: badgeRect

    property alias text: label.text
    property alias textColor: label.color
    property int number: 0
    property bool isRound: true
    property real fontPointSize: 8 // Reduced for better fit in small circles
    property string iconSource: ""
    property bool hovered: false
    property bool isUrgent: false
    property bool showBackground: true
    property bool isBold: false
    property real fontFactor: 0.85

    readonly property string defaultNotificationIcon: "notifications-symbolic"

    // Visual state coloring - Bound to theme palette
    property color highlightColor: Kirigami.Theme.highlightColor
    property color themeTextColor: showBackground ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
    property color themeBgColor: Kirigami.Theme.backgroundColor

    implicitHeight: Math.round(Kirigami.Units.gridUnit * 0.9)
    
    width: {
        const padding = Math.round(Kirigami.Units.smallSpacing * 2);
        return Math.max(height, Math.round(label.contentWidth + padding));
    }

    radius: height / 2
    antialiasing: true
    // Theme-aware background: uses system background color, but stays red for urgent items
    color: showBackground ? (isUrgent ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.backgroundColor) : "transparent"

    // Bright border using highlight color
    border.color: showBackground ? (isUrgent ? "transparent" : highlightColor) : "transparent"
    border.width: hovered ? 2 : 1
    
    visible: (number > 0) || (iconSource !== "")

    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }

    // Icon Layer: Using Kirigami.Icon
    Kirigami.Icon {
        id: icon
        anchors.centerIn: parent
        // Scale up the icon if there is no background to keep it visible
        width: Math.round(parent.height * (badgeRect.showBackground ? 0.65 : 0.85))
        height: width
        
        source: badgeRect.iconSource
        visible: (badgeRect.iconSource !== "") && (badgeRect.number <= 0)
        
        smooth: true
        roundToIconSize: false
        // Adaptive icon color: white on red background, theme-aware otherwise
        color: badgeRect.isUrgent ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        
        // Visual feedback for interaction
        scale: badgeRect.hovered ? 1.2 : 1.0
        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
    }

    // Text Layer: Using Text with NativeRendering
    Text {
        id: label
        anchors.centerIn: parent
        anchors.verticalCenterOffset: text === "…" ? -Math.round(parent.height * 0.22) : 0
        
        width: implicitWidth
        height: parent.height
        
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        
        font.pointSize: badgeRect.fontPointSize * badgeRect.fontFactor
        font.bold: badgeRect.isBold
        
        renderType: Text.QtRendering
        antialiasing: true
        // Adaptive text color: white on red background, theme-aware otherwise
        color: badgeRect.isUrgent ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        visible: badgeRect.number > 0
        
        text: {
            if (badgeRect.number < 0) {
                return Wrappers.i18nc("Invalid", "—");
            }
            // Show full number up to 999, then ellipsis as requested
            if (badgeRect.number > 999) {
                return "…";
            }
            return badgeRect.number.toLocaleString(Qt.locale(), 'f', 0);
        }
    }
}
