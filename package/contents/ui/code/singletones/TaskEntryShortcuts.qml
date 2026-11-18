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
 * all. The Python helper registers them (RegisterTaskEntryShortcuts), under
 * the same component and action names, so a key changed in System Settings
 * still applies; this hands each press to one of the instances.
 *
 * The stock backend isn't joined when it is loaded too: its module can only be
 * imported once that widget's plugin is loaded, and a failed import before
 * then breaks the stock widget for the rest of the session.
 */
Item {
    id: root

    // Plasmashell before 6.7.80 (the start of the 6.8 cycle) handles the
    // shortcuts itself; taking them here too would activate every task twice.
    // Other hosts (plasmawindowed in make test) would file them under their
    // own name in the real kglobalshortcutsrc.
    readonly property bool shortcutsHandled: Qt.application.name === "plasmashell" && !versionBelow(Qt.application.version, [6, 7, 80])

    // KGlobalAccel files an application's shortcuts under its name, which is
    // where the stock backend's go as well, so both drive the same actions.
    readonly property string componentName: Qt.application.name
    readonly property string actionPrefix: "activate task manager entry "
    readonly property int entryCount: 10

    // Object path of the component that emits the presses, from kglobalaccel.
    property string componentPath: ""

    property var targets: []
    property int targetCount: 0

    // The keys of the actions as kglobalaccel has them (they can be changed
    // in System Settings): the first key combination of entry 1 to 10, as
    // Qt's combined key and modifier bits, 0 for none. Empty until read.
    property var entryKeys: []
    readonly property int modifierBits: Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier

    // Entry `index` (0-based): its key, the default Meta+N until read.
    function keyOf(index) {
        if (entryKeys.length === 0)
            return Qt.MetaModifier | (Qt.Key_1 + index);
        return entryKeys[index] || 0;
    }
    function keyName(combined) {
        const key = combined & ~modifierBits & ~Qt.KeypadModifier;
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
            return "F" + (key - Qt.Key_F1 + 1);
        if (key > 0x20 && key < 0x7f)
            return String.fromCharCode(key).toUpperCase();
        return "?";
    }
    // What a task's badge shows for entry `index`: its key without the
    // modifiers, or "" when the entry has no key.
    function badgeText(index) {
        const key = keyOf(index);
        return key === 0 ? "" : keyName(key);
    }
    // Each entry is a shortcut of its own: its badge shows while exactly
    // its modifiers are held.
    function shownWhileHeld(index) {
        const key = keyOf(index);
        return key !== 0 && heldModifiers !== 0 && (key & modifierBits) === heldModifiers;
    }

    function readKeys() {
        const keys = [];
        let pending = entryCount;
        for (let i = 0; i < entryCount; ++i) {
            const reply = DBus.SessionBus.asyncCall({
                "service": "org.kde.kglobalaccel",
                "path": "/kglobalaccel",
                "iface": "org.kde.KGlobalAccel",
                "member": "shortcutKeys",
                "arguments": [[componentName, actionPrefix + (i + 1), "", ""]],
                "signature": "(as)"
            });
            reply.finished.connect(() => {
                // a(ai): key sequences of up to four keys, each wrapped as
                // {value}. A single-key sequence's first key is the one.
                let key = 0;
                if (!reply.isError) {
                    const first = (reply.value || [])[0];
                    const sequence = first ? (first[0] ?? first) : null;
                    const k = sequence ? sequence[0] : null;
                    key = Number(k && typeof k === "object" ? k.value : k) || 0;
                }
                keys[i] = key;
                reply.destroy();
                if (--pending === 0)
                    root.entryKeys = keys;
            });
        }
    }
    Component.onCompleted: readKeys()

    // Task keys: shown on the instance a press would go to while the
    // modifiers of one of the shortcuts are held, after a short delay so Meta+E and other
    // combinations don't flash them. Before 6.8 plasmashell picks the
    // instance itself, so with several it may be another one.
    // Set by ModifierKeyState.qml, which this loads.
    property int heldModifiers: 0
    readonly property bool numbersHeld: {
        for (let i = 0; i < 9; ++i) {
            if (shownWhileHeld(i))
                return true;
        }
        return false;
    }
    property var numbersTarget: null
    onNumbersHeldChanged: {
        if (numbersHeld) {
            numbersDelay.restart();
        } else {
            numbersDelay.stop();
            numbersTarget = null;
        }
    }

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
        if (targets.indexOf(target) !== -1)
            return;
        targets.push(target);
        targetCount = targets.length;
        if (targets.length === 1)
            registerTimer.restart();
    }

    // Instances that take the shortcuts: those with them turned on.
    function activeTargets() {
        return targets.filter(target => target.config.taskEntryShortcuts);
    }

    function refresh() {
        registerTimer.restart();
    }

    function removeTarget(target) {
        const i = targets.indexOf(target);
        if (i !== -1)
            targets.splice(i, 1);
        targetCount = targets.length;
        if (numbersTarget === target)
            numbersTarget = null;
    }

    // In the order the stock task manager uses: an instance with the active
    // task that shows every screen, then one that shows only its own; with no
    // active task anywhere (to launch a pinned app), one showing every
    // screen, then any.
    function dispatchTarget() {
        const candidates = activeTargets();
        let fallback = null;
        for (const target of candidates) {
            if (!target.hasActiveTask)
                continue;
            if (!target.showsOnlyCurrentScreen)
                return target;
            fallback = fallback || target;
        }
        if (fallback)
            return fallback;
        for (const target of candidates) {
            if (!target.showsOnlyCurrentScreen)
                return target;
        }
        return candidates.length > 0 ? candidates[0] : null;
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

    function registerShortcuts() {
        if (!shortcutsHandled || activeTargets().length === 0 || !helperWatcher.registered)
            return;
        DesktopActionsManager.registerTaskEntryShortcuts(componentName, path => {
            if (path)
                root.componentPath = path;
            root.readKeys();
        });
    }

    Timer {
        id: numbersDelay
        interval: 200
        onTriggered: root.numbersTarget = root.dispatchTarget()
    }

    Loader {
        id: modifierKeyState
        active: root.targetCount > 0
        source: Qt.resolvedUrl("../../ModifierKeyState.qml")
        onActiveChanged: if (!active) root.heldModifiers = 0
    }

    // Coalesces the requests to register into one round of calls.
    Timer {
        id: registerTimer
        interval: 0
        onTriggered: root.registerShortcuts()
    }

    // The helper may come up after the first instance; it registers them
    // again itself whenever kglobalaccel restarts.
    DBus.DBusServiceWatcher {
        id: helperWatcher
        busType: DBus.BusType.Session
        watchedService: root.shortcutsHandled ? DesktopActionsManager.service : ""
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

    // A key changed in System Settings.
    DBus.SignalWatcher {
        service: "org.kde.kglobalaccel"
        path: "/kglobalaccel"
        iface: "org.kde.KGlobalAccel"

        function dbusyourShortcutsChanged(actionId, keys) {
            const id = Array.from(actionId, String);
            if (id[0] === root.componentName && String(id[1]).startsWith(root.actionPrefix))
                readKeysTimer.restart();
        }
        function dbusyourShortcutGotChanged() {
        }
    }
    // All ten change at once when a scheme is applied.
    Timer {
        id: readKeysTimer
        interval: 100
        onTriggered: root.readKeys()
    }
}
