/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2023-2024 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2024 Jin Liu <m.liu.jin@gmail.com>
    SPDX-FileCopyrightText: 2024 Xaver Hugl <xaver.hugl@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2023 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2023 Niccolò Venerandi <niccolo@venerandi.com>
    SPDX-FileCopyrightText: 2023 Nicolas Fella <nicolas.fella@gmx.de>
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras

import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.mpris as Mpris
// import org.kde.plasma.private.taskmanager as TaskManagerApplet

import "code/singletones"

PlasmaExtras.Menu {
    id: menu

    required property Mpris.Mpris2Model mpris2Source
    required property /*QModelIndex*/ var modelIndex
    required property TaskManager.TasksModel tasksModel
    required property TaskManager.VirtualDesktopInfo virtualDesktopInfo
    required property TaskManager.ActivityInfo activityInfo
    required property var tasksRoot

    readonly property var atm: TaskManager.AbstractTasksModel

    property bool showAllPlaces: false

    placement: {
        if (tasksRoot.effectiveLocation === PlasmaCore.Types.LeftEdge) {
            return PlasmaExtras.Menu.RightPosedTopAlignedPopup;
        } else if (tasksRoot.effectiveLocation === PlasmaCore.Types.TopEdge) {
            return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
        } else if (tasksRoot.effectiveLocation === PlasmaCore.Types.RightEdge) {
            return PlasmaExtras.Menu.LeftPosedTopAlignedPopup;
        } else {
            return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
        }
    }

    readonly property Item visualParentItem: visualParent as Item
    minimumWidth: visualParentItem ? visualParentItem.width : 0

    onStatusChanged: {
        if (status === PlasmaExtras.Menu.Open) {
            if (activitiesDesktopsMenuItem.visible) {
                activitiesDesktopsMenuItem._activitiesDesktopsMenu.refresh();
            }
            if (virtualDesktopsMenuItem.visible) {
                virtualDesktopsMenuItem._virtualDesktopsMenu.refresh();
            }
        } else if (status === PlasmaExtras.Menu.Closed) {
            menu.destroy();
        }
    }

    Component.onCompleted: {}

    Component.onDestruction: {}

    function showContextMenuWithAllPlaces(): void {
        const parentTask = visualParent as Task;
        parentTask.showContextMenu({
            showAllPlaces: true
        });
    }

    function get(modelProp: int): var {
        return menu.tasksModel.data(modelIndex, modelProp);
    }

    function show(): void {
        Plasmoid.contextualActionsAboutToShow();

        loadDynamicLaunchActions(get(atm.LauncherUrlWithoutIcon), () => {
            openRelative();
        });
    }

    function newMenuItem(parent: QtObject): var {
        return Qt.createQmlObject(`
            import org.kde.plasma.extras as PlasmaExtras

            PlasmaExtras.MenuItem {}
        `, parent);
    }

    function newSeparator(parent: QtObject): var {
        return Qt.createQmlObject(`
            import org.kde.plasma.extras as PlasmaExtras

            PlasmaExtras.MenuItem { separator: true }
            `, parent);
    }

    property var _dynamicDesktopItems: []

    function _insertDesktopActions(result, launcherUrl) {
        // Find where to insert (before startNewInstanceItem)
        let insertItem = startNewInstanceItem;

        // Clean up any previously added dynamic items to avoid duplicates on re-open
        _dynamicDesktopItems.forEach(item => {
            if (item)
                item.destroy();
        });
        _dynamicDesktopItems = [];

        // Manually elide text since QMenu does not limit its width automatically
        const textMetrics = Qt.createQmlObject("import QtQuick; TextMetrics {}", menu);
        textMetrics.elide = Qt.ElideRight;
        textMetrics.elideWidth = Kirigami.Units.iconSizes.sizeForLabels * 28;

        function elideText(text) {
            if (!text)
                return "";
            textMetrics.text = text.replace(/&/g, "&&");
            return textMetrics.elidedText;
        }

        function setIcon(item, iconPath) {
            if (!iconPath)
                return;
            if (String(iconPath).startsWith("file://")) {
                item.icon = iconPath.replace(/^file:\/\//, "");
            } else {
                item.icon = iconPath;
            }
        }

        // 1. Add Jump List Actions (Desktop Actions)
        if (result.jumpList && result.jumpList.length > 0) {
            result.jumpList.forEach(action => {
                let menuItem = menu.newMenuItem(menu);
                menuItem.text = action.name;
                setIcon(menuItem, action.icon);
                menuItem.clicked.connect(() => {
                    let cleanExec = action.exec.replace(/%[uUfF]/g, "").trim();
                    DesktopActionsManager.executeCommand(cleanExec);
                });
                menu.addMenuItem(menuItem, insertItem);
                _dynamicDesktopItems.push(menuItem);
            });

            let sep2 = menu.newSeparator(menu);
            menu.addMenuItem(sep2, insertItem);
            _dynamicDesktopItems.push(sep2);
        }

        // 1.5 Add Places Submenu (for Dolphin / File Managers)
        if (result.places && result.places.length > 0) {
            let placesSubItem = Qt.createQmlObject('import "."; PlacesSubMenu {}', menu);
            placesSubItem.text = Wrappers.i18n("Places");
            let placesSubMenu = placesSubItem.subMenu;

            result.places.forEach(place => {
                let menuItem = menu.newMenuItem(placesSubMenu);
                menuItem.text = elideText(place.name);
                setIcon(menuItem, place.icon);
                menuItem.clicked.connect(() => {
                    DesktopActionsManager.openUrl(place.url, launcherUrl);
                });
                placesSubMenu.addMenuItem(menuItem);
            });

            menu.addMenuItem(placesSubItem, insertItem);
            _dynamicDesktopItems.push(placesSubItem);

            let sep3 = menu.newSeparator(menu);
            menu.addMenuItem(sep3, insertItem);
            _dynamicDesktopItems.push(sep3);
        }

        // 1.7 Add Browser History (for Firefox/Browsers)
        if (result.browserHistory && result.browserHistory.length > 0) {
            let title = menu.newMenuItem(menu);
            title.text = Wrappers.i18n("Recent Pages");
            title.section = true;
            menu.addMenuItem(title, insertItem);
            _dynamicDesktopItems.push(title);

            result.browserHistory.forEach(item => {
                let menuItem = menu.newMenuItem(menu);
                menuItem.text = elideText(item.name);
                setIcon(menuItem, item.icon);
                menuItem.clicked.connect(() => {
                    DesktopActionsManager.openUrl(item.url, launcherUrl);
                });
                menu.addMenuItem(menuItem, insertItem);
                _dynamicDesktopItems.push(menuItem);
            });

            let sep4 = menu.newSeparator(menu);
            menu.addMenuItem(sep4, insertItem);
            _dynamicDesktopItems.push(sep4);
        }

        // 2. Add Recent Folders
        if (result.recentFolders && result.recentFolders.length > 0) {
            let title = menu.newMenuItem(menu);
            title.text = Wrappers.i18n("Recent Folders");
            title.section = true;
            menu.addMenuItem(title, insertItem);
            _dynamicDesktopItems.push(title);

            result.recentFolders.forEach(folder => {
                let menuItem = menu.newMenuItem(menu);
                menuItem.text = elideText(folder.name);
                setIcon(menuItem, folder.icon);
                menuItem.clicked.connect(() => {
                    DesktopActionsManager.openUrl(folder.url, launcherUrl);
                });
                menu.addMenuItem(menuItem, insertItem);
                _dynamicDesktopItems.push(menuItem);
            });
        }

        // 3. Add Recent Documents
        if (result.recentDocs && result.recentDocs.length > 0) {
            // First, add the section header using the native Plasma menu item
            let title = menu.newMenuItem(menu);
            title.text = Wrappers.i18n("Recent Documents");
            title.section = true;
            menu.addMenuItem(title, insertItem);
            _dynamicDesktopItems.push(title);

            // Add the files
            result.recentDocs.forEach(doc => {
                let menuItem = menu.newMenuItem(menu);

                // Format name visually for virtual paths using plaintext
                if (doc.url.startsWith("trash:/")) {
                    menuItem.text = elideText(Wrappers.i18n("Trash"));
                    setIcon(menuItem, "user-trash-full");
                } else if (doc.url.startsWith("zip://") || doc.url.startsWith("tar://") || doc.url.startsWith("krarc://")) {
                    // Extract archive name safely without regex
                    let protoIdx = doc.url.indexOf("://");
                    let pathWithoutProto = protoIdx !== -1 ? doc.url.substring(protoIdx + 3) : doc.url;

                    let insidePath = "";
                    let archiveName = doc.name;

                    let match = pathWithoutProto.match(/([^\/]+\.(?:zip|tar|gz|xz|bz2|rar|7z))(?:\/|$)(.*)/i);
                    if (match) {
                        archiveName = match[1];
                        insidePath = match[2];
                        if (insidePath) {
                            menuItem.text = elideText("[" + archiveName + "] /" + insidePath);
                        } else {
                            menuItem.text = elideText(archiveName);
                        }
                    } else {
                        menuItem.text = elideText(doc.name.startsWith("zip://") ? pathWithoutProto : doc.name);
                    }
                    setIcon(menuItem, "application-x-archive");
                } else {
                    menuItem.text = elideText(doc.name);
                    setIcon(menuItem, doc.icon);
                }

                menuItem.clicked.connect(() => {
                    DesktopActionsManager.openUrl(doc.url, launcherUrl);
                });
                menu.addMenuItem(menuItem, insertItem);
                _dynamicDesktopItems.push(menuItem);
            });
        }

        // 4. Add "Clear recent" button if we added folders OR documents
        if ((result.recentDocs && result.recentDocs.length > 0) || (result.recentFolders && result.recentFolders.length > 0)) {
            let clearItem = menu.newMenuItem(menu);
            clearItem.text = Wrappers.i18n("Forget Recent Files");
            setIcon(clearItem, "edit-clear-history");
            clearItem.clicked.connect(() => {
                DesktopActionsManager.clearRecentDocuments(launcherUrl);
            });
            menu.addMenuItem(clearItem, insertItem);
            _dynamicDesktopItems.push(clearItem);

            // Separator after recent documents
            let sep = menu.newSeparator(menu);
            menu.addMenuItem(sep, insertItem);
            _dynamicDesktopItems.push(sep);
        }
    }

    function loadDynamicLaunchActions(launcherUrl: url, onReady: var): void {
        // Query desktop file actions and recent documents
        const showHistory = get(atm.AppPid) > 0 && Plasmoid.configuration.showBrowserHistory;
        DesktopActionsManager.query(launcherUrl, get(atm.AppPid), showHistory, Plasmoid.configuration.browserHistoryLimit, result => {
            _insertDesktopActions(result, launcherUrl);
            if (onReady)
                onReady();
        });

        // Add Media Player control actions
        const playerData = menu.mpris2Source.playerForLauncherUrl(launcherUrl, menu.get(menu.atm.AppPid));

        if (playerData && playerData.canControl && !(menu.get(menu.atm.WinIdList) !== undefined && menu.get(menu.atm.WinIdList).length > 1)) {
            const playing = playerData.playbackStatus === Mpris.PlaybackStatus.Playing;
            let menuItem = menu.newMenuItem(menu);
            menuItem.text = Wrappers.i18nc("Play previous track", "Previous Track");
            menuItem.icon = "media-skip-backward";
            menuItem.enabled = Qt.binding(() => {
                return playerData.canGoPrevious;
            });
            menuItem.clicked.connect(() => {
                playerData.Previous();
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            menuItem = menu.newMenuItem(menu);
            // PlasmaCore Menu doesn't actually handle icons or labels changing at runtime...
            menuItem.text = Qt.binding(() => {
                // if CanPause, toggle the menu entry between Play & Pause, otherwise always use Play
                return playing && playerData.canPause ? Wrappers.i18nc("Pause playback", "Pause") : Wrappers.i18nc("Start playback", "Play");
            });
            menuItem.icon = Qt.binding(() => {
                return playing && playerData.canPause ? "media-playback-pause" : "media-playback-start";
            });
            menuItem.enabled = Qt.binding(() => {
                return playing ? playerData.canPause : playerData.canPlay;
            });
            menuItem.clicked.connect(() => {
                if (playing) {
                    playerData.Pause();
                } else {
                    playerData.Play();
                }
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            menuItem = menu.newMenuItem(menu);
            menuItem.text = Wrappers.i18nc("Play next track", "Next Track");
            menuItem.icon = "media-skip-forward";
            menuItem.enabled = Qt.binding(() => {
                return playerData.canGoNext;
            });
            menuItem.clicked.connect(() => {
                playerData.Next();
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            menuItem = menu.newMenuItem(menu);
            menuItem.text = Wrappers.i18nc("Stop playback", "Stop");
            menuItem.icon = "media-playback-stop";
            menuItem.enabled = Qt.binding(() => {
                return playerData.canStop;
            });
            menuItem.clicked.connect(() => {
                playerData.Stop();
            });
            menu.addMenuItem(menuItem, startNewInstanceItem);

            // Technically media controls and audio streams are separate but for the user they're
            // semantically related, don't add a separator inbetween.
            if (!(menu.visualParent as Task).hasAudioStream) {
                menu.addMenuItem(newSeparator(menu), startNewInstanceItem);
            }

            // If we don't have a window associated with the player but we can quit
            // it through MPRIS we'll offer a "Quit" option instead of "Close"
            if (!closeWindowItem.visible && playerData.canQuit) {
                menuItem = menu.newMenuItem(menu);
                menuItem.text = Wrappers.i18nc("Quit media player app", "Quit");
                menuItem.icon = "application-exit";
                menuItem.visible = Qt.binding(() => {
                    return !closeWindowItem.visible;
                });
                menuItem.clicked.connect(() => {
                    playerData.Quit();
                });
                menu.addMenuItem(menuItem);
            }

            // If we don't have a window associated with the player but we can raise
            // it through MPRIS we'll offer a "Restore" option
            if (get(atm.IsLauncher) && !startNewInstanceItem.visible && playerData.canRaise) {
                menuItem = menu.newMenuItem(menu);
                menuItem.text = Wrappers.i18nc("Open or bring to the front window of media player app", "Restore");
                menuItem.icon = playerData.iconName;
                menuItem.visible = Qt.binding(() => {
                    return !startNewInstanceItem.visible;
                });
                menuItem.clicked.connect(() => {
                    playerData.Raise();
                });
                menu.addMenuItem(menuItem, startNewInstanceItem);
            }
        }

        // We allow mute/unmute whenever an application has a stream, regardless of whether it
        // is actually playing sound.
        // This way you can unmute, e.g. a telephony app, even after the conversation has ended,
        // so you still have it ringing later on.
        if ((menu.visualParent as Task).hasAudioStream) {
            const muteItem = menu.newMenuItem(menu);
            muteItem.checkable = true;
            muteItem.checked = Qt.binding(() => {
                return menu.visualParent && (menu.visualParent as Task).muted;
            });
            muteItem.clicked.connect(() => {
                (menu.visualParent as Task).toggleMuted();
            });
            muteItem.text = Wrappers.i18n("Mute");
            muteItem.icon = "audio-volume-muted";
            menu.addMenuItem(muteItem, startNewInstanceItem);

            menu.addMenuItem(newSeparator(menu), startNewInstanceItem);
        }
    }

    PlasmaExtras.MenuItem {
        id: startNewInstanceItem
        visible: menu.get(menu.atm.CanLaunchNewInstance) || menu.get(menu.atm.IsLauncher)
        text: menu.get(menu.atm.IsLauncher) ? Wrappers.i18n("Launch") : Wrappers.i18n("Open New Window")
        icon: menu.get(menu.atm.IsLauncher) ? "system-run" : "window-new"

        onClicked: {
            const parentTask = menu.visualParent;
            if (parentTask && typeof parentTask.triggerLaunch === "function") {
                parentTask.triggerLaunch();
            }
            menu.tasksModel.requestNewInstance(menu.modelIndex);
        }
    }

    PlasmaExtras.MenuItem {
        id: virtualDesktopsMenuItem

        visible: (menu.virtualDesktopInfo.numberOfDesktops > 1 || !Plasmoid.configuration.hideMoveToDesktopMenuWithOneDesktop) && (menu.visualParent && !menu.get(menu.atm.IsLauncher) && !menu.get(menu.atm.IsStartup) && menu.get(menu.atm.IsVirtualDesktopsChangeable))

        enabled: visible

        text: Wrappers.i18n("Move to &Desktop")
        icon: "virtual-desktops"

        readonly property Connections virtualDesktopsMenuConnections: Connections {
            target: menu.virtualDesktopInfo

            function onNumberOfDesktopsChanged(): void {
                Qt.callLater(virtualDesktopsMenuItem._virtualDesktopsMenu["refresh"]);
            }
            function onDesktopIdsChanged(): void {
                Qt.callLater(virtualDesktopsMenuItem._virtualDesktopsMenu["refresh"]);
            }
            function onDesktopNamesChanged(): void {
                Qt.callLater(virtualDesktopsMenuItem._virtualDesktopsMenu["refresh"]);
            }
        }

        readonly property PlasmaExtras.Menu _virtualDesktopsMenu: PlasmaExtras.Menu {
            id: virtualDesktopsMenu

            visualParent: virtualDesktopsMenuItem.action

            function refresh(): void {
                clearMenuItems();

                if (!virtualDesktopsMenuItem.enabled) {
                    return;
                }

                let menuItem = menu.newMenuItem(virtualDesktopsMenuItem._virtualDesktopsMenu);
                menuItem.text = Wrappers.i18n("Move &To Current Desktop");
                menuItem.enabled = Qt.binding(() => {
                    return menu.visualParent && menu.get(menu.atm.VirtualDesktops).indexOf(menu.virtualDesktopInfo.currentDesktop) === -1;
                });
                menuItem.clicked.connect(() => {
                    menu.tasksModel.requestVirtualDesktops(menu.modelIndex, [menu.virtualDesktopInfo.currentDesktop]);
                });

                menuItem = menu.newMenuItem(virtualDesktopsMenuItem._virtualDesktopsMenu);
                menuItem.text = Wrappers.i18n("&All Desktops");
                menuItem.checkable = true;
                menuItem.checked = Qt.binding(() => {
                    return menu.visualParent && menu.get(menu.atm.IsOnAllVirtualDesktops);
                });
                menuItem.clicked.connect(() => {
                    menu.tasksModel.requestVirtualDesktops(menu.modelIndex, []);
                });

                menu.newSeparator(virtualDesktopsMenuItem._virtualDesktopsMenu);

                for (let i = 0; i < menu.virtualDesktopInfo.desktopNames.length; ++i) {
                    menuItem = menu.newMenuItem(virtualDesktopsMenuItem._virtualDesktopsMenu);
                    menuItem.text = menu.virtualDesktopInfo.desktopNames[i];
                    menuItem.checkable = true;
                    menuItem.checked = Qt.binding((i => {
                            return () => menu.visualParent && menu.get(menu.atm.VirtualDesktops).indexOf(menu.virtualDesktopInfo.desktopIds[i]) > -1;
                        })(i));
                    menuItem.clicked.connect((i => {
                            return () => menu.tasksModel.requestVirtualDesktops(menu.modelIndex, [menu.virtualDesktopInfo.desktopIds[i]]);
                        })(i));
                }

                menu.newSeparator(virtualDesktopsMenuItem._virtualDesktopsMenu);

                menuItem = menu.newMenuItem(virtualDesktopsMenuItem._virtualDesktopsMenu);
                menuItem.text = Wrappers.i18n("&New Desktop");
                menuItem.icon = "list-add";
                menuItem.clicked.connect(() => {
                    menu.tasksModel.requestNewVirtualDesktop(menu.modelIndex);
                });
            }

            Component.onCompleted: refresh()
        }
    }

    PlasmaExtras.MenuItem {
        id: activitiesDesktopsMenuItem

        visible: menu.activityInfo.numberOfRunningActivities > 1 && (menu.visualParent && !menu.get(menu.atm.IsLauncher) && !menu.get(menu.atm.IsStartup))

        enabled: visible

        text: Wrappers.i18n("Show in &Activities")
        icon: "activities"

        readonly property Connections activityInfoConnections: Connections {
            target: menu.activityInfo

            function onNumberOfRunningActivitiesChanged(): void {
                activitiesDesktopsMenuItem._activitiesDesktopsMenu["refresh"]();
            }
        }

        readonly property PlasmaExtras.Menu _activitiesDesktopsMenu: PlasmaExtras.Menu {
            id: activitiesDesktopsMenu

            visualParent: activitiesDesktopsMenuItem.action

            function refresh(): void {
                clearMenuItems();

                if (menu.activityInfo.numberOfRunningActivities <= 1) {
                    return;
                }

                let menuItem = menu.newMenuItem(activitiesDesktopsMenuItem._activitiesDesktopsMenu);
                menuItem.text = Wrappers.i18n("Add To Current Activity");
                menuItem.enabled = Qt.binding(() => {
                    return menu.visualParent && menu.get(atm.Activities).length > 0 && menu.get(atm.Activities).indexOf(menu.activityInfo.currentActivity) < 0;
                });
                menuItem.clicked.connect(() => {
                    menu.tasksModel.requestActivities(menu.modelIndex, menu.get(atm.Activities).concat(menu.activityInfo.currentActivity));
                });

                menuItem = menu.newMenuItem(activitiesDesktopsMenuItem._activitiesDesktopsMenu);
                menuItem.text = Wrappers.i18n("All Activities");
                menuItem.checkable = true;
                menuItem.checked = Qt.binding(() => {
                    return menu.visualParent && menu.get(atm.Activities).length === 0;
                });
                menuItem.toggled.connect(checked => {
                    let newActivities = []; // will cast to an empty QStringList i.e all activities
                    if (!checked) {
                        newActivities = [menu.activityInfo.currentActivity];
                    }
                    menu.tasksModel.requestActivities(menu.modelIndex, newActivities);
                });

                menu.newSeparator(activitiesDesktopsMenuItem._activitiesDesktopsMenu);

                const runningActivities = menu.activityInfo.runningActivities();
                for (let i = 0; i < runningActivities.length; ++i) {
                    const activityId = runningActivities[i];

                    menuItem = menu.newMenuItem(activitiesDesktopsMenuItem._activitiesDesktopsMenu);
                    menuItem.text = menu.activityInfo.activityName(runningActivities[i]);
                    menuItem.icon = menu.activityInfo.activityIcon(runningActivities[i]);
                    menuItem.checkable = true;
                    menuItem.checked = Qt.binding((activityId => {
                            return () => menu.visualParent && menu.get(atm.Activities).indexOf(activityId) >= 0;
                        })(activityId));
                    menuItem.toggled.connect((activityId => {
                            return checked => {
                                let newActivities = menu.get(atm.Activities);
                                if (checked) {
                                    newActivities = newActivities.concat(activityId);
                                } else {
                                    const index = newActivities.indexOf(activityId);
                                    if (index < 0) {
                                        return;
                                    }

                                    newActivities.splice(index, 1);
                                }
                                return menu.tasksModel.requestActivities(menu.modelIndex, newActivities);
                            };
                        })(activityId));
                }

                menu.newSeparator(activitiesDesktopsMenuItem._activitiesDesktopsMenu);

                for (let i = 0; i < runningActivities.length; ++i) {
                    const activityId = runningActivities[i];
                    const onActivities = menu.get(atm.Activities);

                    // if the task is on a single activity, don't insert a "move to" item for that activity
                    if (onActivities.length === 1 && onActivities[0] === activityId) {
                        continue;
                    }

                    menuItem = menu.newMenuItem(activitiesDesktopsMenuItem._activitiesDesktopsMenu);
                    menuItem.text = Wrappers.i18n("Move to %1", menu.activityInfo.activityName(activityId));
                    menuItem.icon = menu.activityInfo.activityIcon(activityId);
                    menuItem.clicked.connect((activityId => {
                            return () => menu.tasksModel.requestActivities(menu.modelIndex, [activityId]);
                        })(activityId));
                }

                menu.newSeparator(activitiesDesktopsMenuItem._activitiesDesktopsMenu);
            }

            Component.onCompleted: refresh()
        }
    }

    PlasmaExtras.MenuItem {
        id: launcherToggleAction

        visible: visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup) && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable && !isPinned()

        enabled: visualParent && get(atm.LauncherUrlWithoutIcon).toString() !== ""

        text: Wrappers.i18n("&Pin to Task Manager")
        icon: "window-pin"

        function isPinned(): bool {
            var url = get(atm.LauncherUrlWithoutIcon).toString();
            return Plasmoid.configuration.launchers.indexOf(url) !== -1;
        }

        onClicked: {
            var launchers = Plasmoid.configuration.launchers.slice();
            var url = get(atm.LauncherUrlWithoutIcon).toString();
            if (launchers.indexOf(url) === -1) {
                launchers.push(url);
                Plasmoid.configuration.launchers = launchers;
            }
        }
    }

    PlasmaExtras.MenuItem {
        visible: visualParent && get(atm.IsStartup) !== true && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable && (get(atm.IsLauncher) || launcherToggleAction.isPinned())

        text: Wrappers.i18n("Unpin from Task Manager")
        icon: "window-unpin"

        onClicked: {
            var launchers = Plasmoid.configuration.launchers.slice();
            var url = get(atm.LauncherUrlWithoutIcon).toString();
            var index = launchers.indexOf(url);
            if (index !== -1) {
                launchers.splice(index, 1);
                Plasmoid.configuration.launchers = launchers;
            }
        }
    }

    PlasmaExtras.MenuItem {
        id: moreActionsMenuItem

        visible: (visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

        enabled: visible

        text: Wrappers.i18n("More")
        icon: "view-more-symbolic"

        readonly property PlasmaExtras.Menu moreMenu: PlasmaExtras.Menu {
            visualParent: moreActionsMenuItem.action

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(atm.IsMovable)

                text: Wrappers.i18n("&Move")
                icon: "transform-move"

                onClicked: menu.tasksModel.requestMove(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(atm.IsResizable)

                text: Wrappers.i18n("Re&size")
                icon: "transform-scale"

                onClicked: menu.tasksModel.requestResize(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                visible: (menu.visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

                enabled: menu.visualParent && get(atm.IsMaximizable)

                checkable: true
                checked: menu.visualParent && get(atm.IsMaximized)

                text: Wrappers.i18n("Ma&ximize")
                icon: "window-maximize"

                onClicked: menu.tasksModel.requestToggleMaximized(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                visible: (menu.visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

                enabled: menu.visualParent && get(atm.IsMinimizable)

                checkable: true
                checked: menu.visualParent && get(atm.IsMinimized)

                text: Wrappers.i18n("Mi&nimize")
                icon: "window-minimize"

                onClicked: menu.tasksModel.requestToggleMinimized(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.visualParent && menu.get(atm.IsKeepAbove)

                text: Wrappers.i18n("Keep &Above Others")
                icon: "window-keep-above"

                onClicked: menu.tasksModel.requestToggleKeepAbove(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                checkable: true
                checked: menu.visualParent && menu.get(atm.IsKeepBelow)

                text: Wrappers.i18n("Keep &Below Others")
                icon: "window-keep-below"

                onClicked: menu.tasksModel.requestToggleKeepBelow(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(atm.IsFullScreenable)

                checkable: true
                checked: menu.visualParent && menu.get(atm.IsFullScreen)

                text: Wrappers.i18n("&Fullscreen")
                icon: "view-fullscreen"

                onClicked: menu.tasksModel.requestToggleFullScreen(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(atm.IsShadeable)
                visible: Qt.platform.pluginName !== "wayland"

                checkable: true
                checked: menu.visualParent && menu.get(atm.IsShaded)

                text: Wrappers.i18n("&Shade")
                icon: "window-shade"

                onClicked: menu.tasksModel.requestToggleShaded(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent && menu.get(atm.CanSetNoBoder)

                checkable: true
                checked: menu.visualParent && menu.get(atm.HasNoBorder)

                text: Wrappers.i18n("&No Titlebar and Frame")
                icon: "edit-none-border"

                onClicked: menu.tasksModel.requestToggleNoBorder(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                enabled: menu.visualParent

                checkable: true
                checked: menu.visualParent && menu.get(atm.IsExcludedFromCapture)
                visible: Qt.platform.pluginName === "wayland"

                text: Wrappers.i18n("&Hide from Screencast")
                icon: "view-private"

                onClicked: menu.tasksModel.requestToggleExcludeFromCapture(menu.modelIndex)
            }

            PlasmaExtras.MenuItem {
                separator: true
            }

            PlasmaExtras.MenuItem {
                visible: (Plasmoid.configuration.groupingStrategy !== 0) && menu.get(atm.IsWindow)

                checkable: true
                checked: menu.visualParent && menu.get(atm.IsGroupable)

                text: Wrappers.i18n("Allow this program to be grouped")
                icon: "view-group"

                onClicked: menu.tasksModel.requestToggleGrouping(menu.modelIndex)
            }
        }
    }

    PlasmaExtras.MenuItem {
        separator: true
    }

    PlasmaExtras.MenuItem {
        property QtObject configureAction: null

        enabled: configureAction && configureAction.enabled
        visible: configureAction && configureAction.visible

        text: configureAction ? configureAction.text : ""
        icon: configureAction ? configureAction.icon : ""

        onClicked: configureAction.trigger()

        Component.onCompleted: configureAction = Plasmoid.internalAction("configure")
    }

    PlasmaExtras.MenuItem {
        property QtObject editModeAction: null

        enabled: editModeAction && editModeAction.enabled
        visible: editModeAction && editModeAction.visible

        text: editModeAction ? editModeAction.text : ""
        icon: editModeAction ? editModeAction.icon : ""

        onClicked: editModeAction.trigger()

        Component.onCompleted: editModeAction = Plasmoid.containment.internalAction("configure")
    }

    PlasmaExtras.MenuItem {
        separator: true
    }

    PlasmaExtras.MenuItem {
        id: closeWindowItem
        visible: (visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

        enabled: visualParent && get(atm.IsClosable)

        text: get(atm.IsGroupParent) ? Wrappers.i18nc("@item:inmenu", "&Close All") : Wrappers.i18n("&Close")
        icon: "window-close"

        onClicked: {
            menu.tasksModel.requestClose(menu.modelIndex);
        }
    }
}
