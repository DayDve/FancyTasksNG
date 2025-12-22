import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support

Kirigami.ScrollablePage {
    id: pinnedAppsDialog

    property var pinnedLaunchers: plasmoid.configuration.launchers
    property bool appsLoaded: false
    property bool initialLoadDone: false
    property bool isLoadingApps: false
    property int appsBatchSize: 15

    // --- Properties to silence KCM errors ---
    // Defaults for existing aliases
    property var cfg_launchersDefault

    // Missing properties from main.xml not used in this tab
    property var cfg_showOnlyCurrentScreen
    property var cfg_showOnlyCurrentScreenDefault
    property var cfg_showOnlyCurrentDesktop
    property var cfg_showOnlyCurrentDesktopDefault
    property var cfg_showOnlyCurrentActivity
    property var cfg_showOnlyCurrentActivityDefault
    property var cfg_showOnlyMinimized
    property var cfg_showOnlyMinimizedDefault
    property var cfg_unhideOnAttention
    property var cfg_unhideOnAttentionDefault
    property var cfg_groupingStrategy
    property var cfg_groupingStrategyDefault
    property var cfg_iconOnly
    property var cfg_iconOnlyDefault
    property var cfg_groupedTaskVisualization
    property var cfg_groupedTaskVisualizationDefault
    property var cfg_groupPopups
    property var cfg_groupPopupsDefault
    property var cfg_onlyGroupWhenFull
    property var cfg_onlyGroupWhenFullDefault
    property var cfg_groupingAppIdBlacklist
    property var cfg_groupingAppIdBlacklistDefault
    property var cfg_groupingLauncherUrlBlacklist
    property var cfg_groupingLauncherUrlBlacklistDefault
    property var cfg_sortingStrategy
    property var cfg_sortingStrategyDefault
    property var cfg_separateLaunchers
    property var cfg_separateLaunchersDefault
    property var cfg_hideLauncherOnStart
    property var cfg_hideLauncherOnStartDefault
    property var cfg_maxStripes
    property var cfg_maxStripesDefault
    property var cfg_maxButtonLength
    property var cfg_maxButtonLengthDefault
    property var cfg_forceStripes
    property var cfg_forceStripesDefault
    property var cfg_showToolTips
    property var cfg_showToolTipsDefault
    property var cfg_taskMaxWidth
    property var cfg_taskMaxWidthDefault
    property var cfg_wheelEnabled
    property var cfg_wheelEnabledDefault
    property var cfg_wheelSkipMinimized
    property var cfg_wheelSkipMinimizedDefault
    property var cfg_highlightWindows
    property var cfg_highlightWindowsDefault
    property var cfg_launchers // Used manually via plasmoid.configuration
    property var cfg_middleClickAction
    property var cfg_middleClickActionDefault
    property var cfg_indicateAudioStreams
    property var cfg_indicateAudioStreamsDefault
    property var cfg_iconScale
    property var cfg_iconScaleDefault
    property var cfg_iconSizePx
    property var cfg_iconSizePxDefault
    property var cfg_iconSizeOverride
    property var cfg_iconSizeOverrideDefault
    property var cfg_fill
    property var cfg_fillDefault
    property var cfg_taskHoverEffect
    property var cfg_taskHoverEffectDefault
    property var cfg_maxTextLines
    property var cfg_maxTextLinesDefault
    property var cfg_minimizeActiveTaskOnClick
    property var cfg_minimizeActiveTaskOnClickDefault
    property var cfg_reverseMode
    property var cfg_reverseModeDefault
    property var cfg_iconSpacing
    property var cfg_iconSpacingDefault
    property var cfg_indicatorsEnabled
    property var cfg_indicatorsEnabledDefault
    property var cfg_indicatorProgress
    property var cfg_indicatorProgressDefault
    property var cfg_indicatorProgressColor
    property var cfg_indicatorProgressColorDefault
    property var cfg_disableInactiveIndicators
    property var cfg_disableInactiveIndicatorsDefault
    property var cfg_indicatorsAnimated
    property var cfg_indicatorsAnimatedDefault
    property var cfg_groupIconEnabled
    property var cfg_groupIconEnabledDefault
    property var cfg_indicatorLocation
    property var cfg_indicatorLocationDefault
    property var cfg_indicatorStyle
    property var cfg_indicatorStyleDefault
    property var cfg_indicatorMinLimit
    property var cfg_indicatorMinLimitDefault
    property var cfg_indicatorMaxLimit
    property var cfg_indicatorMaxLimitDefault
    property var cfg_indicatorDesaturate
    property var cfg_indicatorDesaturateDefault
    property var cfg_indicatorGrow
    property var cfg_indicatorGrowDefault
    property var cfg_indicatorGrowFactor
    property var cfg_indicatorGrowFactorDefault
    property var cfg_indicatorEdgeOffset
    property var cfg_indicatorEdgeOffsetDefault
    property var cfg_indicatorSize
    property var cfg_indicatorSizeDefault
    property var cfg_indicatorLength
    property var cfg_indicatorLengthDefault
    property var cfg_indicatorRadius
    property var cfg_indicatorRadiusDefault
    property var cfg_indicatorShrink
    property var cfg_indicatorShrinkDefault
    property var cfg_indicatorDominantColor
    property var cfg_indicatorDominantColorDefault
    property var cfg_indicatorAccentColor
    property var cfg_indicatorAccentColorDefault
    property var cfg_indicatorCustomColor
    property var cfg_indicatorCustomColorDefault
    property var cfg_useBorders
    property var cfg_useBordersDefault
    property var cfg_taskSpacingSize
    property var cfg_taskSpacingSizeDefault
    property var cfg_buttonColorize
    property var cfg_buttonColorizeDefault
    property var cfg_buttonColorizeInactive
    property var cfg_buttonColorizeInactiveDefault
    property var cfg_buttonColorizeDominant
    property var cfg_buttonColorizeDominantDefault
    property var cfg_buttonColorizeCustom
    property var cfg_buttonColorizeCustomDefault
    property var cfg_disableButtonSvg
    property var cfg_disableButtonSvgDefault
    property var cfg_disableButtonInactiveSvg
    property var cfg_disableButtonInactiveSvgDefault
    property var cfg_overridePlasmaButtonDirection
    property var cfg_overridePlasmaButtonDirectionDefault
    property var cfg_plasmaButtonDirection
    property var cfg_plasmaButtonDirectionDefault
    property var cfg_indicatorReverse
    property var cfg_indicatorReverseDefault
    property var cfg_indicatorOverride
    property var cfg_indicatorOverrideDefault
    property var cfg_iconZoomFactor
    property var cfg_iconZoomFactorDefault
    property var cfg_iconZoomDuration
    property var cfg_iconZoomDurationDefault
    // ---------------------------------------

    // Initial app loading timer
    Timer {
        id: initialLoadTimer
        interval: 200
        repeat: false
        onTriggered: {
            isLoadingApps = true;
            loadInstalledApps();
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
            processAppSource(source);
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
                name: i18n("Default Web Browser"),
                icon: "internet-web-browser",
                url: "preferred://browser",
                keywords: "web browser internet"
            });
            installedAppsModel.append({
                name: i18n("Default File Manager"),
                icon: "system-file-manager",
                url: "preferred://filemanager",
                keywords: "files folder"
            });
            installedAppsModel.append({
                name: i18n("Default Mail Client"),
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
                return i18n("Default Web Browser");
            if (appName === "preferred://filemanager")
                return i18n("Default File Manager");
            if (appName === "preferred://mail")
                return i18n("Default Mail Client");
            return i18n("Default Application");
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

    ListModel {
        id: pinnedAppsModel
    }

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
                title: i18n("Add Application")
                modal: true
                standardButtons: Dialog.Close

                width: Math.min(800, parent.width - Kirigami.Units.gridUnit * 4)
                height: Math.min(600, parent.height - Kirigami.Units.gridUnit * 4)

                anchors.centerIn: parent

                onOpened: {
                    if (!initialLoadDone) {
                        initialLoadDone = true;
                        initialLoadTimer.start();
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaExtras.SearchField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: i18n("Search applications...")
                        onTextChanged: searchTimer.restart()
                    }

                    Timer {
                        id: searchTimer
                        interval: 300
                        onTriggered: filterAppsModel()
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: appsListView
                            model: filteredAppsModel

                            onContentYChanged: {
                                if (contentY + height >= contentHeight - 200 && !isLoadingApps) {
                                    loadMoreApps();
                                }
                            }

                            delegate: ItemDelegate {
                                width: appsListView.width

                                contentItem: RowLayout {
                                    spacing: Kirigami.Units.smallSpacing

                                    Kirigami.Icon {
                                        source: model.icon || "application-x-executable"
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                                    }

                                    Label {
                                        text: model.name || model.url
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        font.bold: true
                                    }

                                    Button {
                                        icon.name: "list-add"
                                        text: i18n("Add")
                                        onClicked: {
                                            addLauncher(model.url);
                                            appPickerDialog.close();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Loading indicator
                    Item {
                        visible: isLoadingApps && filteredAppsModel.count === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        BusyIndicator {
                            anchors.centerIn: parent
                            running: isLoadingApps
                        }
                    }
                }
            }
        ]

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Add applications to pin to the taskbar. Drag items to reorder them.")
            visible: true
        }

        ListView {
            id: pinnedAppsList
            Layout.fillWidth: true
            Layout.fillHeight: true

            model: pinnedAppsModel

            // Disable animations during drag
            interactive: !isDragging

            // Add scrollbar when needed
            ScrollBar.vertical: ScrollBar {}

            // Add drop area to handle autoscroll
            DropArea {
                id: dropArea
                anchors.fill: parent

                onEntered: {
                    if (isDragging) {
                        // Calculate new index based on drop position
                        var newIndex = Math.floor((drag.y + pinnedAppsList.contentY) / 48);
                        // Approximate item height
                        if (newIndex >= 0 && newIndex < pinnedAppsModel.count) {
                            dropItemIndex = newIndex;
                        }
                    }
                }

                onPositionChanged: {
                    if (isDragging) {
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
                            dropItemIndex = newIndex;
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
                width: ListView.view.width
                height: 48

                // Properties for drag operation
                property bool beingDragged: index === dragItemIndex

                Drag.active: mouseArea.drag.active
                Drag.source: pinnedAppDelegate
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                // Visual representation during drag
                states: [
                    State {
                        when: beingDragged
                        ParentChange {
                            target: pinnedAppDelegate
                            parent: pinnedAppsDialog
                        }
                        PropertyChanges {
                            target: pinnedAppDelegate
                            z: 100
                            opacity: 0.8
                        }
                    }
                ]

                Rectangle {
                    id: itemHighlight
                    anchors.fill: parent
                    color: dropItemIndex === index && isDragging ?
Kirigami.Theme.highlightColor : mouseArea.containsMouse ? Kirigami.Theme.highlightColor.lighter(0.7) : "transparent"
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
                        source: model.icon
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }

                    Label {
                        text: model.name
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Label {
                        text: model.url
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
                            let currentLaunchers = pinnedLaunchers;
                            currentLaunchers.splice(index, 1);
                            plasmoid.configuration.launchers = currentLaunchers;
                            pinnedLaunchers = currentLaunchers;
                            refreshPinnedAppsModel();
                        }
                        ToolTip.text: i18n("Remove")
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
                        dragItemIndex = index;
                        isDragging = true;
                    }

                    onReleased: {
                        // End dragging
                        isDragging = false;
                        if (dropItemIndex !== -1 && dragItemIndex !== -1 && dropItemIndex !== dragItemIndex) {
                            // Move the item
                            moveItem(dragItemIndex, dropItemIndex);
                        }

                        // Reset state
                        dragItemIndex = -1;
                        dropItemIndex = -1;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                id: addAppButton
                icon.name: "list-add"
                text: i18n("Add Application...")
                onClicked: appPickerDialog.open()
                Layout.fillWidth: true
            }

            Button {
                id: addSpecialButton
                icon.name: "preferences-desktop-default-applications"
                text: i18n("Add Special Launcher...")
                onClicked: specialLauncherMenu.popup()

                Menu {
                    id: specialLauncherMenu

                    MenuItem {
                        text: i18n("Default Web Browser")
                        icon.name: "internet-web-browser"
                        onTriggered: {
                            addLauncher("preferred://browser");
                        }
                    }

                    MenuItem {
                        text: i18n("Default File Manager")
                        icon.name: "system-file-manager"
                        onTriggered: {
                            addLauncher("preferred://filemanager");
                        }
                    }

                    MenuItem {
                        text: i18n("Default Mail Client")
                        icon.name: "internet-mail"
                        onTriggered: {
                            addLauncher("preferred://mail");
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
        plasmoid.configuration.launchers = currentLaunchers;
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
        plasmoid.configuration.launchers = currentLaunchers;
        pinnedLaunchers = currentLaunchers;
        // Refresh model to ensure view is updated
        refreshPinnedAppsModel();
    }
}
