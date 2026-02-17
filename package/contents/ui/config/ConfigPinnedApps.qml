import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.plasma.plasma5support as P5Support

import "../code/singletones"

ConfigPage {
    id: cfg_page

    property var pinnedLaunchers: cfg_page.cfg_launchers
    onPinnedLaunchersChanged: {
        refreshPinnedAppsModel();
    }
    property bool appsLoaded: false
    property bool initialLoadDone: false
    property bool isLoadingApps: false
    property int appsBatchSize: 15
    property var appMetadataCache: ({})
    property string currentSearchText: ""


    // ---------------------------------------

    function cleanUrl(url) {
        // Handle [activity-id] prefix often found in Plasma config
        // e.g. "[uuid] applications:foo.desktop"
        if (url.startsWith("[")) {
            const closingBracket = url.indexOf("]");
            if (closingBracket !== -1) {
                // Return the part after "] " (usually 2 chars, checking simply for applications:)
                // But it might have spaces.
                // Let's rely on finding "applications:"
                const appIndex = url.indexOf("applications:");
                if (appIndex !== -1) {
                    return url.substring(appIndex);
                }
            }
        }
        return url;
    }
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
        connectedSources: ["apps"]
        interval: 0

        property var requestedSources: ({})

        onSourceConnected: (source) => {
            // Data usually comes later in onNewData, but sometimes it's immediate if cached.
            // If data is already present, process it.
            if (source === "apps") {
                cfg_page.startBatchProcessing();
                return;
            }
            if (appsSource.data[source] !== undefined) {
                 cfg_page.processAppSource(source, appsSource.data[source]);
            }
        }

        onNewData: (source, data) => {
            if (source === "apps") {
                 cfg_page.startBatchProcessing();
                 return;
            }
            cfg_page.processAppSource(source, data);
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

        // Start loading by connecting to "apps" list source
        isLoadingApps = true;
        // Connecting to "apps" source will trigger onNewData/onSourceConnected when ready
        // which will then call startBatchProcessing()
        appsSource.connectSource("apps");
    }

    function startBatchProcessing() {
        // Create a prioritized list of desktop files
        const desktopFiles = [];
        const commonPrefixes = ["firefox", "chromium", "chrome", "brave", "dolphin", "konsole", "kate", "gnome-terminal", "org.kde"];
        
        // Build set of pinned sources for O(1) lookup
        const pinnedSources = new Set();
        for (let i = 0; i < pinnedLaunchers.length; i++) {
            let url = cleanUrl(pinnedLaunchers[i]);
            if (url.startsWith("applications:")) {
                const src = url.substring(13);
                pinnedSources.add(src); // remove "applications:" prefix
                
                // Explicitly add pinned apps to the processing list, even if not in appsSource.sources
                // This ensures .local apps are requested
                desktopFiles.push({
                    source: src,
                    priority: -1 // Highest priority
                });
            }
        }

        // Add other available sources
        for (let i = 0; i < appsSource.sources.length; i++) {
            const source = appsSource.sources[i];
            // Skip if already added (pinned apps are handled above)
            // Or just check if source is valid desktop file
            if (source !== "apps" && source.endsWith(".desktop")) {
                if (pinnedSources.has(source)) continue; // Already added

                let priority = 1000;
                const sourceLower = source.toLowerCase();

                // Check if it's a commonly used app
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
                const item = desktopFiles[i];
                const source = item.source;
                // Only connect if not already requested or pinned (pinned forces request sometimes)
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
                // Once loaded, refresh pinned apps to ensure metadata is caught up
                refreshPinnedAppsModel();
            }
        }

        // Start processing
        processBatch();
    }

    function processAppSource(source, data) {
        if (source === "apps" || !source.endsWith(".desktop")) {
            return;
        }

        if (!data) {
             // Try to fetch from source if not provided
             data = appsSource.data[source];
        }
        if (!data) return;

        try {
            // Keys based on user logs: name, iconName, genericName, display, keywords
            
            const isPinned = pinnedLaunchers.indexOf("applications:" + source) !== -1;
            
            // Filter out hidden items unless they are already pinned
            if (data["display"] === false && !isPinned) {
                return;
            }

            const appName = data["name"] || source.replace(".desktop", "");
            const appIcon = data["iconName"] || "application-x-executable";
            const appGenericName = data["genericName"] || "";
            const appUrl = "applications:" + source;
            const appKeywords = data["keywords"] ? data["keywords"].join(" ") : "";
            
            // Cache metadata for fast lookup
            appMetadataCache[appUrl] = {
                name: appName,
                icon: appIcon,
                genericName: appGenericName
            };

            // Check for duplicates in the model
            for (let j = 0; j < installedAppsModel.count; j++) {
                if (installedAppsModel.get(j).url === appUrl) {
                    return;
                }
            }

            const appItem = {
                name: appName,
                icon: appIcon,
                url: appUrl,
                keywords: appKeywords
            };

            installedAppsModel.append(appItem);

            // Update filtered model if needed (initial populate or search match)
            if (cfg_page.currentSearchText.length === 0 && filteredAppsModel.count < 100) {
                 filteredAppsModel.append(appItem);
            } else if (cfg_page.currentSearchText.length > 0) {
                // update search results in real time if data comes in late
                const searchText = cfg_page.currentSearchText.toLowerCase();
                 if (appName.toLowerCase().includes(searchText) || 
                     appUrl.toLowerCase().includes(searchText) || 
                     (appItem.keywords && appItem.keywords.toLowerCase().includes(searchText))) {
                     filteredAppsModel.append(appItem);
                 }
            }

            // If this app is pinned, refresh the pinned list to show updated metadata
            // Only do this periodically or check if it's actually pinned to avoid spamming
            if (isPinned) {
                refreshPinnedAppsModel();
            }

        } catch (e) {
        }
    }

    function filterAppsModel(text) {
        const searchText = (text || "").toLowerCase();
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

    function refreshPinnedAppsModel(sourceList) {
        pinnedAppsModel.clear();
        let list = sourceList || pinnedLaunchers;
        for (let i = 0; i < list.length; i++) {
            let launcher = list[i];
            let url = cleanUrl(launcher);
            let name = getNameForUrl(url); // Use cleaned URL for lookup
            let icon = getIconForUrl(url); // Use cleaned URL for lookup
            pinnedAppsModel.append({
                "name": name,
                "icon": icon,
                "url": url
            });
        }
    }

    function getNameForUrl(url) {
        if (url.startsWith("preferred://")) {
            if (url === "preferred://browser") return Wrappers.i18n("Default Web Browser");
            if (url === "preferred://filemanager") return Wrappers.i18n("Default File Manager");
            if (url === "preferred://mail") return Wrappers.i18n("Default Mail Client");
            return Wrappers.i18n("Default Application");
        }

        if (appMetadataCache[url]) {
            return appMetadataCache[url].name;
        }

        // Fallback for uncached items
        let appName = url;
        if (appName.startsWith("applications:")) {
            appName = appName.substring(13);
            if (appName.endsWith(".desktop")) {
                appName = appName.substring(0, appName.length - 8);
            }
            // Simple prettify fallback
            appName = appName.split(/[-_.]/g).map(word => {
               return word.charAt(0).toUpperCase() + word.slice(1);
            }).join(" ");
        }
        return appName;
    }

    function getIconForUrl(url) {
        if (url.startsWith("preferred://")) {
            if (url === "preferred://browser") return "internet-web-browser";
            if (url === "preferred://filemanager") return "system-file-manager";
            if (url === "preferred://mail") return "internet-mail";
            return "preferences-desktop-default-applications";
        }

        if (appMetadataCache[url]) {
            return appMetadataCache[url].icon;
        }

        // Fallback
        if (url.startsWith("applications:")) {
            let appId = url.substring(13);
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

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: mainPage
        
        // Ensure the stack view doesn't clip content during transitions if possible, 
        // though clipping is default.
        clip: true
    }

    Component {
        id: mainPage
        Item {
            // Main page container
            
            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.largeSpacing

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

                        onEntered: (drag) => {
                            if (cfg_page.isDragging) {
                                // Calculate new index based on drop position
                                var newIndex = Math.floor((drag.y + pinnedAppsList.contentY) / 48);
                                // Approximate item height
                                if (newIndex >= 0 && newIndex < pinnedAppsModel.count) {
                                    cfg_page.dropItemIndex = newIndex;
                                }
                            }
                        }

                        onPositionChanged: (drag) => {
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

                        Drag.active: dragMouseArea.drag.active
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
                                id: dragHandle
                                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                Layout.preferredHeight: parent.height

                                Grid {
                                    anchors.centerIn: parent
                                    columns: 2
                                    rows: 3
                                    columnSpacing: 2
                                    rowSpacing: 2
                                    
                                    Repeater {
                                        model: 6
                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: Kirigami.Theme.textColor
                                            opacity: 0.5
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    id: dragMouseArea
                                    anchors.fill: parent
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    
                                    drag.target: pinnedAppDelegate
                                    drag.axis: Drag.YAxis
                                    
                                    onPressed: {
                                        cfg_page.dragItemIndex = pinnedAppDelegate.index;
                                        cfg_page.isDragging = true;
                                    }
                                    
                                    onReleased: {
                                        cfg_page.isDragging = false;
                                        
                                        // Robust index calculation using global coordinates
                                        var mappedPos = pinnedAppsList.contentItem.mapFromItem(cfg_page, pinnedAppDelegate.x, pinnedAppDelegate.y + pinnedAppDelegate.height/2);
                                        var targetIndex = Math.floor(mappedPos.y / 48);

                                        // Clamp index to valid range
                                        if (targetIndex < 0) targetIndex = 0;
                                        if (targetIndex >= pinnedAppsModel.count) targetIndex = pinnedAppsModel.count - 1;

                                        // Capture current drag index
                                        var dragIdx = cfg_page.dragItemIndex;

                                        // Reset state BEFORE acting (because action might destroy us)
                                        cfg_page.dragItemIndex = -1;
                                        cfg_page.dropItemIndex = -1;

                                        if (dragIdx !== -1 && targetIndex !== -1 && targetIndex !== dragIdx) {
                                            cfg_page.moveItem(dragIdx, targetIndex);
                                        } else {
                                            // Force refresh even if index didn't change
                                            cfg_page.refreshPinnedAppsModel();
                                        }
                                    }
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
                                
                                ToolTip.text: pinnedAppDelegate.model.url
                                ToolTip.visible: mouseArea.containsMouse
                                ToolTip.delay: 1000
                            }

                            Button {
                                icon.name: "list-remove"
                                onClicked: {
                                    // Create a copy to ensure change detection
                                    let currentLaunchers = Array.from(cfg_page.pinnedLaunchers);
                                    currentLaunchers.splice(pinnedAppDelegate.index, 1);
                                    cfg_page.cfg_launchers = currentLaunchers;
                                    // pinnedLaunchers binding will update automatically
                                    cfg_page.refreshPinnedAppsModel();
                                }
                                ToolTip.text: Wrappers.i18n("Remove")
                                ToolTip.visible: hovered
                                ToolTip.delay: 1000
                            }
                        }

                        // MouseArea for hover effects only (no drag)
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                // Maybe handle click selection if needed?
                            }
                            // Allow passing clicks to children (like buttons) if z-ordered correctly, 
                            // but simpler to just put this below visuals or not fill parent if possible.
                            // Actually, putting it here AFTER RowLayout covers the button again.
                            // We need it for hover effect (highlight).
                            z: -1
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        id: addAppButton
                        icon.name: "list-add"
                        text: Wrappers.i18n("Add Application...")
                        onClicked: {
                            stackView.push(addAppsPage)
                            if (!cfg_page.initialLoadDone) {
                                cfg_page.initialLoadDone = true;
                                initialLoadTimer.start();
                            }
                        }
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
        }
    }

    Component {
        id: addAppsPage
        Item {
            // Add apps page container
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing

                    Button {
                        icon.name: "go-previous"
                        text: Wrappers.i18n("Back")
                        onClicked: stackView.pop()
                    }
                    
                    Label {
                        text: Wrappers.i18n("Add Application")
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                        Layout.alignment: Qt.AlignVCenter
                        color: Kirigami.Theme.textColor
                    }

                    Item { Layout.fillWidth: true }
                }
                
                // Search Field
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    placeholderText: Wrappers.i18n("Search applications...")
                    text: cfg_page.currentSearchText
                    onTextChanged: {
                        cfg_page.currentSearchText = text
                        searchTimer.restart()
                    }
                    leftPadding: searchIcon.width + Kirigami.Units.smallSpacing * 2
                    
                    Kirigami.Icon {
                        id: searchIcon
                        source: "search"
                        width: Kirigami.Units.iconSizes.smallMedium
                        height: width
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        color: Kirigami.Theme.textColor
                        opacity: 0.7
                    }
                }

                Timer {
                    id: searchTimer
                    interval: 300
                    onTriggered: cfg_page.filterAppsModel(cfg_page.currentSearchText)
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: appsListView
                        model: filteredAppsModel
                        clip: true

                        onContentYChanged: {
                            if (contentY + height >= contentHeight - 200 && !cfg_page.isLoadingApps) {
                                cfg_page.loadMoreApps();
                            }
                        }

                        delegate: ItemDelegate {
                            id: appsDelegate
                            required property var model
                            width: ListView.view.width
                            
                            onClicked: {
                                cfg_page.addLauncher(appsDelegate.model.url);
                                stackView.pop();
                            }

                            contentItem: RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: appsDelegate.model.icon || "application-x-executable"
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 0

                                    Label {
                                        Layout.fillWidth: true
                                        text: appsDelegate.model.name || appsDelegate.model.url
                                        wrapMode: Text.Wrap
                                        font.bold: true
                                        color: Kirigami.Theme.textColor
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: appsDelegate.model.genericName || ""
                                        elide: Text.ElideRight
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.7
                                        color: Kirigami.Theme.textColor
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
    }
    function addLauncher(url) {
        // Create a copy to ensure change detection
        let currentLaunchers = Array.from(pinnedLaunchers);
        
        // Don't add if already in the list
        if (currentLaunchers.indexOf(url) !== -1) {
            return;
        }

        currentLaunchers.push(url);
        cfg_page.cfg_launchers = currentLaunchers;
        // pinnedLaunchers binding will update automatically
        refreshPinnedAppsModel();
    }

    // Move item in the model and update configuration
    function moveItem(fromIndex, toIndex) {
        if (fromIndex === toIndex) return;
        
        // Update visual model immediately
        pinnedAppsModel.move(fromIndex, toIndex, 1);
        
        // Rebuild list from model to update config
        let list = [];
        for (let i = 0; i < pinnedAppsModel.count; i++) {
            list.push(pinnedAppsModel.get(i).url);
        }
        
        cfg_page.cfg_launchers = list;
        // pinnedLaunchers binding should update automatically from cfg_launchers
    }
}
