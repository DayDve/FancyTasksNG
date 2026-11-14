/*
    SPDX-FileCopyrightText: 2026 Egor <359aar@proton.me>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma Singleton
import QtQuick
import org.kde.plasma.workspace.dbus as DBus

/**
 * TaskEntryShortcuts: the "Activate Task Manager Entry 1-10" global shortcuts
 * (Meta+1 to Meta+9 by default).
 *
 * Up to Plasma 6.7, plasmashell registered them itself and called
 * activateTaskAtIndex() on a task manager. Since 6.8 the stock task manager
 * registers them from its C++ backend, which only exists while that widget is
 * loaded, so with only this widget on the panels nothing registers them at
 * all. This registers them through kglobalaccel's D-Bus interface, under the
 * same component and action names, so a key changed in System Settings still
 * applies, and hands each press to one of the instances.
 *
 * The stock backend isn't joined when it is loaded too: its module can only be
 * imported once that widget's plugin is loaded, and a failed import before
 * then breaks the stock widget for the rest of the session.
 */
Item {
    id: root

    // Plasmashell before 6.7.80 (the start of the 6.8 cycle) handles the
    // shortcuts itself; taking them here too would activate every task twice.
    readonly property bool shortcutsHandled: !(Qt.application.name === "plasmashell" && versionBelow(Qt.application.version, [6, 7, 80]))

    // KGlobalAccel files an application's shortcuts under its name, which is
    // where the stock backend's go as well, so both drive the same actions.
    readonly property string componentName: Qt.application.name
    readonly property string actionPrefix: "activate task manager entry "
    readonly property int entryCount: 10

    // Object path of the component that emits the presses, from kglobalaccel.
    property string componentPath: ""

    property var targets: []

    function versionBelow(version, minimum) {
        const parts = String(version).split(".").map(part => parseInt(part, 10) || 0);
        for (let i = 0; i < minimum.length; ++i) {
            const part = parts[i] || 0;
            if (part !== minimum[i])
                return part < minimum[i];
        }
        return false;
    }

    // The actions stay registered once the last instance is gone, as the stock
    // backend's do: they may be the stock widget's as well by then.
    function addTarget(target) {
        if (!shortcutsHandled || targets.indexOf(target) !== -1)
            return;
        targets.push(target);
        if (targets.length === 1)
            registerTimer.restart();
    }

    function removeTarget(target) {
        const i = targets.indexOf(target);
        if (i !== -1)
            targets.splice(i, 1);
    }

    // In the order the stock task manager uses: an instance with the active
    // task that shows every screen, then one that shows only its own; with no
    // active task anywhere (to launch a pinned app), one showing every
    // screen, then any.
    function dispatchTarget() {
        let fallback = null;
        for (const target of targets) {
            if (!target.hasActiveTask)
                continue;
            if (!target.showsOnlyCurrentScreen)
                return target;
            fallback = fallback || target;
        }
        if (fallback)
            return fallback;
        for (const target of targets) {
            if (!target.showsOnlyCurrentScreen)
                return target;
        }
        return targets.length > 0 ? targets[0] : null;
    }

    function handlePress(component, action) {
        if (component !== componentName || !action.startsWith(actionPrefix))
            return;
        const entry = parseInt(action.slice(actionPrefix.length), 10);
        if (!(entry >= 1 && entry <= entryCount))
            return;
        const target = dispatchTarget();
        if (target)
            target.activateTaskAtIndex(entry - 1);
    }

    function actionId(entry) {
        // qmllint disable unqualified
        // The stock task manager's wording and translation, so the action has
        // the same name in System Settings whichever widget registered it.
        const friendlyName = typeof i18nd === "function"
            ? i18nd("plasma_applet_org.kde.plasma.taskmanager", "Activate Task Manager Entry %1", entry)
            : "Activate Task Manager Entry " + entry;
        // qmllint enable unqualified
        // An empty component friendly name keeps the one already on record.
        return [componentName, actionPrefix + entry, "", friendlyName];
    }

    function callKGlobalAccel(member, args, signature, onReply) {
        DBus.SessionBus.asyncCall({
            service: "org.kde.kglobalaccel",
            path: "/kglobalaccel",
            iface: "org.kde.KGlobalAccel",
            member: member,
            arguments: args,
            signature: signature
        }, reply => {
            if (onReply)
                onReply(reply);
        }, reply => {
            console.warn("FancyTasksNG: kglobalaccel", member, "failed:", reply.error.message);
        });
    }

    // What KGlobalAccel::setGlobalShortcut() does. setShortcut() rather than
    // setShortcutKeys(): the D-Bus bindings can't build the latter's a(ai).
    function registerShortcuts() {
        if (!shortcutsHandled || targets.length === 0 || !kglobalaccelWatcher.registered)
            return;
        const setPresent = 2;
        const isDefault = 8;
        for (let entry = 1; entry <= entryCount; ++entry) {
            const id = actionId(entry);
            const keys = entry < 10 ? [Qt.MetaModifier | (Qt.Key_0 + entry)] : [];
            callKGlobalAccel("doRegister", [id], "(as)");
            // Keeps the keys already on record (set in System Settings or
            // by an earlier registration) and only applies these to a new action.
            callKGlobalAccel("setShortcut", [id, keys, setPresent], "(asaiu)");
            callKGlobalAccel("setShortcut", [id, keys, isDefault], "(asaiu)");
        }
        callKGlobalAccel("getComponent", [componentName], "(s)", reply => {
            root.componentPath = reply.value.toString();
        });
    }

    // Coalesces the requests to register into one round of calls.
    Timer {
        id: registerTimer
        interval: 0
        onTriggered: root.registerShortcuts()
    }

    // kglobalaccel loses the actions' state when it restarts (with KWin on
    // Wayland), so they're registered again whenever it comes up.
    DBus.DBusServiceWatcher {
        id: kglobalaccelWatcher
        busType: DBus.BusType.Session
        watchedService: root.shortcutsHandled ? "org.kde.kglobalaccel" : ""
        onRegisteredChanged: {
            if (registered)
                registerTimer.restart();
        }
    }

    DBus.SignalWatcher {
        enabled: root.shortcutsHandled
        service: "org.kde.kglobalaccel"
        path: root.componentPath
        iface: "org.kde.kglobalaccel.Component"

        // Strings arrive wrapped as the bindings' D-Bus string type.
        function dbusglobalShortcutPressed(component, action, timestamp) {
            root.handlePress(String(component), String(action));
        }
        // Present so the watcher doesn't warn for each of the component's
        // other signals; only the press matters.
        function dbusglobalShortcutRepeated() {
        }
        function dbusglobalShortcutReleased() {
        }
    }
}
