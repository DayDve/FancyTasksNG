/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma Singleton
import QtQuick
import org.kde.plasma.workspace.dbus as DBus
import org.kde.plasma.plasma5support as Plasma5Support

/**
 * DesktopActionsManager ‒ provides desktop file jump list actions
 * and recent documents via a Python helper over DBus.
 */
Item {
    id: root

    property var cache: ({})
    // Bumped whenever a result is cached, so bindings over the cache update.
    property int revision: 0

    readonly property string _service: "io.github.daydve.fancytasksng.DesktopActions"

    // Calls a helper method; onReply (optional) gets the reply value, or
    // undefined when the call failed. Right after plasmashell starts the
    // helper may not be on the bus yet; that error is expected and quiet.
    function _call(member, signature, args, onReply, iface) {
        const pendingReply = DBus.SessionBus.asyncCall({
            "service": root._service,
            "path": "/DesktopActions",
            "iface": iface || root._service,
            "member": member,
            "arguments": args,
            "signature": signature
        });
        pendingReply.finished.connect(() => {
            let value;
            if (pendingReply.isError) {
                if (pendingReply.error.name !== "org.freedesktop.DBus.Error.ServiceUnknown") {
                    console.warn("DesktopActionsManager:", member, pendingReply.error.name, pendingReply.error.message);
                }
            } else {
                value = pendingReply.value;
            }
            if (onReply) {
                onReply(value);
            }
            pendingReply.destroy();
        });
    }

    Plasma5Support.DataSource {
        id: dbusDaemonStarter
        engine: "executable"
        connectedSources: []
        Component.onCompleted: {
            // Start the DBus daemon ONCE
            let scriptPath = Qt.resolvedUrl("../desktop_actions.py").toString().replace(/^file:\/\//, "");
            connectSource("python3 '" + scriptPath + "'");
        }
    }

    // Single source of truth for the cache key: query/prefetch/_doQuery must
    // agree on it, or a prefetched entry silently misses when re-queried.
    function _buildKey(launcherUrl, appPid, showHistory, limit) {
        appPid = parseInt(appPid || 0);
        showHistory = !!showHistory;
        limit = parseInt(limit || 10);
        return String(launcherUrl) + "|" + appPid + "|" + showHistory + "|" + limit;
    }

    // Shared gate for "should browser history be requested": history only
    // makes sense for an app with a valid running-process id.
    function shouldShowHistory(appPid, enabled) {
        return !!enabled && parseInt(appPid || 0) > 0;
    }

    function query(launcherUrl, appPid, showHistory, limit, callback) {
        const key = _buildKey(launcherUrl, appPid, showHistory, limit);

        // Always do a background query to keep data fresh,
        // but if we have cache, we can return it immediately for instant UI
        if (key in cache && callback) {
            callback(cache[key]);
            // If we already have a callback, we might not want to re-trigger UI
            // but we SHOULD update the cache in background.
            _doQuery(String(launcherUrl), appPid, showHistory, limit, null);
            return;
        }

        _doQuery(String(launcherUrl), appPid, showHistory, limit, callback);
    }

    function prefetch(launcherUrl, appPid, showHistory, limit) {
        if (!launcherUrl) return;
        const key = _buildKey(launcherUrl, appPid, showHistory, limit);
        // Only prefetch if NOT in cache to avoid spam
        if (!(key in cache)) {
            _doQuery(String(launcherUrl), appPid, showHistory, limit, null);
        }
    }

    function _doQuery(launcherUrl, appPid, showHistory, limit, callback) {
        const key = _buildKey(launcherUrl, appPid, showHistory, limit);
        _call("Query", "(sbii)", [String(launcherUrl || ""), !!showHistory, parseInt(limit || 10), parseInt(appPid || 0)], value => {
            let result = {jumpList: [], recentDocs: []};
            const reply = value === undefined || value === null ? "" : String(value);
            if (reply) {
                try {
                    result = JSON.parse(reply);
                    root.cache[key] = result;
                    root.revision++;
                } catch (e) {
                    console.warn("DesktopActionsManager JSON parse error:", e, reply);
                }
            }
            // Outside the try, so errors in the callback aren't swallowed.
            if (callback) {
                callback(result);
            }
        });
    }

    // Categories from the app's .desktop file, from any cached query for
    // it; empty until one has answered (bind through revision).
    function categoriesFor(launcherUrl) {
        const prefix = String(launcherUrl) + "|";
        for (let k in cache) {
            if (k.startsWith(prefix) && cache[k].categories) {
                return cache[k].categories;
            }
        }
        return [];
    }

    function invalidate(launcherUrl) {
        if (launcherUrl) {
            const pattern = String(launcherUrl) + "|";
            // Important: we need to clean BOTH the exact key and any variations 
            // (with symbols like |true/false|limit)
            for (let k in cache) {
                if (k === String(launcherUrl) || k.startsWith(pattern)) {
                    delete cache[k];
                }
            }
        } else {
            cache = {};
        }
    }

    function clearRecentDocuments(launcherUrl) {
        _call("ClearRecent", "(s)", [String(launcherUrl || "")], () => invalidate(launcherUrl));
    }

    function launchAction(launcherUrl, actionId) {
        _call("LaunchAction", "(ss)", [String(launcherUrl || ""), String(actionId || "")]);
    }

    // callback receives "OK" or an "ERROR: ..." text.
    function exportConfig(path, content, callback) {
        _call("ExportConfig", "(ss)", [String(path || ""), String(content || "")],
              value => callback && callback(value === undefined ? "ERROR: no reply" : String(value)),
              "io.github.daydve.fancytasksng.Config");
    }

    // callback receives the file's text or an "ERROR: ..." text.
    function importConfig(path, callback) {
        _call("ImportConfig", "(s)", [String(path || "")],
              value => callback && callback(value === undefined ? "ERROR: no reply" : String(value)),
              "io.github.daydve.fancytasksng.Config");
    }

    // callback receives an object mapping each PID (as a string) to its parent
    // PID; empty while the helper is still starting up.
    function parentPids(pids, callback) {
        _call("ParentPids", "(s)", [pids.join(",")], value => {
            let result = {};
            const reply = String(value || "");
            if (reply.startsWith("{")) {
                try {
                    result = JSON.parse(reply);
                } catch (e) {
                    console.warn("DesktopActionsManager ParentPids parse error:", e, reply);
                }
            }
            if (callback) {
                callback(result);
            }
        });
    }

    // callback receives true if a tab with that title was found and the
    // browser switched to it (needs the Plasma Browser Integration extension).
    function activateBrowserTab(browserPid, title, callback) {
        _call("ActivateBrowserTab", "(is)", [parseInt(browserPid || 0), String(title || "")],
              value => callback && callback(value === true));
    }

    function openUrl(url, launcherUrl) {
        _call("OpenUrl", "(ss)", [String(url || ""), String(launcherUrl || "")]);
    }
}
