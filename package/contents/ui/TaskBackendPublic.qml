import QtQuick


QtObject {
    id: root

    signal addLauncher(var url)
    signal showAllPlaces()

    function globalRect(item) {
        if (!item) return Qt.rect(0,0,0,0);
        var point = item.mapToGlobal(0,0);
        return Qt.rect(point.x, point.y, item.width, item.height);
    }

    function isApplication(url) {
        if (!url) return false;
        var s = url.toString();
        return s.indexOf("applications:") === 0 || s.indexOf(".desktop") !== -1;
    }

    function tryDecodeApplicationsUrl(url) {
        if (!url) return "";
        var s = url.toString();
        if (s.indexOf("applications:") === 0) return s.substring(13);
        return s;
    }

    function placesActions(launcherUrl, showAll, menu) {
        return [];
    }

    function recentDocumentActions(launcherUrl, menu) {
        return [];
    }

    function jumpListActions(launcherUrl, menu) {
        return [];
    }

    function setActionGroup(action) {
        // No-op for now
    }

    function cancelHighlightWindows() {
        // Handled by main.qml directly via DBus, but keeping dummy just in case
    }
}
