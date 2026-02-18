/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasmoid

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras

import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.mpris as Mpris
// import org.kde.plasma.private.taskmanager as TaskManagerApplet

import "code/layoutmetrics.js" as LayoutMetrics
import "code/singletones"

PlasmaExtras.Menu {
    id: menu

    required property var backend
    required property Mpris.Mpris2Model mpris2Source
    required property /*QModelIndex*/var modelIndex
    required property TaskManager.TasksModel tasksModel
    required property TaskManager.VirtualDesktopInfo virtualDesktopInfo
    required property TaskManager.ActivityInfo activityInfo

    readonly property var atm: TaskManager.AbstractTasksModel

    property bool showAllPlaces: false

    placement: {
        if (Plasmoid.location === PlasmaCore.Types.LeftEdge) {
            return PlasmaExtras.Menu.RightPosedTopAlignedPopup;
        } else if (Plasmoid.location === PlasmaCore.Types.TopEdge) {
            return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
        } else if (Plasmoid.location === PlasmaCore.Types.RightEdge) {
            return PlasmaExtras.Menu.LeftPosedTopAlignedPopup;
        } else {
            return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
        }
    }


    readonly property Item visualParentItem: visualParent as Item
    minimumWidth: visualParentItem ? visualParentItem.width : 0

    onStatusChanged: {
        if (visualParent && get(atm.LauncherUrlWithoutIcon).toString() !== "" && status === PlasmaExtras.Menu.Open) {
            activitiesDesktopsMenuItem._activitiesDesktopsMenu.refresh();

        } else if (status === PlasmaExtras.Menu.Closed) {
            menu.destroy();
        }
    }

    Component.onCompleted: {
        // Cannot have "Connections" as child of PlasmaExtras.Menu.
        backend.showAllPlaces.connect(showContextMenuWithAllPlaces);
    }

    Component.onDestruction: {
        backend.showAllPlaces.disconnect(showContextMenuWithAllPlaces);
    }

    function showContextMenuWithAllPlaces(): void {
        const parentTask = visualParent as Task;
        parentTask.showContextMenu({showAllPlaces: true});
    }

    function get(modelProp: int): var {
        return menu.tasksModel.data(modelIndex, modelProp)
    }

    function show(): void {
        Plasmoid.contextualActionsAboutToShow();

        loadDynamicLaunchActions(get(atm.LauncherUrlWithoutIcon));
        openRelative();
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

    function loadDynamicLaunchActions(launcherUrl: url): void {
        const sections = [];

        const placesActions = menu.backend.placesActions(launcherUrl, menu.showAllPlaces, menu);

        if (placesActions.length > 0) {
            sections.push({
                title: Wrappers.i18n("Places"),
                group: "places",
                actions: placesActions
            });
        } else {
            sections.push({
                title:   Wrappers.i18n("Recent Files"),
                group:   "recents",
                actions: menu.backend.recentDocumentActions(launcherUrl, menu)
            });
        }

        sections.push({
            title: Wrappers.i18n("Actions"),
            group: "actions",
            actions: menu.backend.jumpListActions(launcherUrl, menu)
        });

        // C++ can override section heading by returning a QString as first action
        sections.forEach((section) => {
            if (typeof section.actions[0] === "string") {
                section.title = section.actions.shift(); // take first
            }
        });

        // QMenu does not limit its width automatically. Even if we set a maximumWidth
        // it would just cut off text rather than eliding. So we do this manually.
        const textMetrics = Qt.createQmlObject("import QtQuick; TextMetrics {}", menu);
        textMetrics.elide = Qt.ElideRight;
        textMetrics.elideWidth = LayoutMetrics.maximumContextMenuTextWidth();

        sections.forEach(section => {
            if (section["actions"].length > 0 || section["group"] === "actions") {
                // Don't add the "Actions" header if the menu has nothing but actions
                // in it, because then it's redundant (all menus have actions)
                if (
                    (section["group"] !== "actions") ||
                    (section["group"] === "actions" && (sections[0]["actions"].length > 0 || sections[1]["actions"].length > 0))
                ) {
                    var sectionHeader = newMenuItem(menu);
                    sectionHeader.text = section["title"];
                    sectionHeader.section = true;
                    menu.addMenuItem(sectionHeader, startNewInstanceItem);
                }
            }

            for (var i = 0; i < section["actions"].length; ++i) {
                var item = newMenuItem(menu);
                item["action"] = section["actions"][i];

                textMetrics.text = item["action"].text;
                item["action"].text = textMetrics.elidedText;

                menu.addMenuItem(item, startNewInstanceItem);
            }
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
        visible: menu.get(menu.atm.CanLaunchNewInstance)
        text: Wrappers.i18n("Open New Window")
        icon: "window-new"

        onClicked: menu.tasksModel.requestNewInstance(menu.modelIndex)
    }

    PlasmaExtras.MenuItem {
        id: virtualDesktopsMenuItem

        visible: menu.virtualDesktopInfo.numberOfDesktops > 1
            && (menu.visualParent && !menu.get(menu.atm.IsLauncher)
            && !menu.get(menu.atm.IsStartup)
            && menu.get(menu.atm.IsVirtualDesktopsChangeable))

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

        readonly property var _virtualDesktopsMenu: PlasmaExtras.Menu {
            id: virtualDesktopsMenu

            visualParent: virtualDesktopsMenuItem

            function refresh(): void {
                clearMenuItems();

                if (menu.virtualDesktopInfo.numberOfDesktops <= 1 || !virtualDesktopsMenuItem.enabled) {
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
                menu.backend.setActionGroup(menuItem["action"]);

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
                    menu.backend.setActionGroup(menuItem["action"]);
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

        visible: menu.activityInfo.numberOfRunningActivities > 1
            && (menu.visualParent && !menu.get(menu.atm.IsLauncher)
            && !menu.get(menu.atm.IsStartup))

        enabled: visible

        text: Wrappers.i18n("Show in &Activities")
        icon: "activities"

        readonly property Connections activityInfoConnections: Connections {
            target: menu.activityInfo

            function onNumberOfRunningActivitiesChanged(): void {
                activitiesDesktopsMenuItem._activitiesDesktopsMenu["refresh"]()
            }
        }

        readonly property var _activitiesDesktopsMenu: PlasmaExtras.Menu {
            id: activitiesDesktopsMenu

            visualParent: activitiesDesktopsMenuItem

            function refresh(): void {
                clearMenuItems();

                if (menu.activityInfo.numberOfRunningActivities <= 1) {
                    return;
                }

                let menuItem = menu.newMenuItem(activitiesDesktopsMenuItem._activitiesDesktopsMenu);
                menuItem.text = Wrappers.i18n("Add To Current Activity");
                menuItem.enabled = Qt.binding(() => {
                    return menu.visualParent && menu.get(atm.Activities).length > 0 &&
                           menu.get(atm.Activities).indexOf(menu.activityInfo.currentActivity) < 0;
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
                    menuItem.text = Wrappers.i18n("Move to %1", menu.activityInfo.activityName(activityId))
                    menuItem.icon = menu.activityInfo.activityIcon(activityId)
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

        visible: visualParent
            && !get(atm.IsLauncher)
            && !get(atm.IsStartup)
            && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            && (menu.activityInfo.numberOfRunningActivities < 2)
            && !doesBelongToCurrentActivity()

        enabled: visualParent && get(atm.LauncherUrlWithoutIcon).toString() !== ""

        text: Wrappers.i18n("&Pin to Task Manager")
        icon: "window-pin"

        function doesBelongToCurrentActivity(): bool {
            return menu.tasksModel.launcherActivities(get(atm.LauncherUrlWithoutIcon))
                .some(activity => activity === menu.activityInfo.currentActivity || activity === menu.activityInfo.nullUuid);
        }

        onClicked: {
            menu.tasksModel.requestAddLauncher(get(atm.LauncherUrl));
        }
    }

    PlasmaExtras.MenuItem {
        id: showLauncherInActivitiesItem

        text: Wrappers.i18n("&Pin to Task Manager")
        icon: "window-pin"

        visible: visualParent
            && !get(atm.IsStartup)
            && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            && (menu.activityInfo.numberOfRunningActivities >= 2)

        readonly property Connections activitiesLaunchersMenuConnections: Connections {
            target: menu.activityInfo

            function onNumberOfRunningActivitiesChanged(): void {
                showLauncherInActivitiesItem._activitiesLaunchersMenu["refresh"]()
            }
        }

        readonly property var _activitiesLaunchersMenu: PlasmaExtras.Menu {
            id: activitiesLaunchersMenu
            visualParent: showLauncherInActivitiesItem

            function refresh(): void {
                clearMenuItems();

                if (menu.visualParent === null) return;

                const createNewItem = (id, title, iconName, url, activities) => {
                    var result = menu.newMenuItem(showLauncherInActivitiesItem._activitiesLaunchersMenu);
                    result.text = title;
                    result.icon = iconName;

                    result.visible = true;
                    result.checkable = true;

                    result.checked = activities.some(activity => activity === id);

                    result.clicked.connect(() => {
                        if (result.checked) {
                            menu.tasksModel.requestAddLauncherToActivity(url, id);
                        } else {
                            menu.tasksModel.requestRemoveLauncherFromActivity(url, id);
                        }
                    });

                    return result;
                };

                if (menu.visualParent === null) return;

                const url = menu.get(atm.LauncherUrlWithoutIcon);

                const activities = menu.tasksModel.launcherActivities(url);

                createNewItem(menu.activityInfo.nullUuid, Wrappers.i18n("On All Activities"), "", url, activities);

                if (menu.activityInfo.numberOfRunningActivities <= 1) {
                    return;
                }

                createNewItem(menu.activityInfo.currentActivity, Wrappers.i18n("On The Current Activity"), menu.activityInfo.activityIcon(menu.activityInfo.currentActivity), url, activities);

                menu.newSeparator(showLauncherInActivitiesItem._activitiesLaunchersMenu);

                menu.activityInfo.runningActivities()
                    .forEach(id => {
                        createNewItem(id, menu.activityInfo.activityName(id), menu.activityInfo.activityIcon(id), url, activities);
                    });
            }

            Component.onCompleted: {
                menu.visualParentChanged.connect(refresh);
                refresh();
            }
        }
    }

    PlasmaExtras.MenuItem {
        visible: (visualParent
                && get(atm.IsStartup) !== true
                && Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
                && !launcherToggleAction.visible
                && menu.activityInfo.numberOfRunningActivities < 2)

        text: Wrappers.i18n("Unpin from Task Manager")
        icon: "window-unpin"

        onClicked: {
            menu.tasksModel.requestRemoveLauncher(get(atm.LauncherUrlWithoutIcon));
        }
    }

    PlasmaExtras.MenuItem {
        id: moreActionsMenuItem

        visible: (visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

        enabled: visible

        text: Wrappers.i18n("More")
        icon: "view-more-symbolic"

        readonly property PlasmaExtras.Menu moreMenu: PlasmaExtras.Menu {
            visualParent: { var i = moreActionsMenuItem; return i["action"] }

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

                onClicked: menu.tasksModel.requestToggleMaximized(modelIndex)
            }

            PlasmaExtras.MenuItem {
                visible: (menu.visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

                enabled: menu.visualParent && get(atm.IsMinimizable)

                checkable: true
                checked: menu.visualParent && get(atm.IsMinimized)

                text: Wrappers.i18n("Mi&nimize")
                icon: "window-minimize"

                onClicked: menu.tasksModel.requestToggleMinimized(modelIndex)
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

                checkable: true
                checked: menu.visualParent && menu.get(atm.IsShaded)

                text: Wrappers.i18n("&Shade")
                icon: "window-shade"

                onClicked: menu.tasksModel.requestToggleShaded(menu.modelIndex)
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

    PlasmaExtras.MenuItem { separator: true }

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

    PlasmaExtras.MenuItem { separator: true }

    PlasmaExtras.MenuItem {
        id: closeWindowItem
        visible: (visualParent && !get(atm.IsLauncher) && !get(atm.IsStartup))

        enabled: visualParent && get(atm.IsClosable)

        text: get(atm.IsGroupParent) ? Wrappers.i18nc("@item:inmenu", "&Close All") : Wrappers.i18n("&Close")
        icon: "window-close"

        onClicked: {
            if (tasks.groupDialog !== null && tasks.groupDialog.visualParent === visualParent) {
                tasks.groupDialog.visible = false;
            }

            menu.tasksModel.requestClose(modelIndex);
        }
    }
}
