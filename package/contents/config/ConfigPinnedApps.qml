/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

import "../ui/code/singletones"

ConfigPage {
    id: cfg_page
    fullTitle: Wrappers.i18n("Pinned Applications")

    property var pinnedLaunchers: cfg_page.cfg_launchers
    onPinnedLaunchersChanged: {
        refreshPinnedAppsModel();
    }
    property bool isLoadingApps: false
    property var appMetadataCache: ({})
    property string currentSearchText: ""

    // The "preferred://" launchers: whichever app is set in System Settings'
    // Default Applications. Plasma resolves only these four hosts itself.
    readonly property var specialLaunchers: [
        {url: "preferred://browser", name: Wrappers.i18n("Default Web Browser"), comment: Wrappers.i18n("Browse the Web"),
         icon: "internet-web-browser", keywords: "web browser internet"},
        {url: "preferred://mailer", name: Wrappers.i18n("Default Mail Client"), comment: Wrappers.i18n("Send and Receive Email"),
         icon: "internet-mail", keywords: "email mail"},
        {url: "preferred://filemanager", name: Wrappers.i18n("Default File Manager"), comment: Wrappers.i18n("Manage Files"),
         icon: "system-file-manager", keywords: "files folder"},
        {url: "preferred://terminal", name: Wrappers.i18n("Default Terminal"), comment: Wrappers.i18n("Run Commands"),
         icon: "utilities-terminal", keywords: "terminal console shell"}
    ]
    function specialLauncher(url: string): var {
        return specialLaunchers.find(launcher => launcher.url === url);
    }

    // The app each special launcher stands for now: {preferred url: {name, url}}.
    property var defaultApps: ({})

    // Resolves the special launchers the way the panel does, and again once
    // System Settings changes a default app (libtaskmanager re-reads them on
    // a KSycoca rebuild). Window rows are there too, and are skipped.
    TaskManager.TasksModel {
        id: defaultAppsModel
        launcherList: cfg_page.specialLaunchers.map(launcher => launcher.url)
        separateLaunchers: true
        hideActivatedLaunchers: false
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    Instantiator {
        id: defaultAppsResolver
        model: defaultAppsModel
        delegate: QtObject {
            required property var model
            readonly property bool isLauncher: model.IsLauncher === true
            readonly property string appUrl: isLauncher ? String(model.LauncherUrlWithoutIcon) : ""
            readonly property string appName: isLauncher ? (model.AppName || "") : ""
            onAppUrlChanged: defaultAppsTimer.restart()
            onAppNameChanged: defaultAppsTimer.restart()
        }
        onObjectAdded: defaultAppsTimer.restart()
        onObjectRemoved: defaultAppsTimer.restart()
    }
    Timer {
        id: defaultAppsTimer
        interval: 0
        onTriggered: cfg_page.updateDefaultApps()
    }
    function updateDefaultApps() {
        const apps = {};
        for (let i = 0; i < defaultAppsResolver.count; i++) {
            const row = defaultAppsResolver.objectAt(i);
            if (!row?.isLauncher)
                continue;
            const position = defaultAppsModel.launcherPosition(row.appUrl);
            const url = defaultAppsModel.launcherList[position];
            // Unresolved (no such app): the URL stays a preferred:// one.
            if (url && !row.appUrl.startsWith("preferred:"))
                apps[url] = {name: row.appName, url: row.appUrl};
        }
        defaultApps = apps;
        for (const list of [installedAppsModel, filteredAppsModel]) {
            for (let i = 0; i < list.count; i++) {
                const url = list.get(i).url;
                if (url.startsWith("preferred://")) {
                    list.setProperty(i, "genericName", getGenericNameForUrl(url));
                    list.setProperty(i, "icon", getIconForUrl(url));
                }
            }
        }
        refreshPinnedAppsModel();
    }

    // ---------------------------------------
    // Unified Style Configuration
    // ---------------------------------------
    QtObject {
        id: appListStyle
        property int iconSize: Kirigami.Units.iconSizes.smallMedium
        property int spacing: Kirigami.Units.smallSpacing
        property int padding: Kirigami.Units.smallSpacing
    }

    // ---------------------------------------

    // Launchers bound to activities are stored as "[activity ids]\nurl" (see
    // libtaskmanager's deserializeLauncher). The page shows and compares the
    // bare URL but must write the stored strings back unchanged.
    function cleanUrl(url) {
        if (url.startsWith("[")) {
            const blockEnd = url.indexOf("]\n");
            if (blockEnd !== -1)
                return url.substring(blockEnd + 2);
        }
        return url;
    }

    function isPinned(url) {
        return pinnedLaunchers.some(launcher => cleanUrl(launcher) === url);
    }

    ListModel {
        id: installedAppsModel
    }

    ListModel {
        id: filteredAppsModel
    }

    // Loads every installed app once, through the helper, into the app list
    // and the metadata the pinned list shows.
    function loadApps() {
        isLoadingApps = true;
        DesktopActionsManager.listApps(apps => {
            const cache = {};
            for (const app of apps)
                cache["applications:" + app.id] = {name: app.name, icon: app.icon, genericName: app.genericName, comment: app.comment};
            cfg_page.appMetadataCache = cache;
            const items = cfg_page.specialLaunchers.map(launcher => ({
                name: launcher.name,
                icon: cfg_page.getIconForUrl(launcher.url),
                url: launcher.url,
                keywords: launcher.keywords,
                genericName: cfg_page.getGenericNameForUrl(launcher.url),
                comment: launcher.comment,
                section: Wrappers.i18n("Default Applications")
            }));
            for (const app of apps) {
                const url = "applications:" + app.id;
                // Hidden apps are listed only if they're already pinned.
                if (!app.display && !cfg_page.isPinned(url))
                    continue;
                items.push({
                    name: app.name,
                    icon: app.icon,
                    url: url,
                    keywords: app.keywords.join(" "),
                    genericName: app.genericName,
                    comment: app.comment,
                    section: Wrappers.i18n("Applications")
                });
            }
            installedAppsModel.clear();
            installedAppsModel.append(items);
            cfg_page.isLoadingApps = false;
            cfg_page.refreshPinnedAppsModel();
            cfg_page.filterAppsModel(cfg_page.currentSearchText, true);
        });
    }

    function filterAppsModel(text, force) {
        const searchText = (text || "").toLowerCase();
        // Optimization for empty search with already filled model
        if (!force && searchText.length === 0 && filteredAppsModel.count > 0 && filteredAppsModel.count === Math.min(installedAppsModel.count, 50)) {
            return;
        }

        filteredAppsModel.clear();

        for (let i = 0; i < installedAppsModel.count; i++) {
            const app = installedAppsModel.get(i);
            
            // Skip if already pinned
            if (cfg_page.isPinned(app.url)) {
                continue;
            }

            // Apply search filter
            if (searchText && searchText.length > 0) {
                if (app.name.toLowerCase().includes(searchText) || 
                    app.url.toLowerCase().includes(searchText) || 
                    (app.keywords && app.keywords.toLowerCase().includes(searchText)) ||
                    (app.genericName && app.genericName.toLowerCase().includes(searchText)) ||
                    (app.comment && app.comment.toLowerCase().includes(searchText))) {
                    filteredAppsModel.append(app);
                }
            } else {
                filteredAppsModel.append(app);
                // Limit initial load for better performance
                if (filteredAppsModel.count >= 50) {
                    break;
                }
            }
        }
    }

    function loadMoreApps() {
        // Only lazy load if we are showing the full list (no search)
        if (cfg_page.currentSearchText.length > 0)
            return;

        if (filteredAppsModel.count < installedAppsModel.count) {
            const startIndex = filteredAppsModel.count;
            const endIndex = Math.min(startIndex + 50, installedAppsModel.count);

            for (let i = startIndex; i < endIndex; i++) {
                const app = installedAppsModel.get(i);
                // Skip if already pinned
                if (cfg_page.isPinned(app.url)) {
                    continue;
                }
                filteredAppsModel.append(app);
            }
        }
    }

    Component.onCompleted: {
        refreshPinnedAppsModel();
        loadApps();
    }

    function getGenericNameForUrl(url) {
        if (url.startsWith("preferred://")) {
            const app = defaultApps[url];
            return app ? Wrappers.i18nc("The app a default-app launcher opens now", "Now: %1", app.name) : "";
        }
        if (appMetadataCache[url]) {
            return appMetadataCache[url].genericName || "";
        }
        return "";
    }

    function refreshPinnedAppsModel(sourceList) {
        pinnedAppsModel.clear();
        let list = sourceList || pinnedLaunchers;
        for (let i = 0; i < list.length; i++) {
            let launcher = list[i];
            let url = cleanUrl(launcher);
            pinnedAppsModel.append({
                "name": getNameForUrl(url),
                "genericName": getGenericNameForUrl(url),
                "comment": getCommentForUrl(url),
                "icon": getIconForUrl(url),
                "url": url,
                "launcher": launcher
            });
        }
    }

    function getCommentForUrl(url) {
        if (url.startsWith("preferred://")) {
            return cfg_page.specialLauncher(url)?.comment ?? "";
        }

        if (appMetadataCache[url]) {
            return appMetadataCache[url].comment || appMetadataCache[url].genericName || "";
        }
        return "";
    }

    function getNameForUrl(url) {
        if (url.startsWith("preferred://")) {
            return cfg_page.specialLauncher(url)?.name ?? Wrappers.i18n("Default Application");
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
            // The current default app's icon, as on the panel.
            const app = defaultApps[url];
            return (app && appMetadataCache[app.url]?.icon)
                || (cfg_page.specialLauncher(url)?.icon ?? "preferences-desktop-default-applications");
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

                ConfigScrollView {
                    cfg_page: cfg_page
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: pinnedAppsList
                        model: pinnedAppsModel
                        
                        // Disable animations during drag
                        interactive: !cfg_page.isDragging

                    // Add drop area to handle autoscroll
                    DropArea {
                        id: dropArea
                        anchors.fill: parent

                        onEntered: (drag) => {
                            if (cfg_page.isDragging) {
                                updateDropIndex(drag.y);
                            }
                        }

                        onPositionChanged: (drag) => {
                            if (cfg_page.isDragging) {
                                let localY = drag.y;
                                if (localY < 50) {
                                    autoScrollTimer.direction = -1;
                                    autoScrollTimer.running = true;
                                } else if (localY > pinnedAppsList.height - 50) {
                                    autoScrollTimer.direction = 1;
                                    autoScrollTimer.running = true;
                                } else {
                                    autoScrollTimer.running = false;
                                }
                                updateDropIndex(localY);
                            }
                        }

                        onDropped: {
                            autoScrollTimer.running = false;
                        }

                        onExited: {
                            autoScrollTimer.running = false;
                        }

                        function updateDropIndex(localY) {
                            var absY = localY + pinnedAppsList.contentY;
                            var idx = pinnedAppsList.indexAt(0, absY);
                            if (idx === -1) {
                                cfg_page.dropItemIndex = pinnedAppsModel.count;
                                return;
                            }
                            var item = pinnedAppsList.itemAtIndex(idx);
                            if (item) {
                                let midY = item.y + item.height / 2;
                                cfg_page.dropItemIndex = absY < midY ? idx : idx + 1;
                            } else {
                                cfg_page.dropItemIndex = idx;
                            }
                        }
                    }

                    Timer {
                        id: autoScrollTimer
                        interval: 50
                        repeat: true
                        property int direction: 0
                        property int scrollStep: 10

                        onTriggered: {
                            pinnedAppsList.contentY = Math.max(0, Math.min(pinnedAppsList.contentY + direction * scrollStep, pinnedAppsList.contentHeight - pinnedAppsList.height));
                        }
                    }

                    delegate: PinnedAppCard {
                        pageRoot: cfg_page
                        cardStyle: appListStyle
                        pinnedModel: pinnedAppsModel
                    }
                }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    CheckBox {
                        id: unpinByDragCheck
                        text: Wrappers.i18n("Unpin app by dragging its icon off the panel")
                        checked: cfg_page.cfg_unpinByDrag
                        onToggled: cfg_page.cfg_unpinByDrag = checked
                    }

                    // Only with unpinning on; the animations are played in the
                    // icons-only mode.
                    RowLayout {
                        visible: unpinByDragCheck.checked && cfg_page.cfg_iconOnly === 1
                        Item { implicitWidth: Kirigami.Units.gridUnit }
                        Label {
                            text: Wrappers.i18n("Unpinning animation:")
                        }
                        AnimationCards {
                            dragOff: true
                            choices: [
                                { text: Wrappers.i18nc("No animation", "None"), effect: "" },
                                { text: Wrappers.i18nc("Animation", "Smoke"), effect: "smoke" },
                                { text: Wrappers.i18nc("Animation", "Shatter"), effect: "shatter" }
                            ]
                            currentIndex: cfg_page.cfg_unpinAnimation
                            onActivated: (index) => cfg_page.cfg_unpinAnimation = index
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
                            // Force refresh to ensure unpinned apps appear
                            cfg_page.filterAppsModel(cfg_page.currentSearchText, true);
                            
                            stackView.push(addAppsPage)
                        }
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    Component {
        id: addAppsPage
        Item {
            // Add apps page container
            focus: true // Ensure item can receive focus for keys
            
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

                        section.property: "section"
                        section.delegate: Kirigami.ListSectionHeader {
                            required property string section
                            width: ListView.view.width
                            text: section
                        }

                        onContentYChanged: {
                            if (contentY + height >= contentHeight - 100) {
                                cfg_page.loadMoreApps();
                            }
                        }

                        delegate: ItemDelegate {
                            id: appsDelegate
                            required property var model
                            required property int index
                            
                            width: ListView.view.width
                            topPadding: appListStyle.padding
                            bottomPadding: appListStyle.padding
                            leftPadding: appListStyle.padding
                            rightPadding: appListStyle.padding
                            
                            onClicked: {
                                cfg_page.addLauncher(appsDelegate.model.url);
                                // The page stays open; the app leaves the list right away.
                                filteredAppsModel.remove(index);
                            }

                            ToolTip.text: appsDelegate.model.comment || appsDelegate.model.name || ""
                            ToolTip.visible: appsDelegate.hovered && ToolTip.text !== ""
                            ToolTip.delay: 1000

                            contentItem: RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: appsDelegate.model.icon || "application-x-executable"
                                    Layout.preferredWidth: appListStyle.iconSize
                                    Layout.preferredHeight: appListStyle.iconSize
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 0

                                    Label {
                                        Layout.fillWidth: true
                                        text: appsDelegate.model.name || appsDelegate.model.url
                                        wrapMode: Text.Wrap
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
        if (isPinned(url)) {
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
            list.push(pinnedAppsModel.get(i).launcher);
        }
        
        cfg_page.cfg_launchers = list;
        // pinnedLaunchers binding should update automatically from cfg_launchers
    }


}
