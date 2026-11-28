/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2025 SushiTrash <namanrajhans@gmail.com>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Fushan Wen <qydwhotmail@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Marco Martin <notmart@gmail.com>
    SPDX-FileCopyrightText: 2023-2024 Nate Graham <nate@kde.org>
    SPDX-FileCopyrightText: 2023-2024 Niccolò Venerandi <niccolo@venerandi.com>
    SPDX-FileCopyrightText: 2024 David Edmundson <kde@davidedmundson.co.uk>
    SPDX-FileCopyrightText: 2024 David Redondo <kde@david-redondo.de>
    SPDX-FileCopyrightText: 2024 Ismael Asensio <isma.af@gmail.com>
    SPDX-FileCopyrightText: 2024 ivan tkachenko <me@ratijas.tk>
    SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
    SPDX-FileCopyrightText: 2023 Bharadwaj Raju <bharadwaj.raju777@protonmail.com>
    SPDX-FileCopyrightText: 2023 Nicolas Fella <nicolas.fella@gmx.de>
    SPDX-FileCopyrightText: 2023 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2023 Taro Tanaka <mkrmdk@gmail.com>
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami

import org.kde.plasma.workspace.trianglemousefilter

import org.kde.taskmanager as TaskManager
import QtCore as QtCore
import org.kde.plasma.workspace.dbus as DBus
import org.kde.kitemmodels as KItemModels
import org.kde.iconthemes as KIconThemes

import "code/layoutmetrics.js" as LayoutMetrics
import "code/tools.js" as TaskTools
import "code/FloatingLogic.js" as FloatingLogic
import "code/singletones"

PlasmoidItem {
    id: tasks

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    readonly property var config: Plasmoid.configuration
    readonly property int location: Plasmoid.location
    // The tooltip window's transparent band on the panel side, for its
    // shadow, and how far its visible frame stays from the panel, or from a
    // hover-zoomed icon sticking out of it (Task.tooltipAnchor).
    readonly property int tooltipShadowBand: 8
    readonly property int tooltipDistance: 2
    // The Meta+N numbers shown without Meta held (settings previews only).
    readonly property bool forceTaskNumbers: false
    // Keyboard hints: the widget's own shortcut shows a key on every task
    // button; that key switches to the task.
    property bool hintMode: false
    // The keys, by their place on the keyboard, so a hint works in any
    // layout: the label is the US letter, the match is the scan code (XKB
    // keycode: evdev code + 8, on X11 and Wayland alike).
    readonly property var hintKeys: [
        ["1", 10], ["2", 11], ["3", 12], ["4", 13], ["5", 14], ["6", 15], ["7", 16], ["8", 17], ["9", 18], ["0", 19],
        ["A", 38], ["S", 39], ["D", 40], ["F", 41], ["G", 42], ["H", 43], ["J", 44], ["K", 45], ["L", 46],
        ["Q", 24], ["W", 25], ["E", 26], ["R", 27], ["T", 28], ["Y", 29], ["U", 30], ["I", 31], ["O", 32], ["P", 33],
        ["Z", 52], ["X", 53], ["C", 54], ["V", 55], ["B", 56], ["N", 57], ["M", 58]
    ]
    function hintLabel(index: int): string {
        return index >= 0 && index < hintKeys.length ? hintKeys[index][0] : "";
    }
    // Shift held, for the task menu's Force Quit (ShiftKeyState.qml).
    readonly property bool shiftHeld: _shiftKeyState ? _shiftKeyState.pressed === true : false
    // A var: KeyState isn't an Item, and its type is in a private module.
    readonly property var _shiftKeyState: shiftKeyState.item
    Loader {
        id: shiftKeyState
        source: Qt.resolvedUrl("ShiftKeyState.qml")
    }
    readonly property var containment: Plasmoid.containment

    rotation: tasks.config.reverseMode && tasks.vertical ? 180 : 0

    // Prevent shrinking to zero during startup before the tasks model is fully initialized.
    // Otherwise, in Wayland with "Fit Content" panel, the panel shrinks to zero size
    // and becomes invisible until edit mode is entered.
    readonly property bool shouldShrinkToZero: !tasks._initialStartup && !!tasks.effectiveTasksModel && tasks.effectiveTasksModel.count === 0
    readonly property int effectiveLocation: FloatingLogic.getEffectiveLocation(tasks.location, tasks.config, PlasmaCore.Types)

    readonly property bool vertical: {
        if (effectiveLocation === PlasmaCore.Types.LeftEdge || effectiveLocation === PlasmaCore.Types.RightEdge) {
            return true;
        }
        if (effectiveLocation === PlasmaCore.Types.TopEdge || effectiveLocation === PlasmaCore.Types.BottomEdge) {
            return false;
        }
        return Plasmoid.formFactor === PlasmaCore.Types.Vertical;
    }
    readonly property bool iconsOnly: tasks.config.iconOnly === 1

    property alias globalVolumeOverlay: globalVolumeOverlayLoader
    property Item dropIndicator: dropIndicatorRect
    property int dropIndex: -1
    property Item dragSource: null
    // Whether a drag is over this widget, tracked by MouseHandler's DropArea:
    // a launcher dropped anywhere else is unpinned when unpinByDrag is on.
    property bool dragOverApplet: false

    property bool _isApplyingConfig: false
    property bool _initialStartup: true
    property bool _taskOrderRestored: false

    // TasksModel fills in asynchronously at startup (on Wayland the windows
    // arrive after the shell is up) and has no "ready" signal. The saved
    // order is restored as soon as every task in it is back
    // (checkStartupTasks()), or after this timeout when some never come back,
    // e.g. apps that weren't reopened after a login.
    Timer {
        id: startupTimer
        interval: 1500
        repeat: false
        onTriggered: tasks.finishStartup()
    }

    function checkStartupTasks(): void {
        if (!tasks._taskOrderRestored && tasks.savedTasksPresent())
            tasks.finishStartup();
    }

    function finishStartup(): void {
        if (tasks._taskOrderRestored)
            return;
        tasks._taskOrderRestored = true;
        startupTimer.stop();
        if (tasks.config.sortingStrategy <= 1) {
            tasks.restoreTaskOrder();
            // Writes the restored order of pinned apps to the launcher list.
            tasks.tasksModel.syncLaunchers();
        }
        // Deferred: restoreTaskOrder()'s move() calls pass through several
        // chained proxy models, so their rowsMoved signals aren't
        // guaranteed to arrive in this same tick. Qt.callLater() only
        // runs once those are drained, so the Connections guard below
        // stays active until they have.
        Qt.callLater(() => { tasks._initialStartup = false; });
    }

    // Snapshot of the visible task order, restored after a plasmashell
    // restart. TasksModel's own manual-sort logic has no memory of the
    // previous live arrangement (e.g. a dragged-away pinned button) - it
    // only rebuilds sort order from scratch. Saved on every real order
    // change, applied once the model has settled at startup. One category
    // per applet: the settings file is shared by the whole plasmashell, and
    // several instances (e.g. one per panel) would overwrite each other.
    QtCore.Settings {
        id: taskOrderSettings
        category: "TaskOrder-" + Plasmoid.id
        property string savedOrder: "[]"
    }

    Timer {
        id: taskOrderSaveTimer
        interval: 500
        repeat: false
        onTriggered: tasks.snapshotTaskOrder()
    }

    Connections {
        target: tasks.tasksModel
        // Ignored during the startup settling window: row churn while the
        // model is still populating isn't a real change, and saving it would
        // overwrite the snapshot restoreTaskOrder() is about to read.
        function onRowsInserted() {
            if (!tasks._initialStartup)
                taskOrderSaveTimer.restart();
            else
                // Not from inside the model's signal: restoring moves rows.
                Qt.callLater(tasks.checkStartupTasks);
        }
        function onRowsRemoved() { if (!tasks._initialStartup) taskOrderSaveTimer.restart(); }
        function onRowsMoved() { if (!tasks._initialStartup) taskOrderSaveTimer.restart(); }
    }

    // Stable across a plasmashell restart, unlike WinIdList (only meaningful
    // within the same process on Wayland). Can't disambiguate multiple
    // windows of the same app - restoreTaskOrder() matches those in order as
    // a best-effort fallback.
    function taskOrderIdentifierAt(index) {
        const idx = tasks.tasksModel.index(index, 0);
        const isLauncher = tasks.tasksModel.data(idx, TaskManager.AbstractTasksModel.IsLauncher);
        const winIds = tasks.tasksModel.data(idx, TaskManager.AbstractTasksModel.WinIdList);
        if (isLauncher && (!winIds || winIds.length === 0)) {
            return "L:" + tasks.tasksModel.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
        }
        return "A:" + tasks.tasksModel.data(idx, TaskManager.AbstractTasksModel.AppId);
    }

    function snapshotTaskOrder() {
        if (!tasks.tasksModel)
            return;
        const order = [];
        for (let i = 0; i < tasks.tasksModel.count; i++) {
            order.push(tasks.taskOrderIdentifierAt(i));
        }
        taskOrderSettings.savedOrder = JSON.stringify(order);
    }

    // Whether every task in the saved order is in the model, counting
    // several windows of one app separately. False with no saved order:
    // then startup waits for the timeout, so an empty model doesn't shrink
    // the panel before the windows arrive (see shouldShrinkToZero).
    function savedTasksPresent(): bool {
        let savedOrder;
        try {
            savedOrder = JSON.parse(taskOrderSettings.savedOrder);
        } catch (e) {
            return false;
        }
        if (!Array.isArray(savedOrder) || savedOrder.length === 0)
            return false;

        const missing = {};
        for (const id of savedOrder)
            missing[id] = (missing[id] ?? 0) + 1;
        for (let i = 0; i < tasks.tasksModel.count; i++) {
            const id = tasks.taskOrderIdentifierAt(i);
            if (missing[id])
                missing[id]--;
        }
        return Object.values(missing).every(n => n === 0);
    }

    function restoreTaskOrder() {
        if (!tasks.tasksModel)
            return;

        let savedOrder;
        try {
            savedOrder = JSON.parse(taskOrderSettings.savedOrder);
        } catch (e) {
            return;
        }
        if (!Array.isArray(savedOrder) || savedOrder.length === 0)
            return;

        // Mirrors the model's order locally, updated after each move() so
        // later lookups search post-move positions.
        const current = [];
        for (let i = 0; i < tasks.tasksModel.count; i++) {
            current.push(tasks.taskOrderIdentifierAt(i));
        }

        for (let target = 0; target < savedOrder.length && target < current.length; target++) {
            const from = current.indexOf(savedOrder[target], target);
            if (from === -1 || from === target)
                continue;
            tasks.tasksModel.move(from, target);
            current.splice(target, 0, current.splice(from, 1)[0]);
        }
    }

    Connections {
        target: tasks.config
        // Turned on later, the shortcuts may still have to be registered.
        function onTaskEntryShortcutsChanged() {
            TaskEntryShortcuts.refresh();
        }
        function onShowOnlyCurrentDesktopChanged() {
            modelUpdateTimer.restart();
            tasks.filteredTasksModel.invalidateFilter();
        }
        function onShowOnlyCurrentScreenChanged() {
            modelUpdateTimer.restart();
            tasks.filteredTasksModel.invalidateFilter();
        }
        function onShowOnlyCurrentActivityChanged() {
            modelUpdateTimer.restart();
            tasks.filteredTasksModel.invalidateFilter();
        }
        function onReverseFiltersChanged() {
            modelUpdateTimer.restart();
            tasks.filteredTasksModel.invalidateFilter();
        }

        function onSortingStrategyChanged() {
            modelUpdateTimer.restart();
        }
        function onGroupingStrategyChanged() {
            modelUpdateTimer.restart();
        }

        function onMinimizedFilterChanged() {
            tasks.filteredTasksModel.invalidateFilter();
        }

        function onLaunchersChanged(): void {
            if (tasks.tasksModel && !tasks._isInternalLauncherUpdate) {
                tasks.applyLauncherList(tasks.config.launchers);
                tasks.tasksModel.syncLaunchers();
            }
        }
    }

    // Applies a launcher list changed outside the model (the Pinned
    // Applications page, an imported config). Handing it straight to
    // launcherList makes LauncherTasksModel remove and re-insert every
    // launcher whenever the set of URLs changes, and in manual sorting the
    // re-inserted launchers land after every launcher-backed window, which
    // piles the running apps up at the start. Adding and removing only what
    // changed goes through the incremental path that pinning from the context
    // menu uses; the final assignment then only reorders and sets activities.
    function applyLauncherList(launchers: var): void {
        const urlOf = launcher => {
            const s = String(launcher);
            const nl = s.indexOf("\n");
            return (s.startsWith("[") && nl !== -1) ? s.substring(nl + 1) : s;
        };
        const current = tasks.tasksModel.launcherList.map(urlOf);
        const wanted = Array.from(launchers).map(urlOf);

        tasks._isApplyingConfig = true;
        try {
            current.filter(url => !wanted.includes(url))
                   .forEach(url => tasks.tasksModel.requestRemoveLauncher(url));
            wanted.filter(url => !current.includes(url))
                  .forEach(url => tasks.tasksModel.requestAddLauncher(url));
        } finally {
            tasks._isApplyingConfig = false;
        }
        tasks.tasksModel.launcherList = launchers;
    }

    // The task whose tooltip is shown, and whether a click opened it (it
    // then stays until clicked again or dismissed, in text mode for groups).
    property Task currentHoveredTask: null
    property Task toolTipOpenedByClick: null
    property Task instantHoveredTask: null
    property int instantHoveredIndex: instantHoveredTask ? instantHoveredTask.index : -1
    property real instantHoveredFraction: 0.5
    property bool isTooltipHovered: false
    // An open context menu of a tooltip thumbnail and the task whose tooltip
    // it came from. The tooltip stays up while it's open; hovering another
    // task moves the tooltip away from it, so the menu closes too.
    property var thumbnailMenu: null
    property Task thumbnailMenuTask: null
    readonly property bool thumbnailMenuOpen: thumbnailMenu !== null

    // PERSIST PARENT FOR FADE-OUT ANIMATION
    property Item lastTooltipParent: null

    property bool tooltipAnimationEnabled: true

    // Icon replacements: key -> icon (TaskTools.iconReplacementKey()).
    readonly property var iconReplacements: TaskTools.parseIconReplacements(tasks.config.iconReplacements)
    function iconReplacementFor(model: var): string {
        const key = TaskTools.iconReplacementKey(model);
        return key && tasks.iconReplacements[key] ? String(tasks.iconReplacements[key]) : "";
    }

    // Sets (or, with no icon, removes) an app's icon replacement.
    function setIconReplacement(key: string, icon: string): void {
        if (!key)
            return;
        const map = Object.assign({}, tasks.iconReplacements);
        if (icon)
            map[key] = icon;
        else
            delete map[key];
        Plasmoid.configuration.iconReplacements = Object.keys(map).length > 0 ? JSON.stringify(map) : "";
    }
    // "Change Icon…": KDE's icon dialog; a picked file is copied into the
    // widget's data folder first.
    function changeIconOf(key: string): void {
        iconReplacementDialog.key = key;
        iconReplacementDialog.open();
    }
    KIconThemes.IconDialog {
        id: iconReplacementDialog
        property string key
        onAccepted: {
            const key = iconReplacementDialog.key;
            const name = iconReplacementDialog.iconName;
            if (!name)
                return;
            if (name.startsWith("/"))
                DesktopActionsManager.storeIcon(name, url => tasks.setIconReplacement(key, url || "file://" + name));
            else
                tasks.setIconReplacement(key, name);
        }
    }

    // The cursor over the widget, in its coordinates: for the hover
    // highlight of stylized icons (IconStylizer).
    readonly property bool pointerInside: rootHoverHandler.hovered
    readonly property point pointerPosition: rootHoverHandler.point.position

    function showTooltip(task: Task, byClick: bool): void {
        tasks.currentHoveredTask = task;
        tasks.toolTipOpenedByClick = byClick ? task : null;
    }

    // Hides the tooltip at once, without the fade (which would keep it
    // around, and taking input, after something in it was acted on), and
    // drops the window highlight it may have started.
    function dismissTooltip(): void {
        tasks.tooltipAnimationEnabled = false;
        tasks.currentHoveredTask = null;
        tasks.cancelHighlightWindows();
        Qt.callLater(() => {
            if (tasks) {
                tasks.tooltipAnimationEnabled = true;
            }
        });
    }

    // Key: WinId, Value: { result: ItemGrabResult, stamp: ms }
    // Capped at THUMBNAIL_CACHE_MAX entries; entries older than THUMBNAIL_CACHE_TTL_MS are treated as stale.
    property var thumbnailCache: ({})
    readonly property int thumbnailCacheMax: 48
    readonly property int thumbnailCacheTtlMs: 120000

    function cacheThumbnail(winId, result) {
        const now = Date.now();
        // Build a fresh object rather than mutating in place: reassigning the
        // property (not just its contents) is what makes the change propagate
        // through the tasks.thumbnailCache -> toolTipDelegate.thumbnailCache
        // binding chain, since QML skips a changed signal when the rebound
        // value is reference-equal to the previous one.
        const next = {};
        let count = 0;
        let oldestKey = null, oldestStamp = Infinity;
        for (const k of Object.keys(thumbnailCache)) {
            const entry = thumbnailCache[k];
            if (now - entry.stamp > thumbnailCacheTtlMs) continue; // evict stale
            next[k] = entry;
            count++;
            if (entry.stamp < oldestStamp) {
                oldestStamp = entry.stamp;
                oldestKey = k;
            }
        }
        if (count >= thumbnailCacheMax && oldestKey !== null) {
            delete next[oldestKey]; // enforce cap by dropping the oldest survivor
        }
        next[winId] = { result: result, stamp: now };
        thumbnailCache = next;
    }

    onCurrentHoveredTaskChanged: {
        if (toolTipOpenedByClick && toolTipOpenedByClick !== currentHoveredTask) {
            toolTipOpenedByClick = null;
        }
        if (currentHoveredTask) {
            lastTooltipParent = currentHoveredTask.tooltipAnchor;
        }
        if (thumbnailMenu && currentHoveredTask !== thumbnailMenuTask) {
            thumbnailMenu.close();
        }
    }

    // The one place a hovered tooltip closes: once neither its task nor the
    // tooltip (nor a thumbnail's menu) has the cursor. The interval is the
    // time to cross the gap between them.
    Timer {
        id: tooltipCloseTimer
        interval: 250
        running: !tasks.isTooltipHovered && !tasks.thumbnailMenuOpen && tasks.currentHoveredTask !== null && !tasks.currentHoveredTask.containsMouse && tasks.currentHoveredTask !== mouseHandler.hoveredItem
        onTriggered: {
            if (!tasks.isTooltipHovered && !tasks.thumbnailMenuOpen && (tasks.currentHoveredTask && !tasks.currentHoveredTask.containsMouse && tasks.currentHoveredTask !== mouseHandler.hoveredItem)) {
                tasks.currentHoveredTask = null;
            }
        }
    }

    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")


    property alias taskList: taskListView
    property alias effectWatcher: windowViewEffectWatcher
    property alias mediaRegistry: mediaRegistry
    property alias dragHelper: dragHelper
    property alias taskFrame: taskFrame
    property alias filteredTasksModel: internalFilteredTasksModel
    property alias busyIndicator: busyIndicator
    property alias virtualDesktopInfo: virtualDesktopInfo
    property alias mouseHandler: mouseHandler
    FancyTasksExplosion {
        id: explosionManager
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: Wrappers.i18n("System Monitor")
            icon.name: "office-chart-line-symbolic"
            visible: tasks.config.systemMonitorMenuItem && systemMonitor.installed
            onTriggered: systemMonitor.open()
        }
    ]
    InstalledApp {
        id: systemMonitor
        desktopId: "org.kde.plasma-systemmonitor.desktop"
    }
    // The menu editor, for "Edit Application…" in a task's menu.
    InstalledApp {
        id: menuEditor
        desktopId: "org.kde.kmenuedit.desktop"
    }
    readonly property bool canEditApps: menuEditor.installed

    Layout.fillWidth: vertical ? true : tasks.config.fill
    Layout.fillHeight: !vertical ? true : tasks.config.fill
    Layout.minimumWidth: {
        if (shouldShrinkToZero)
            return Kirigami.Units.gridUnit;
        return vertical ? 0 : LayoutMetrics.preferredMinWidth(tasks);
    }
    Layout.minimumHeight: {
        if (shouldShrinkToZero)
            return Kirigami.Units.gridUnit;
        return !vertical ? 0 : LayoutMetrics.preferredMinHeight(tasks);
    }
    Layout.preferredWidth: {
        if (shouldShrinkToZero)
            return 0.01;
        if (tasks.location === PlasmaCore.Types.Floating)
            return -1; // Let Plasma manage and persist manual resizes
        if (vertical)
            return Kirigami.Units.gridUnit * (iconsOnly ? 2.5 : 10);
        return taskListView.Layout.maximumWidth;
    }
    Layout.preferredHeight: {
        if (shouldShrinkToZero)
            return 0.01;
        if (tasks.location === PlasmaCore.Types.Floating)
            return -1; // Let Plasma manage and persist manual resizes
        if (vertical)
            return taskListView.Layout.maximumHeight;
        return Kirigami.Units.gridUnit * 2;
    }

    signal requestLayout
    signal windowsHovered(var winIds, bool hovered)
    function activateWindowView(winIds) {
        if (!windowViewEffectWatcher.registered)
            return;
        cancelHighlightWindows();
        return DBus.SessionBus.asyncCall({
            service: "org.kde.KWin.Effect.WindowView1",
            path: "/org/kde/KWin/Effect/WindowView1",
            iface: "org.kde.KWin.Effect.WindowView1",
            member: "activate",
            arguments: [winIds.map(s => String(s))],
            signature: "(as)"
        });
    }

    onWindowsHovered: (winIds, hovered) => {
        if (!tasks.config.highlightWindows || !tasks.config.enableToolTips)
            return;
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin.HighlightWindow",
            path: "/org/kde/KWin/HighlightWindow",
            iface: "org.kde.KWin.HighlightWindow",
            member: "highlightWindows",
            arguments: [hovered ? winIds : []],
            signature: "(as)"
        });
    }

    function cancelHighlightWindows(): DBus.DBusPendingReply {
        return DBus.SessionBus.asyncCall({
            service: "org.kde.KWin.HighlightWindow",
            path: "/org/kde/KWin/HighlightWindow",
            iface: "org.kde.KWin.HighlightWindow",
            member: "highlightWindows",
            arguments: [[]],
            signature: "(as)"
        });
    }

    onDragSourceChanged: {
        if (tasks.dragSource === null && tasks.tasksModel)
            tasks.tasksModel.syncLaunchers();
    }

    property bool _isInternalLauncherUpdate: false
    property bool _isPublishingGeometries: false

    function publishIconGeometries(taskItems: var): void {
        if (_isPublishingGeometries)
            return;
        if (TaskTools.taskManagerInstanceCount >= 2)
            return;

        _isPublishingGeometries = true;
        try {
            for (let i = 0; i < taskItems.length; ++i) {
                const task = taskItems[i];
                if (task.getGlobalRect && task.model && !task.model.IsLauncher && !task.model.IsStartup && tasks.tasksModel) {
                    const idx = task.modelIndex();
                    if (idx && idx.valid) {
                        tasks.tasksModel.requestPublishDelegateGeometry(idx, task.getGlobalRect(), task);
                    }
                }
            }
        } finally {
            _isPublishingGeometries = false;
        }
    }

    readonly property TaskManager.TasksModel tasksModel: internalTasksModel
    TaskManager.TasksModel {
        id: internalTasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: tasks.containment.screenGeometry
        activity: activityInfo.currentActivity

        onLauncherListChanged: {
            if (!tasks._isApplyingConfig) {
                tasks._isInternalLauncherUpdate = true;
                tasks.config.launchers = launcherList;
                // Defer reset to ensure the config change signal has finished propagating
                Qt.callLater(() => {
                    if (tasks)
                        tasks._isInternalLauncherUpdate = false;
                });
            }
        }
        onGroupingAppIdBlacklistChanged: {
            if (!tasks._isApplyingConfig) {
                tasks.config.groupingAppIdBlacklist = groupingAppIdBlacklist;
            }
        }
        onGroupingLauncherUrlBlacklistChanged: {
            if (!tasks._isApplyingConfig) {
                tasks.config.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
            }
        }

        Component.onCompleted: {
            // Runs before launcherList below: setting launcherList inserts
            // launcher rows through the same incremental path a running
            // window uses, which only queues a row for launcher-position
            // matching if separateLaunchers is already at its final value.
            tasks.applyModelConfiguration();
            launcherList = tasks.config.launchers;
            groupingAppIdBlacklist = tasks.config.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = tasks.config.groupingLauncherUrlBlacklist;
            startupTimer.start();
            // The launchers alone may be the whole saved order.
            Qt.callLater(tasks.checkStartupTasks);
        }
    }

    KItemModels.KSortFilterProxyModel {
        id: internalFilteredTasksModel
        sourceModel: internalTasksModel
        filterRowCallback: (source_row, source_parent) => {
            const idx = internalTasksModel.index(source_row, 0, source_parent);

            // Minimized Filter
            const isMinimized = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.IsMinimized) === true;
            if (tasks.config.minimizedFilter === 1) { // Only Minimized
                if (!isMinimized)
                    return false;
            } else if (tasks.config.minimizedFilter === 2) { // Only Not Minimized
                if (isMinimized)
                    return false;
            }

            // A launch from another instance's pin, unless this instance pins the
            // same app: the model swaps that pin out for the startup, so hiding
            // the startup would make the pin vanish too.
            if (tasks.isForeignStartup(internalTasksModel.data(idx, TaskManager.AbstractTasksModel.IsStartup) === true,
                                       internalTasksModel.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon),
                                       internalTasksModel.data(idx, TaskManager.AbstractTasksModel.AppId) || "")
                && internalTasksModel.launcherPosition(internalTasksModel.data(idx, TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon)) === -1) {
                return false;
            }

            // Reverse Filters (hide instead of show)
            if (tasks.config.reverseFilters) {
                // Screen Filter: hide tasks on the current screen
                if (tasks.config.showOnlyCurrentScreen) {
                    const taskScreen = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.ScreenGeometry);
                    const currentScreen = tasks.tasksModel.screenGeometry;
                    if (taskScreen && taskScreen.x === currentScreen.x && taskScreen.y === currentScreen.y && taskScreen.width === currentScreen.width && taskScreen.height === currentScreen.height) {
                        return false;
                    }
                }

                // Desktop Filter: hide tasks on the current virtual desktop
                if (tasks.config.showOnlyCurrentDesktop) {
                    const isOnAllDesktops = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops) === true;
                    const demandsAttention = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.IsDemandingAttention) === true;
                    if (!isOnAllDesktops && !demandsAttention) {
                        const virtualDesktops = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.VirtualDesktops);
                        const currentDesktop = tasks.tasksModel.virtualDesktop;
                        if (Array.isArray(virtualDesktops) && virtualDesktops.indexOf(currentDesktop) !== -1) {
                            return false;
                        }
                    }
                }

                // Activity Filter: hide tasks on the current activity
                if (tasks.config.showOnlyCurrentActivity) {
                    const demandsAttention = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.IsDemandingAttention) === true;
                    if (!demandsAttention) {
                        const activities = internalTasksModel.data(idx, TaskManager.AbstractTasksModel.Activities);
                        const currentActivity = tasks.tasksModel.activity;
                        if (Array.isArray(activities) && activities.length > 0) {
                            const isOnAllActivities = activities.indexOf("00000000-0000-0000-0000-000000000000") !== -1;
                            if (!isOnAllActivities && activities.indexOf(currentActivity) !== -1) {
                                return false;
                            }
                        }
                    }
                }
            }

            return true;
        }
    }

    // The screen filter also goes through the proxy, which hides startup
    // feedback for launches made from another instance's panel.
    readonly property var effectiveTasksModel: (tasks.config.minimizedFilter === 0 && !tasks.config.reverseFilters && !tasks.config.showOnlyCurrentScreen) ? internalTasksModel : internalFilteredTasksModel

    // Read by TaskEntryShortcuts to choose the instance a Meta+number press
    // goes to: like the stock task manager, it prefers the one showing the
    // active window, and one that shows every screen over one that shows only
    // its own.
    readonly property bool hasActiveTask: {
        const activeTask = tasks.tasksModel.activeTask;
        if (tasks.effectiveTasksModel.count === 0 || !activeTask.valid)
            return false;
        return tasks.effectiveTasksModel === internalTasksModel || internalFilteredTasksModel.mapFromSource(activeTask).valid;
    }
    readonly property bool showsOnlyCurrentScreen: tasks.config.showOnlyCurrentScreen && !tasks.config.reverseFilters

    // Startup tasks carry no screen, so with "show only tasks from the current
    // screen" every instance would show the busy feedback of a launch made from
    // another instance's panel. True for a startup some other instance launched.
    function isForeignStartup(isStartup: bool, launcherUrl: var, appId: string): bool {
        if (!isStartup || !tasks.config.showOnlyCurrentScreen || tasks.config.reverseFilters)
            return false;
        const owner = TaskTools.launchClaimOwner(launcherUrl, appId);
        return owner !== null && owner !== Plasmoid.id;
    }

    Timer {
        id: modelUpdateTimer
        interval: 100
        repeat: false
        onTriggered: tasks.applyModelConfiguration()
    }

    function applyModelConfiguration() {
        if (!tasks.tasksModel)
            return;

        tasks._isApplyingConfig = true;

        tasks.tasksModel.filterByVirtualDesktop = tasks.config.showOnlyCurrentDesktop && !tasks.config.reverseFilters;
        tasks.tasksModel.filterByScreen = tasks.config.showOnlyCurrentScreen && !tasks.config.reverseFilters;
        tasks.tasksModel.filterByActivity = tasks.config.showOnlyCurrentActivity && !tasks.config.reverseFilters;
        // The minimized filter is done by filteredTasksModel instead, which
        // also avoids crashes in TasksModel's own one.
        tasks.tasksModel.filterNotMinimized = false;

        // Must be set before sortMode: setting sortMode to SortManual can
        // synchronously trigger TasksModel's internal bulk re-sort (if its
        // sort map is still empty), which reads whatever launchInPlace/
        // separateLaunchers currently are - stale values there silently
        // break launcher-position matching for any pre-existing row.
        const launchInPlace = (tasks.config.sortingStrategy === 1 || tasks.config.sortingStrategy === 0);
        const separateLaunchers = (tasks.config.sortingStrategy !== 1);
        tasks.tasksModel.launchInPlace = launchInPlace;
        tasks.tasksModel.separateLaunchers = separateLaunchers;
        tasks.tasksModel.hideActivatedLaunchers = tasks.iconsOnly || launchInPlace;
        tasks.tasksModel.sortMode = tasks.sortModeEnumValue(tasks.config.sortingStrategy);

        tasks.tasksModel.groupMode = tasks.groupModeEnumValue(tasks.config.groupingStrategy);
        tasks.tasksModel.groupInline = !tasks.config.groupPopups;

        internalFilteredTasksModel.invalidateFilter();

        tasks._isApplyingConfig = false;
    }

    function sortModeEnumValue(index) {
        switch (Number(index)) {
        // "Do not sort" runs on SortManual too. Under SortDisabled, TasksModel
        // orders launchers by their row in TaskGroupingProxyModel, which
        // re-appends a launcher at its end when the launcher is shown again
        // after its window closes - the pinned app then jumped to the end of
        // the pinned group. SortManual orders launchers by their stable row in
        // the launcher list instead. Both allow reordering by hand;
        // TasksModel::move() itself keeps launchers apart in 0.
        case 0:
        case 1:
            return TaskManager.TasksModel.SortManual;
        case 2:
            return TaskManager.TasksModel.SortAlpha;
        case 3:
            return TaskManager.TasksModel.SortVirtualDesktop;
        case 4:
            return TaskManager.TasksModel.SortActivity;
        case 5:
            return TaskManager.TasksModel.SortWindowPositionHorizontal;
        default:
            return TaskManager.TasksModel.SortDisabled;
        }
    }

    function groupModeEnumValue(index) {
        switch (Number(index)) {
        case 0:
            return TaskManager.TasksModel.GroupDisabled;
        case 1:
            return TaskManager.TasksModel.GroupApplications;
        default:
            return TaskManager.TasksModel.GroupApplications;
        }
    }

    DBus.DBusServiceWatcher {
        id: windowViewEffectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    Connections {
        target: Plasmoid
        function onLocationChanged(): void {
            if (TaskTools.taskManagerInstanceCount >= 2)
                return;
            iconGeometryTimer.start();
        }
    }

    Connections {
        target: tasks.containment
        function onScreenGeometryChanged(): void {
            iconGeometryTimer.start();
        }
    }

    MediaRegistry {
        id: mediaRegistry
        tasksModel: internalTasksModel
    }

    function handleItemRemoval(taskItem) {
        if (!taskItem || !taskItem.model)
            return;

        // Do not spawn ghosts for Launchers or Startups, as their removal is typically
        // a model transition (e.g. Launcher -> Startup -> Window), not a real closure.
        if (taskItem.model.IsLauncher || taskItem.model.IsStartup)
            return;

        if (tasks.config.iconOnly !== 1)
            return;

        if (taskItem.forceQuitAt > 0 && Date.now() - taskItem.forceQuitAt < 5000) {
            // The neighbors move in once the icon has mostly gone.
            if (tasks.config.forceQuitAnimation === 1)
                spawnIconEffect(burnComponent, taskItem, 575);
            else if (tasks.config.forceQuitAnimation === 2)
                spawnIconEffect(blazeComponent, taskItem, 500);
            return;
        }

        if (taskItem.wasMiddleClicked)
            spawnCloseEffect(tasks.config.closeAnimation, taskItem);
    }

    // A close or unpin effect: 1 = Smoke, 2 = Shatter (closeAnimation).
    function spawnCloseEffect(kind: int, taskItem: Item): void {
        if (kind === 1)
            explosionManager.spawn(tasks, taskItem, true);
        else if (kind === 2)
            spawnIconEffect(shatterComponent, taskItem, 0);
    }

    // QML has no clipboard API; a hidden text field's copy() reaches it.
    function copyToClipboard(text: string): void {
        clipboardHelper.text = text;
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        clipboardHelper.text = "";
    }
    TextEdit {
        id: clipboardHelper
        visible: false
        textFormat: TextEdit.PlainText
    }

    // How long the buttons moving into a closed one's place wait (ms).
    property int moveHold: 0
    Timer {
        id: moveHoldReset
        interval: 100
        onTriggered: tasks.moveHold = 0
    }
    Component {
        id: burnComponent
        BurnEffect {}
    }
    Component {
        id: blazeComponent
        BlazeEffect {}
    }
    Component {
        id: shatterComponent
        ShatterEffect {}
    }
    // Plays an effect over a task's icon, in its place; the neighbors moving
    // into its place wait `hold` ms.
    function spawnIconEffect(component: Component, taskItem: Item, hold: int): void {
        const icon = taskItem.taskIcon as Item;
        if (!icon)
            return;
        // Where the icon sits at rest: mapping the icon itself would take
        // in the hover zoom, still on while the menu was open.
        const box = icon.parent;
        const pos = taskItem.mapToItem(tasks, box.x + icon.x, box.y + icon.y);
        // The room the window has past the icon, away from the panel edge.
        const inWindow = taskItem.mapToItem(null, box.x + icon.x, box.y + icon.y);
        let top = icon;
        while (top.parent)
            top = top.parent;
        const edge = tasks.effectiveLocation;
        let room = inWindow.y;
        if (edge === PlasmaCore.Types.TopEdge)
            room = top.height - inWindow.y - icon.height;
        else if (edge === PlasmaCore.Types.LeftEdge)
            room = top.width - inWindow.x - icon.width;
        else if (edge === PlasmaCore.Types.RightEdge)
            room = inWindow.x;
        const props = {
            x: pos.x, y: pos.y, width: icon.width, height: icon.height,
            iconSource: taskItem.iconSource, edge
        };
        if (component !== blazeComponent)
            props.room = Math.max(0, room);
        component.createObject(tasks, props);
        if (hold > 0) {
            tasks.moveHold = hold;
            moveHoldReset.restart();
        }
    }

    function addLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable && tasks.tasksModel)
            tasks.tasksModel.requestAddLauncher(url);
    }
    function removeLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable && tasks.tasksModel)
            tasks.tasksModel.requestRemoveLauncher(url);
    }
    // Through the filter proxy a move arrives as a layout change that recreates
    // the delegates, so keyboard focus has to be put back on the moved task.
    function focusTaskAt(row: int): void {
        Qt.callLater(() => {
            const task = internalTaskRepeater.itemAt(row) as Task;
            if (task)
                task.forceActiveFocus(Qt.TabFocusReason);
        });
    }

    // The widget's own shortcut ("Keyboard Shortcuts" in its settings).
    // The panel takes the keyboard only while the widget asks for input
    // (AcceptingInputStatus, see PanelView::refreshStatus), and gives it back
    // to the window that had it on PassiveStatus.
    Connections {
        target: Plasmoid
        function onActivated(): void {
            if (!tasks.config.keyboardHints || internalTaskRepeater.count === 0)
                return;
            if (tasks.hintMode) {
                tasks.endHintMode();
                return;
            }
            tasks.hintMode = true;
            tasks.hintReturnTask = tasks.persistentActiveTask();
            Plasmoid.status = PlasmaCore.Types.AcceptingInputStatus;
            // After the panel has put its focus on its first item.
            Qt.callLater(() => hintKeyReceiver.forceActiveFocus());
            hintTimeout.restart();
        }
    }
    // The window that had the keyboard before the hints, given it back when
    // they're cancelled. The panel only does that itself while none of its
    // widgets is active (a player, a monitor): the panel's status is the
    // highest of its widgets', and from ActiveStatus it gives the keyboard
    // to no one (PanelView::refreshStatus).
    property var hintReturnTask: null
    function persistentActiveTask(): var {
        const active = tasks.tasksModel.activeTask;
        if (!active || !active.valid)
            return null;
        const parent = tasks.tasksModel.parent(active);
        return parent && parent.valid
            ? tasks.tasksModel.makePersistentModelIndex(parent.row, active.row)
            : tasks.tasksModel.makePersistentModelIndex(active.row);
    }
    // giveBack: false when the keyboard has already gone elsewhere (a click
    // on another window).
    function endHintMode(giveBack = true): void {
        if (!tasks.hintMode)
            return;
        tasks.hintMode = false;
        hintTimeout.stop();
        Plasmoid.status = PlasmaCore.Types.PassiveStatus;
        const back = tasks.hintReturnTask;
        tasks.hintReturnTask = null;
        if (giveBack && back && back.valid)
            tasks.tasksModel.requestActivate(back);
    }
    Timer {
        id: hintTimeout
        interval: 5000
        onTriggered: tasks.endHintMode()
    }
    Item {
        id: hintKeyReceiver
        // A click on another window takes the keyboard away.
        onActiveFocusChanged: if (!activeFocus) tasks.endHintMode(false)
        Keys.onPressed: (event) => {
            event.accepted = true;
            const code = event.nativeScanCode;
            const index = tasks.hintKeys.findIndex(key => key[1] === code);
            const task = index >= 0 ? internalTaskRepeater.itemAt(index) as Task : null;
            if (!task) {
                // Esc, or a key with no task: nothing is switched.
                tasks.endHintMode();
                return;
            }
            // ActiveStatus first: the panel then forgets the window it would
            // give the keyboard back to, and the task's window stays active.
            tasks.hintMode = false;
            tasks.hintReturnTask = null;
            hintTimeout.stop();
            Plasmoid.status = PlasmaCore.Types.ActiveStatus;
            task.showPress();
            TaskTools.activateTask(task.modelIndex(), task.model, null, task, Plasmoid, tasks, windowViewEffectWatcher.registered);
            Plasmoid.status = PlasmaCore.Types.PassiveStatus;
        }
    }

    // Activates the task for a Meta+number shortcut. Plasmashell up to 6.7 calls
    // it by name from C++, as activateTaskAtIndex(QVariant), so keep the name
    // and the untyped argument; on 6.8 and later TaskEntryShortcuts calls it.
    function activateTaskAtIndex(index: var): void {
        // Turned off, a press does nothing here, also when plasmashell (up to
        // 6.7) is the one calling.
        if (typeof index !== "number" || !tasks.config.taskEntryShortcuts)
            return;
        const task = internalTaskRepeater.itemAt(index) as Task;
        if (task) {
            task.showPress();
            TaskTools.activateTask(task.modelIndex(), task.model, null, task, Plasmoid, tasks, windowViewEffectWatcher.registered);
        }
    }
    function adjustGlobalVolume(increment: int) {
        if (!mediaRegistry.preferredSink)
            return;

        const lastResult = mediaRegistry.adjustVolume([mediaRegistry.preferredSink], increment);
        const overlay = globalVolumeOverlayLoader.item as TaskVolumeOverlay;
        if (lastResult && overlay) {
            overlay.volume = lastResult.volume;
            overlay.muted = lastResult.muted;
            overlay.show();
        }
    }
    function createContextMenu(rootTask, modelIndex, args = {}) {
        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            tasksModel: tasks.tasksModel,
            virtualDesktopInfo,
            activityInfo,
            tasksRoot: tasks
        });
        return tasks.contextMenuComponent.createObject(rootTask, initialArgs);
    }
    function shouldBeMirrored(reverseMode, layoutDirection, vertical): bool {
        if (vertical)
            return layoutDirection === Qt.RightToLeft;
        if (layoutDirection === Qt.LeftToRight)
            return reverseMode;
        return !reverseMode;
    }

    Item {
        anchors.fill: parent

        HoverHandler {
            id: rootHoverHandler
        }

        TaskManager.VirtualDesktopInfo {
            id: virtualDesktopInfo
        }
        TaskManager.ActivityInfo {
            id: activityInfo
            readonly property string nullUuid: "00000000-0000-0000-0000-000000000000"
        }

        Loader {
            id: globalVolumeOverlayLoader
            anchors.fill: parent
            source: "TaskVolumeOverlay.qml"
        }

        Timer {
            id: iconGeometryTimer
            interval: 500
            repeat: false
            onTriggered: tasks.publishIconGeometries(taskListView.children)
        }

        Binding {
            target: Plasmoid
            property: "status"
            value: (tasks.tasksModel && tasks.tasksModel.anyTaskDemandsAttention && tasks.config.unhideOnAttention ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus)
            restoreMode: Binding.RestoreBinding
        }

        Component {
            id: busyIndicator
            PlasmaComponents3.BusyIndicator {
                anchors.fill: parent
                running: true
            }
        }

        Item {
            id: dragHelper
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction

            // Holds the launcher URL while waiting for the unpin animation to finish.
            property string pendingUnpinUrl: ""

            // Delays the actual model removal so the explosion animation has time to play.
            Timer {
                id: unpinDelayTimer
                interval: 300
                repeat: false
                onTriggered: {
                    if (dragHelper.pendingUnpinUrl !== "") {
                        tasks.removeLauncher(dragHelper.pendingUnpinUrl);
                        dragHelper.pendingUnpinUrl = "";
                    }
                }
            }

            Drag.onDragFinished: dropAction => {
                // A pure launcher (no running windows) dropped anywhere but this
                // widget is unpinned. The drop action can't tell: other targets
                // may accept or ignore the drag either way.
                const source = tasks.dragSource;
                let pModel = "model";
                let pWinIdList = "winIdList";
                if (tasks.config.unpinByDrag && !tasks.dragOverApplet && source && source[pModel] && source[pModel].IsLauncher && source[pWinIdList].length === 0) {
                    if (tasks.config.unpinAnimation > 0 && tasks.config.iconOnly === 1) {
                        tasks.spawnCloseEffect(tasks.config.unpinAnimation, source);
                        // The effect draws the icon itself from here on.
                        source.taskIcon.opacity = 0;
                        // Delay removal so the explosion animation plays before the item disappears.
                        dragHelper.pendingUnpinUrl = source[pModel].LauncherUrlWithoutIcon.toString();
                        unpinDelayTimer.start();
                    } else {
                        tasks.removeLauncher(source[pModel].LauncherUrlWithoutIcon);
                    }
                }
                tasks.dragOverApplet = false;
                tasks.dragSource = null;
                tasks.dropIndicator.visible = false;
            }
        }

        Rectangle {
            id: dropIndicatorRect
            color: Kirigami.Theme.highlightColor
            width: tasks.vertical ? parent.width : 2
            height: tasks.vertical ? 2 : parent.height
            visible: false
            z: 999

            Behavior on x {
                enabled: tasks.dropIndicator.visible
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on y {
                enabled: tasks.dropIndicator.visible
                NumberAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutQuad
                }
            }
        }

        KSvg.FrameSvgItem {
            id: taskFrame
            visible: false
            imagePath: "widgets/tasks"
            prefix: TaskTools.taskPrefix("normal", tasks.effectiveLocation)
        }

        MouseHandler {
            id: mouseHandler
            anchors.fill: parent
            target: taskList
            tasks: tasks
            tasksModel: tasks.tasksModel
            proxyModel: internalFilteredTasksModel
            onUrlsDropped: urls => {
                const isApp = url => {
                    let s = url.toString();
                    return s.endsWith(".desktop") || s.startsWith("applications:") || s.startsWith("application://");
                };
                const createLaunchers = urls.every(isApp);
                if (createLaunchers) {
                    urls.forEach(item => tasks.addLauncher(item));
                    return;
                }
                if (!hoveredItem)
                    return;
                const task = hoveredItem as Task;
                if (tasks.tasksModel) {
                    if (task.model && task.model.IsLauncher)
                        TaskTools.claimLaunch(tasks.tasksModel, task.modelIndex(), Plasmoid.id);
                    tasks.tasksModel.requestOpenUrls(task.modelIndex(), urls);
                }
            }
        }

        // Cursor-following glow drawn on the panel underneath the task buttons.
        // Sized to the task list area so it never bleeds onto other applets.
        Shape {
            id: hoverGlow
            anchors.fill: tmf
            // A hover effect, so none on a classic panel.
            visible: tasks.config.cursorGlow && tasks.iconsOnly
            preferredRendererType: Shape.CurveRenderer

            // Kept after the cursor leaves so the glow fades out in place
            property real cursorX: 0
            property real cursorY: 0
            property color glowColor: Kirigami.Theme.highlightColor

            function tint(alpha: real): color {
                return Qt.rgba(glowColor.r, glowColor.g, glowColor.b, alpha);
            }

            opacity: rootHoverHandler.hovered && tasks.instantHoveredTask !== null ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on glowColor {
                ColorAnimation {
                    duration: Kirigami.Units.longDuration
                }
            }

            Connections {
                target: rootHoverHandler
                function onPointChanged(): void {
                    if (!rootHoverHandler.hovered) {
                        return;
                    }
                    hoverGlow.cursorX = rootHoverHandler.point.position.x - hoverGlow.x;
                    hoverGlow.cursorY = rootHoverHandler.point.position.y - hoverGlow.y;
                    if (tasks.instantHoveredTask) {
                        hoverGlow.glowColor = tasks.instantHoveredTask.frame.indicatorColor;
                    }
                }
            }

            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: hoverGlow.cursorX
                    centerY: hoverGlow.cursorY
                    centerRadius: (tasks.vertical ? hoverGlow.width : hoverGlow.height) * 1.4
                    focalX: centerX
                    focalY: centerY
                    GradientStop { position: 0.0; color: hoverGlow.tint(0.35) }
                    GradientStop { position: 0.35; color: hoverGlow.tint(0.14) }
                    GradientStop { position: 0.7; color: hoverGlow.tint(0.04) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                PathRectangle {
                    width: hoverGlow.width
                    height: hoverGlow.height
                }
            }
        }

        TriangleMouseFilter {
            id: tmf
            filterTimeOut: 300
            active: tasks.currentHoveredTask !== null
            blockFirstEnter: false
            edge: {
                switch (tasks.effectiveLocation) {
                case PlasmaCore.Types.BottomEdge:
                    return Qt.TopEdge;
                case PlasmaCore.Types.TopEdge:
                    return Qt.BottomEdge;
                case PlasmaCore.Types.LeftEdge:
                    return Qt.RightEdge;
                case PlasmaCore.Types.RightEdge:
                    return Qt.LeftEdge;
                default:
                    return Qt.TopEdge;
                }
            }
            readonly property bool centerAlign: tasks.iconsOnly && tasks.config.fill && tasks.config.fillAlignment === 1
            LayoutMirroring.enabled: tasks.shouldBeMirrored(tasks.config.reverseMode, Qt.locale().textDirection, tasks.vertical)
            x: centerAlign && !tasks.vertical ? Math.round((parent.width - width) / 2) : 0
            y: centerAlign && tasks.vertical ? Math.round((parent.height - height) / 2) : 0
            height: taskListView.height
            width: taskListView.width

            TaskList {
                id: taskListView
                tasks: tasks
                tasksModel: tasks.effectiveTasksModel
                LayoutMirroring.enabled: tasks.shouldBeMirrored(tasks.config.reverseMode, Qt.locale().textDirection, tasks.vertical)
                anchors {
                    left: parent.left
                    top: parent.top
                }
                readonly property real widthOccupation: internalTaskRepeater.count / columns
                readonly property real heightOccupation: internalTaskRepeater.count / rows
                Layout.maximumWidth: {
                    if (widthOccupation <= 0)
                        return 0;
                    if (tasks.iconsOnly) {
                        return Math.round((internalTaskRepeater.count * LayoutMetrics.preferredMaxWidth(tasks)) / widthOccupation);
                    }
                    return Math.round(children.reduce((acc, child) => (child && child.visible && isFinite(child.Layout.maximumWidth)) ? acc + child.Layout.maximumWidth : acc, 0) / widthOccupation);
                }
                Layout.maximumHeight: {
                    if (heightOccupation <= 0)
                        return 0;
                    if (tasks.iconsOnly) {
                        return Math.round((internalTaskRepeater.count * LayoutMetrics.preferredMaxHeight(tasks)) / heightOccupation);
                    }
                    return Math.round(children.reduce((acc, child) => (child && child.visible && isFinite(child.Layout.maximumHeight)) ? acc + child.Layout.maximumHeight : acc, 0) / heightOccupation);
                }
                width: tasks.shouldShrinkToZero ? 0 : (tasks.vertical ? tasks.width * Math.min(1, widthOccupation) : Math.min(tasks.width, Layout.maximumWidth))
                height: tasks.shouldShrinkToZero ? 0 : (tasks.vertical ? Math.min(tasks.height, Layout.maximumHeight) : tasks.height * Math.min(1, heightOccupation))
                flow: tasks.vertical ? (tasks.config.forceStripes ? Grid.LeftToRight : Grid.TopToBottom) : (tasks.config.forceStripes ? Grid.TopToBottom : Grid.LeftToRight)
                onAnimatingChanged: if (!animating)
                    iconGeometryTimer.restart()

                Repeater {
                    id: internalTaskRepeater
                    model: tasks.effectiveTasksModel
                    delegate: Task {
                        tasksRoot: tasks
                    }
                }

                Connections {
                    target: tasks.effectiveTasksModel
                    function onRowsAboutToBeRemoved(parent, first, last) {
                        for (let i = first; i <= last; ++i) {
                            tasks.handleItemRemoval(internalTaskRepeater.itemAt(i));
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        // The close and unpin animations were checkboxes before 3.0.0.
        if (Plasmoid.configuration.smokeExplosionOnClose) {
            Plasmoid.configuration.closeAnimation = 1;
            Plasmoid.configuration.smokeExplosionOnClose = false;
        }
        if (Plasmoid.configuration.unpinByDragExplosion) {
            Plasmoid.configuration.unpinAnimation = 1;
            Plasmoid.configuration.unpinByDragExplosion = false;
        }
        TaskTools.taskManagerInstanceCount += 1;
        requestLayout.connect(iconGeometryTimer.restart);
        TaskEntryShortcuts.addTarget(tasks);
    }
    Component.onDestruction: {
        TaskTools.taskManagerInstanceCount -= 1;
        TaskEntryShortcuts.removeTarget(tasks);
    }

    // The window tooltips are shown in sits against this strip: along the
    // whole widget, and across the panel up to the hovered button's
    // tooltipAnchor. The window is as long as the screen along the panel, so
    // it stays put while the cursor goes from button to button and the frame
    // moves inside it. A window that moved and resized on every animation
    // step wobbled: the compositor places it a frame after its content is
    // drawn.
    Item {
        id: tooltipStrip
        visible: false
        readonly property Item anchorItem: tasks.currentHoveredTask ? tasks.currentHoveredTask.tooltipAnchor : tasks.lastTooltipParent
        readonly property rect anchorRect: anchorItem
            ? anchorItem.mapToItem(tasks, 0, 0, anchorItem.width, anchorItem.height)
            : Qt.rect(0, 0, tasks.width, tasks.height)
        x: tasks.vertical ? anchorRect.x : 0
        y: tasks.vertical ? 0 : anchorRect.y
        width: tasks.vertical ? anchorRect.width : tasks.width
        height: tasks.vertical ? tasks.height : anchorRect.height
    }
    readonly property int screenLength: tasks.vertical ? Screen.height : Screen.width
    // How long the tooltip frame takes to move and resize to another task.
    readonly property int tooltipMorphDuration: 300

    PlasmaCore.Dialog {
        id: windowTooltipDialog

        location: tasks.effectiveLocation
        type: PlasmaCore.Dialog.Tooltip

        backgroundHints: PlasmaCore.Types.NoBackground
        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.BypassWindowManagerHint
        hideOnWindowDeactivate: false

        readonly property bool shouldShow: tasks.config.enableToolTips && tasks.currentHoveredTask !== null
        visible: (shouldShow && toolTipInstance.implicitWidth > 0) || winContainer.opacity > 0
        visualParent: tooltipStrip

        mainItem: Item {
            id: winContainer

            // While it fades out, the frame keeps the size it had: the content
            // has no task any more and would shrink it.
            readonly property real targetWidth: (windowTooltipDialog.shouldShow && toolTipInstance.implicitWidth > 0 ? toolTipInstance.implicitWidth + winBgFrame.margins.left + winBgFrame.margins.right : lastWidth)
            readonly property real targetHeight: (windowTooltipDialog.shouldShow && toolTipInstance.implicitHeight > 0 ? toolTipInstance.implicitHeight + winBgFrame.margins.top + winBgFrame.margins.bottom : lastHeight)

            readonly property bool isTop: tasks.effectiveLocation === PlasmaCore.Types.TopEdge
            readonly property bool isLeft: tasks.effectiveLocation === PlasmaCore.Types.LeftEdge
            readonly property bool isRight: tasks.effectiveLocation === PlasmaCore.Types.RightEdge
            readonly property bool isBottom: !isLeft && !isRight && !isTop

            // Shadow needs transparent space on free sides to prevent clipping:
            // winBgFrame's shadow.size plus its offset.
            readonly property int shadowPadding: 9
            // 8px gap allows an 8px radius shadow to render fully on the panel side
            readonly property int gapSize: tasks.tooltipShadowBand

            readonly property int marginTop: isTop ? gapSize : shadowPadding
            readonly property int marginBottom: isBottom ? gapSize : shadowPadding
            readonly property int marginLeft: isLeft ? gapSize : shadowPadding
            readonly property int marginRight: isRight ? gapSize : shadowPadding

            // Cache the last valid dimensions when the tooltip was loaded.
            // When toolTipInstance.implicitWidth drops to 0 during closure or reload,
            // we use the cached dimensions to prevent the frame from
            // instantly shrinking to borders (margins) size.
            property real lastWidth: 0
            property real lastHeight: 0
            Binding on lastWidth {
                when: windowTooltipDialog.shouldShow && toolTipInstance.implicitWidth > 0
                value: toolTipInstance.implicitWidth + winBgFrame.margins.left + winBgFrame.margins.right
                restoreMode: Binding.RestoreNone
            }
            Binding on lastHeight {
                when: windowTooltipDialog.shouldShow && toolTipInstance.implicitHeight > 0
                value: toolTipInstance.implicitHeight + winBgFrame.margins.top + winBgFrame.margins.bottom
                restoreMode: Binding.RestoreNone
            }

            // Across the panel the window is as deep as the biggest tooltip
            // since it was shown: it grows when it has to, and never shrinks
            // while it's up, so the frame shrinks inside it instead.
            property real depth: 0
            readonly property real targetDepth: tasks.vertical ? targetWidth : targetHeight
            onTargetDepthChanged: depth = Math.max(depth, targetDepth)
            Connections {
                target: windowTooltipDialog
                function onVisibleChanged(): void {
                    if (!windowTooltipDialog.visible) {
                        winContainer.depth = winContainer.targetDepth;
                    }
                }
            }

            implicitWidth: tasks.vertical ? depth + marginLeft + marginRight : tasks.screenLength
            implicitHeight: tasks.vertical ? tasks.screenLength : depth + marginTop + marginBottom
            width: implicitWidth
            height: implicitHeight

            // The frame moves and resizes only once the tooltip is fully up:
            // when it appears, it does so in place.
            readonly property bool morph: tasks.tooltipAnimationEnabled && windowTooltipDialog.shouldShow && opacity > 0.99

            // The hovered button's center along the panel, in this window.
            readonly property real buttonCenter: {
                const task = tasks.currentHoveredTask;
                if (!task) {
                    return lastButtonCenter;
                }
                const center = task.mapToGlobal(task.width / 2, task.height / 2);
                return tasks.vertical ? center.y - windowTooltipDialog.y : center.x - windowTooltipDialog.x;
            }
            property real lastButtonCenter: 0
            onButtonCenterChanged: lastButtonCenter = buttonCenter

            opacity: windowTooltipDialog.shouldShow ? 1 : 0
            Behavior on opacity {
                enabled: tasks.tooltipAnimationEnabled
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }

            Kirigami.ShadowedRectangle {
                id: winBgFrame

                Kirigami.Theme.colorSet: Kirigami.Theme.Tooltip
                Kirigami.Theme.inherit: false

                width: winContainer.targetWidth
                height: winContainer.targetHeight
                Behavior on width {
                    enabled: winContainer.morph
                    NumberAnimation { duration: tasks.tooltipMorphDuration; easing.type: Easing.InOutCubic }
                }
                Behavior on height {
                    enabled: winContainer.morph
                    NumberAnimation { duration: tasks.tooltipMorphDuration; easing.type: Easing.InOutCubic }
                }

                // What moves is the middle of the frame's side facing the
                // panel: centered on the button, kept on screen for the
                // target size. The corner follows from it and the animated
                // size, so the frame grows and shrinks around that point.
                readonly property real targetAlong: tasks.vertical ? winContainer.targetHeight : winContainer.targetWidth
                property real center: Math.max(winContainer.shadowPadding + targetAlong / 2,
                    Math.min(winContainer.buttonCenter, tasks.screenLength - winContainer.shadowPadding - targetAlong / 2))
                Behavior on center {
                    enabled: winContainer.morph
                    NumberAnimation { duration: tasks.tooltipMorphDuration; easing.type: Easing.InOutCubic }
                }
                x: tasks.vertical ? (winContainer.isRight ? winContainer.width - winContainer.marginRight - width : winContainer.marginLeft) : center - width / 2
                y: tasks.vertical ? center - height / 2 : (winContainer.isTop ? winContainer.marginTop : winContainer.height - winContainer.marginBottom - height)

                // The content keeps its own size and is cut by the frame while
                // the frame catches up with it.
                clip: true

                color: Kirigami.Theme.backgroundColor
                radius: Kirigami.Units.cornerRadius

                // A blurred shadow is inherently fainter at the corners than
                // along the edges, so on light themes the corner looked bare;
                // the outline keeps it defined regardless of the shadow.
                border.width: 1
                border.color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)

                // Kept narrow on purpose: the wider Kirigami's shadow is relative
                // to the corner radius, the more it rounds off and thins out
                // at the corners, and the corners looked recessed (#57).
                shadow.size: 8
                shadow.color: Qt.rgba(0, 0, 0, 0.6)
                shadow.xOffset: 1
                shadow.yOffset: 1

                // Thumbnails get a thinner frame: they already sit in their own
                // highlight box, and a wider edge only shrinks the window image.
                readonly property int tooltipFramePadding: toolTipInstance.showThumbnails ? 2 : 4
                readonly property var margins: ({
                        left: tooltipFramePadding,
                        top: tooltipFramePadding,
                        right: tooltipFramePadding,
                        bottom: tooltipFramePadding
                    })

                ToolTipDelegate {
                    id: toolTipInstance
                    clip: true
                    anchors.centerIn: parent
                    width: Math.max(0, winContainer.targetWidth - 2 * winBgFrame.tooltipFramePadding)
                    height: Math.max(0, winContainer.targetHeight - 2 * winBgFrame.tooltipFramePadding)

                    // A new task's content comes in with a short fade while
                    // the frame moves to it.
                    onParentTaskChanged: if (winContainer.morph) contentFade.restart()
                    NumberAnimation {
                        id: contentFade
                        target: toolTipInstance
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: tasks.tooltipMorphDuration
                        easing.type: Easing.InCubic
                    }

                    onContainsMouseChanged: tasks.isTooltipHovered = containsMouse

                    parentTask: tasks.currentHoveredTask
                    tasksModel: tasks.tasksModel
                    mediaRegistry: tasks.mediaRegistry

                    readonly property var taskModel: parentTask ? parentTask.model : null

                    // parentTask.index is a row in the filtered proxy; map it to the source model,
                    // otherwise lookups below read the wrong task whenever filters are active
                    rootIndex: {
                        if (parentTask) {
                            const idx = parentTask.modelIndex();
                            if (idx !== undefined && idx !== null) return idx;
                        }
                        return internalTasksModel.makeModelIndex(parentTask ? parentTask.index : 0, -1);
                    }
                    appName: taskModel ? taskModel.AppName : ""
                    pidParent: taskModel ? taskModel.AppPid : 0
                    windows: taskModel ? taskModel.WinIdList : []
                    isGroup: taskModel ? taskModel.IsGroupParent : false
                    icon: parentTask ? parentTask.iconSource : ""
                    launcherUrl: taskModel ? taskModel.LauncherUrlWithoutIcon : ""
                    isLauncher: taskModel ? taskModel.IsLauncher : false
                    isMinimized: taskModel ? taskModel.IsMinimized : false
                    display: taskModel ? taskModel.display : ""
                    genericName: taskModel ? taskModel.GenericName : ""
                    virtualDesktops: taskModel ? taskModel.VirtualDesktops : []
                    isOnAllVirtualDesktops: taskModel ? taskModel.IsOnAllVirtualDesktops : false
                    activities: taskModel ? taskModel.Activities : []

                    forceTextMode: tasks.toolTipOpenedByClick !== null && tasks.config.groupedTaskVisualization !== 1
                }
            }
        }
    }
}
