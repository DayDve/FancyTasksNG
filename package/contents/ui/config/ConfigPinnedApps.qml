pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.plasma.extras as PlasmaExtras

import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

import "../code/singletones"

ConfigPage {
    id: cfg_page

    property var pinnedLaunchers: cfg_page.cfg_launchers
    property bool appsLoaded: false
    property bool initialLoadDone: false
    property bool isLoadingApps: false
    property int appsBatchSize: 15


    // ---------------------------------------

    // Initial app loading timer
    Timer {
        id: initialLoadTimer
        interval: 200
        repeat: false
        onTriggered: {
            cfg_page.isLoadingApps = true;
            cfg_page.loadInstalledApps();
        }
    }

    // App loading data source
    P5Support.DataSource {
        id: appsSource
        engine: "apps"
        connectedSources: ["apps:"]
        interval: 0

        property var requestedSources: ({})

        onSourceConnected: (source) => {
            cfg_page.processAppSource(source);
        }
    }

    ListModel {
        id: installedAppsModel
    }

    ListModel {
        id: filteredAppsModel
    }

    function loadInstalledApps() {
        // Add default special launchers
        if (installedAppsModel.count === 0) {
            installedAppsModel.append({
                name: Wrappers.i18n("Default Web Browser"),
                icon: "internet-web-browser",
                url: "preferred://browser",
                keywords: "web browser internet"
            });
            installedAppsModel.append({
                name: Wrappers.i18n("Default File Manager"),
                icon: "system-file-manager",
                url: "preferred://filemanager",
                keywords: "files folder"
            });
            installedAppsModel.append({
                name: Wrappers.i18n("Default Mail Client"),
                icon: "internet-mail",
                url: "preferred://mail",
                keywords: "email mail"
            });
        }

        // Start batch processing of app sources
        startBatchProcessing();
    }

    function startBatchProcessing() {
        // Create a prioritized list of desktop files
        const desktopFiles = [];
        const commonPrefixes = ["firefox", "chromium", "chrome", "brave", "dolphin", "konsole", "kate", "gnome-terminal", "org.kde"];
        // Pre-sort desktop files with common ones first
        for (let i = 0; i < appsSource.sources.length; i++) {
            const source = appsSource.sources[i];
            if (source !== "apps:" && source.endsWith(".desktop")) {
                // Check if it's a commonly used app
                let priority = 1000;
                const sourceLower = source.toLowerCase();

                for (let j = 0; j < commonPrefixes.length; j++) {
                    if (sourceLower.includes(commonPrefixes[j])) {
                        priority = j;
                        break;
                    }
                }

                desktopFiles.push({
                    source: source,
                    priority: priority
                });
            }
        }

        // Sort by priority
        desktopFiles.sort((a, b) => a.priority - b.priority);
        // Process in batches
        let processedCount = 0;
        function processBatch() {
            const batchSize = 15;
            const end = Math.min(processedCount + batchSize, desktopFiles.length);

            for (let i = processedCount; i < end; i++) {
                const source = desktopFiles[i].source;
                if (!appsSource.requestedSources[source]) {
                    appsSource.connectSource(source);
                    appsSource.requestedSources[source] = true;
                }
            }

            processedCount = end;
            if (processedCount < desktopFiles.length) {
                // Schedule next batch
                Qt.callLater(processBatch);
            } else {
                // All batches scheduled
                isLoadingApps = false;
                appsLoaded = true;
            }
        }

        // Start processing
        processBatch();
    }

    function processAppSource(source) {
        if (source === "apps:" || !source.endsWith(".desktop")) {
            return;
        }

        try {
            // Extract app name
            let appName = source.replace(".desktop", "");
            const lastSlash = appName.lastIndexOf("/");
            if (lastSlash !== -1) {
                appName = appName.substring(lastSlash + 1);
            }
            appName = appName.split(/[-_.]/).map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()).join(" ");
            // Check for duplicates
            for (let j = 0; j < installedAppsModel.count; j++) {
                if (installedAppsModel.get(j).url === "applications:" + source) {
                    return;
                }
            }

            installedAppsModel.append({
                name: appName,
                icon: appName.toLowerCase().replace(/\s+/g, "-") || "application-x-executable",
                url: "applications:" + source,
                keywords: ""
            });
            // Update filtered model if needed
            if (searchField.text.length === 0 && filteredAppsModel.count < 100) {
                filteredAppsModel.append({
                    name: appName,
                    icon: appName.toLowerCase().replace(/\s+/g, "-") || "application-x-executable",
                    url: "applications:" + source,
                    keywords: ""
                });
            }
        } catch (e) {
            console.log("Error processing app:", source, e);
        }
    }

    function filterAppsModel() {
        const searchText = searchField.text.toLowerCase();
        // Optimization for empty search with already filled model
        if (searchText.length === 0 && filteredAppsModel.count > 0 && filteredAppsModel.count === Math.min(installedAppsModel.count, 100)) {
            return;
        }

        filteredAppsModel.clear();

        for (let i = 0; i < installedAppsModel.count; i++) {
            const app = installedAppsModel.get(i);
            // Apply search filter
            if (searchText && searchText.length > 0) {
                if (app.name.toLowerCase().includes(searchText) || app.url.toLowerCase().includes(searchText) || (app.keywords && app.keywords.toLowerCase().includes(searchText))) {
                    filteredAppsModel.append(app);
                }
            } else {
                filteredAppsModel.append(app);
                // Limit initial load for better performance
                if (filteredAppsModel.count >= 100) {
                    break;
                }
            }
        }
    }

    function loadMoreApps() {
        if (isLoadingApps)
            return;
        if (filteredAppsModel.count < installedAppsModel.count) {
            const startIndex = filteredAppsModel.count;
            const endIndex = Math.min(startIndex + 30, installedAppsModel.count);

            for (let i = startIndex; i < endIndex; i++) {
                filteredAppsModel.append(installedAppsModel.get(i));
            }
        }
    }

    Component.onCompleted: {
        refreshPinnedAppsModel();
    }

    function refreshPinnedAppsModel() {
        pinnedAppsModel.clear();
        for (let i = 0; i < pinnedLaunchers.length; i++) {
            let launcher = pinnedLaunchers[i];
            let name = getNameForUrl(launcher);
            let icon = getIconForUrl(launcher);
            pinnedAppsModel.append({
                "name": name,
                "icon": icon,
                "url": launcher
            });
        }
    }

    function getNameForUrl(url) {
        let appName = url;
        if (appName.indexOf("preferred://") === 0) {
            if (appName === "preferred://browser")
                return Wrappers.i18n("Default Web Browser");
            if (appName === "preferred://filemanager")
                return Wrappers.i18n("Default File Manager");
            if (appName === "preferred://mail")
                return Wrappers.i18n("Default Mail Client");
            return Wrappers.i18n("Default Application");
        }

        if (appName.indexOf("applications:") === 0) {
            // Check installed apps model first
            for (let i = 0; i < installedAppsModel.count; i++) {
                const app = installedAppsModel.get(i);
                if (app.url === appName) {
                    return app.name;
                }
            }

            // Fallback formatting
            appName = appName.substring(13);
            if (appName.endsWith(".desktop")) {
                appName = appName.substring(0, appName.length - 8);
            }
            appName = appName.split(/[-_.]/g).map(word => {
                return word.charAt(0).toUpperCase() + word.slice(1);
            }).join(" ");
        }

        return appName;
    }

    function getIconForUrl(url) {
        let appId = url;
        // Check installed apps model first
        for (let i = 0; i < installedAppsModel.count; i++) {
            const app = installedAppsModel.get(i);
            if (app.url === appId) {
                return app.icon;
            }
        }

        if (appId.indexOf("preferred://") === 0) {
            if (appId === "preferred://browser")
                return "internet-web-browser";
            if (appId === "preferred://filemanager")
                return "system-file-manager";
            if (appId === "preferred://mail")
                return "internet-mail";
            return "preferences-desktop-default-applications";
        }

        if (appId.indexOf("applications:") === 0) {
            appId = appId.substring(13);
            if (appId.endsWith(".desktop")) {
                return appId.substring(0, appId.length - 8).toLowerCase();
            }
            return appId.toLowerCase();
        }

        return "application-x-executable";
    }

    resources: [
        ListModel {
            id: pinnedAppsModel
        }
    ]

    // For better drag and drop reordering
    property int dragItemIndex: -1
    property int dropItemIndex: -1
    property bool isDragging: false

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        resources: [
            // App picker dialog moved here
            Dialog {
                id: appPickerDialog
                title: Wrappers.i18n("Add Application")
                modal: true
                standardButtons: Dialog.Close

                width: Math.min(800, parent.width - Kirigami.Units.gridUnit * 4)
                height: Math.min(600, parent.height - Kirigami.Units.gridUnit * 4)

                anchors.centerIn: parent

                onOpened: {
                    if (!cfg_page.initialLoadDone) {
                        cfg_page.initialLoadDone = true;
                        initialLoadTimer.start();
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaExtras.SearchField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: Wrappers.i18n("Search applications...")
                        onTextChanged: searchTimer.restart()
                    }

                    Timer {
                        id: searchTimer
                        interval: 300
                        onTriggered: cfg_page.filterAppsModel()
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: appsListView
                            model: filteredAppsModel

                            onContentYChanged: {
                                if (contentY + height >= contentHeight - 200 && !cfg_page.isLoadingApps) {
                                    cfg_page.loadMoreApps();
                                }
                            }

                            delegate: ItemDelegate {
                                id: appsDelegate
                                required property var model
                                width: ListView.view.width

                                contentItem: RowLayout {
                                    spacing: Kirigami.Units.smallSpacing

                                    Kirigami.Icon {
                                        source: appsDelegate.model.icon || "application-x-executable"
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                                    }

                                    Label {
                                        text: appsDelegate.model.name || appsDelegate.model.url
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        font.bold: true
                                    }

                                    Button {
                                        icon.name: "list-add"
                                        text: Wrappers.i18n("Add")
                                        onClicked: {
                                            cfg_page.addLauncher(appsDelegate.model.url);
                                            appPickerDialog.close();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Loading indicator
                    Item {
                        visible: cfg_page.isLoadingApps && filteredAppsModel.count === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        BusyIndicator {
                            anchors.centerIn: parent
                            running: cfg_page.isLoadingApps
                        }
                    }
                }
            }
        ]

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: Wrappers.i18n("Add applications to pin to the taskbar. Drag items to reorder them.")
            visible: true
        }

        ListView {
            id: pinnedAppsList
            Layout.fillWidth: true
            Layout.fillHeight: true

            model: pinnedAppsModel

            // Disable animations during drag
            interactive: !cfg_page.isDragging

            // Add scrollbar when needed
            ScrollBar.vertical: ScrollBar {}

            // Add drop area to handle autoscroll
            DropArea {
                id: dropArea
                anchors.fill: parent

                onEntered: {
                    if (cfg_page.isDragging) {
                        // Calculate new index based on drop position
                        var newIndex = Math.floor((drag.y + pinnedAppsList.contentY) / 48);
                        // Approximate item height
                        if (newIndex >= 0 && newIndex < pinnedAppsModel.count) {
                            cfg_page.dropItemIndex = newIndex;
                        }
                    }
                }

                onPositionChanged: {
                    if (cfg_page.isDragging) {
                        // Handle auto-scrolling
                        var localY = drag.y;
                        if (localY < 50) {
                            // Auto-scroll up
                            autoScrollTimer.direction = -1;
                            autoScrollTimer.running = true;
                        } else if (localY > pinnedAppsList.height - 50) {
                            // Auto-scroll down
                            autoScrollTimer.direction = 1;
                            autoScrollTimer.running = true;
                        } else {
                            // Stop auto-scrolling
                            autoScrollTimer.running = false;
                        }

                        // Calculate drop index
                        var newIndex = Math.floor((localY + pinnedAppsList.contentY) / 48);
                        if (newIndex >= 0 && newIndex < pinnedAppsModel.count) {
                            cfg_page.dropItemIndex = newIndex;
                        }
                    }
                }

                onDropped: {
                    autoScrollTimer.running = false;
                }

                onExited: {
                    autoScrollTimer.running = false;
                }
            }

            // Timer for auto-scrolling during drag
            Timer {
                id: autoScrollTimer
                interval: 50
                repeat: true
                property int direction: 0 // -1 for up, 1 for down
                property int scrollStep: 10

                onTriggered: {
                    pinnedAppsList.contentY = Math.max(0, Math.min(pinnedAppsList.contentY + direction * scrollStep, pinnedAppsList.contentHeight - pinnedAppsList.height));
                }
            }

            delegate: Item {
                id: pinnedAppDelegate
                required property var model
                required property int index

                width: ListView.view.width
                height: 48

                // Properties for drag operation
                property bool beingDragged: index === cfg_page.dragItemIndex

                Drag.active: mouseArea.drag.active
                Drag.source: pinnedAppDelegate
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                // Visual representation during drag
                states: [
                    State {
                        when: pinnedAppDelegate.beingDragged
                        ParentChange {
                            target: pinnedAppDelegate
                            parent: cfg_page
                        }
                        PropertyChanges {
                            pinnedAppDelegate.z: 100
                            pinnedAppDelegate.opacity: 0.8
                        }
                    }
                ]

                Rectangle {
                    id: itemHighlight
                    anchors.fill: parent
                    color: cfg_page.dropItemIndex === pinnedAppDelegate.index && cfg_page.isDragging ? Kirigami.Theme.highlightColor : mouseArea.containsMouse ? Kirigami.Theme.highlightColor.lighter(0.7) : "transparent"
                    opacity: 0.3
                    radius: 3

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    // Drag handle
                    Item {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: parent.height

                        Rectangle {
                            width: Kirigami.Units.smallSpacing
                            height: Kirigami.Units.iconSizes.small
                            radius: width / 2
                            anchors.centerIn: parent
                            color: Kirigami.Theme.textColor
                            opacity: 0.5
                        }
                    }

                    Kirigami.Icon {
                        source: pinnedAppDelegate.model.icon
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }

                    Label {
                        text: pinnedAppDelegate.model.name
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Label {
                        text: pinnedAppDelegate.model.url
                        opacity: 0.6
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: parent.width / 3
                        horizontalAlignment: Text.AlignRight
                        visible: Kirigami.Settings.isMobile ? false : true
                    }

                    Button {
                        icon.name: "list-remove"
                        onClicked: {
                            let currentLaunchers = cfg_page.pinnedLaunchers;
                            currentLaunchers.splice(pinnedAppDelegate.index, 1);
                            cfg_page.cfg_launchers = currentLaunchers;
                            cfg_page.pinnedLaunchers = currentLaunchers;
                            cfg_page.refreshPinnedAppsModel();
                        }
                        ToolTip.text: Wrappers.i18n("Remove")
                        ToolTip.visible: hovered
                        ToolTip.delay: 1000
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                    drag.target: pinnedAppDelegate
                    drag.axis: Drag.YAxis

                    onPressed: {
                        // Start dragging
                        cfg_page.dragItemIndex = pinnedAppDelegate.index;
                        cfg_page.isDragging = true;
                    }

                    onReleased: {
                        // End dragging
                        cfg_page.isDragging = false;
                        if (cfg_page.dropItemIndex !== -1 && cfg_page.dragItemIndex !== -1 && cfg_page.dropItemIndex !== cfg_page.dragItemIndex) {
                            // Move the item
                            cfg_page.moveItem(cfg_page.dragItemIndex, cfg_page.dropItemIndex);
                        }

                        // Reset state
                        cfg_page.dragItemIndex = -1;
                        cfg_page.dropItemIndex = -1;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                id: addAppButton
                icon.name: "list-add"
                text: Wrappers.i18n("Add Application...")
                onClicked: appPickerDialog.open()
                Layout.fillWidth: true
            }

            Button {
                id: addSpecialButton
                icon.name: "preferences-desktop-default-applications"
                text: Wrappers.i18n("Add Special Launcher...")
                onClicked: specialLauncherMenu.popup()

                Menu {
                    id: specialLauncherMenu

                    MenuItem {
                        text: Wrappers.i18n("Default Web Browser")
                        icon.name: "internet-web-browser"
                        onTriggered: {
                            cfg_page.addLauncher("preferred://browser");
                        }
                    }

                    MenuItem {
                        text: Wrappers.i18n("Default File Manager")
                        icon.name: "system-file-manager"
                        onTriggered: {
                            cfg_page.addLauncher("preferred://filemanager");
                        }
                    }

                    MenuItem {
                        text: Wrappers.i18n("Default Mail Client")
                        icon.name: "internet-mail"
                        onTriggered: {
                            cfg_page.addLauncher("preferred://mail");
                        }
                    }
                }
            }
        }
    }

    function addLauncher(url) {
        let currentLaunchers = pinnedLaunchers;
        // Don't add if already in the list
        if (currentLaunchers.indexOf(url) !== -1) {
            return;
        }

        currentLaunchers.push(url);
        cfg_page.cfg_launchers = currentLaunchers;
        pinnedLaunchers = currentLaunchers;
        refreshPinnedAppsModel();
    }

    // Move item in the model and update configuration
    function moveItem(fromIndex, toIndex) {
        // First create a copy of the current launchers
        let currentLaunchers = [];
        for (let i = 0; i < pinnedLaunchers.length; i++) {
            currentLaunchers.push(pinnedLaunchers[i]);
        }

        // Move the item in the array
        const item = currentLaunchers.splice(fromIndex, 1)[0];
        currentLaunchers.splice(toIndex, 0, item);

        console.log("Moving item from", fromIndex, "to", toIndex);
        console.log("New order:", currentLaunchers.join(", "));
        // Update the configuration
        // Update the configuration
        cfg_page.cfg_launchers = currentLaunchers;
        pinnedLaunchers = currentLaunchers;
        // Refresh model to ensure view is updated
        refreshPinnedAppsModel();
    }
}
