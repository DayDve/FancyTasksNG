/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.iconthemes as KIconThemes

import "../ui/code/singletones"
import "../ui/code/tools.js" as TaskTools

// Icon replacements (Task Styling): the pinned apps, the running ones and
// the other replaced apps, each with its own icon and its replacement, set
// with a click, removed with ×. Keys as in TaskTools.iconReplacementKey().
ColumnLayout {
    id: list

    // The settings page: cfg_iconReplacements, cfg_launchers.
    required property var page

    Layout.fillWidth: true
    // As wide as the panels get (a layout works out its own implicit width
    // from the rows, too narrow here).
    Layout.preferredWidth: Kirigami.Units.gridUnit * 40
    Layout.maximumWidth: Kirigami.Units.gridUnit * 40
    spacing: Kirigami.Units.largeSpacing

    readonly property var replacements: TaskTools.parseIconReplacements(list.page.cfg_iconReplacements)

    function setReplacement(key: string, icon: string): void {
        const map = Object.assign({}, list.replacements);
        if (icon)
            map[key] = icon;
        else
            delete map[key];
        list.page.cfg_iconReplacements = Object.keys(map).length > 0 ? JSON.stringify(map) : "";
    }

    // "applications:<id>" -> {name, icon}, for the replaced apps that are
    // neither pinned nor running; and the apps shown in menus, for "Add
    // Replacement…".
    property var apps: ({})
    property var appList: []
    Component.onCompleted: DesktopActionsManager.listApps(apps => {
        const map = {};
        const shown = [];
        for (const app of apps) {
            const key = "applications:" + app.id;
            map[key] = { name: app.name, icon: app.icon };
            if (app.display)
                shown.push({ key: key, name: app.name, icon: app.icon, search: (app.name + " " + app.id + " " + app.keywords.join(" ")).toLowerCase() });
        }
        list.apps = map;
        list.appList = shown;
    })

    // The pinned apps (a default app's launcher resolves to the app it
    // opens now) and every window, one row each.
    TaskManager.TasksModel {
        id: tasksModel
        launcherList: list.page.cfg_launchers
        separateLaunchers: true
        hideActivatedLaunchers: false
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    component Entry: QtObject {
        required property var model
        readonly property string key: TaskTools.iconReplacementKey(model)
        readonly property bool isLauncher: model.IsLauncher === true
        readonly property bool isWindow: model.IsWindow === true
        readonly property string name: String(model.AppName || model.display || "")
        readonly property var icon: model.decoration
        onKeyChanged: rebuild.restart()
        onNameChanged: rebuild.restart()
    }
    Instantiator {
        id: tasks
        model: tasksModel
        delegate: Entry {}
        onObjectAdded: rebuild.restart()
        onObjectRemoved: rebuild.restart()
    }
    Timer {
        id: rebuild
        interval: 0
        onTriggered: list.buildRows()
    }
    onReplacementsChanged: rebuild.restart()
    onAppsChanged: rebuild.restart()

    function classLabel(key: string): string {
        return key.startsWith("wmclass:") ? Wrappers.i18nc("%1 is a window class", "window class: %1", key.substring(8)) : "";
    }

    // [{ section ("pinned", "running", "others"), key, name, sub, icon,
    // running }], in groups.
    property var rows: []
    function buildRows(): void {
        const objects = [];
        for (let i = 0; i < tasks.count; i++) {
            const object = tasks.objectAt(i) as Entry;
            if (object && object.key)
                objects.push(object);
        }
        const windowKeys = new Set(objects.filter(o => o.isWindow).map(o => o.key));
        const rows = [];
        const seen = new Set();
        const add = (section, object, running) => {
            seen.add(object.key);
            rows.push({ section: section, key: object.key, name: object.name || object.key,
                        sub: list.classLabel(object.key), icon: object.icon, running: running });
        };
        for (const object of objects) {
            if (object.isLauncher && !seen.has(object.key))
                add("pinned", object, windowKeys.has(object.key));
        }
        // Not Plasma's own windows (this settings window, for one): a
        // replacement set from a task's Shift menu shows under Others.
        for (const object of objects) {
            if (object.isWindow && !seen.has(object.key) && object.key !== "applications:org.kde.plasmashell.desktop")
                add("running", object, false);
        }
        for (const key of Object.keys(list.replacements)) {
            if (seen.has(key))
                continue;
            const app = list.apps[key];
            rows.push({ section: "others", key: key,
                        name: app ? app.name : key.replace(/^(applications:|wmclass:)/, ""),
                        sub: list.classLabel(key), icon: app ? app.icon : "application-x-executable", running: false });
        }
        list.rows = rows;
    }

    KIconThemes.IconDialog {
        id: iconDialog
        property string key
        onAccepted: {
            const key = iconDialog.key;
            const name = iconDialog.iconName;
            if (!name)
                return;
            if (name.startsWith("/"))
                DesktopActionsManager.storeIcon(name, url => list.setReplacement(key, url || "file://" + name));
            else
                list.setReplacement(key, name);
        }
    }
    function pickIcon(key: string): void {
        iconDialog.key = key;
        iconDialog.open();
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 40
        Layout.alignment: Qt.AlignHCenter
        Button {
            icon.name: "list-add"
            text: Wrappers.i18n("Add Replacement…")
            onClicked: {
                appSearch.text = "";
                appSearch.open();
            }
        }
        Item { Layout.fillWidth: true }
        Button {
            visible: Object.keys(list.replacements).length > 0
            icon.name: "edit-clear-all"
            text: Wrappers.i18n("Remove All Replacements")
            onClicked: removeAllPrompt.open()
        }
    }

    // Any installed app, for one neither pinned nor running.
    Kirigami.SearchDialog {
        id: appSearch
        searchFieldPlaceholderText: Wrappers.i18n("Search…")
        model: {
            const text = appSearch.text.trim().toLowerCase();
            return text ? list.appList.filter(app => app.search.includes(text)) : list.appList;
        }
        delegate: ItemDelegate {
            required property var modelData
            width: ListView.view.width
            icon.name: typeof modelData.icon === "string" ? modelData.icon : ""
            text: modelData.name
            onClicked: {
                appSearch.close();
                list.pickIcon(modelData.key);
            }
        }
    }

    Kirigami.PromptDialog {
        id: removeAllPrompt
        title: Wrappers.i18n("Remove All Replacements")
        subtitle: Wrappers.i18np("Remove %1 icon replacement?", "Remove all %1 icon replacements?", Object.keys(list.replacements).length)
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: Wrappers.i18nc("Remove all icon replacements", "Remove")
                icon.name: "edit-clear-all"
                onTriggered: {
                    list.page.cfg_iconReplacements = "";
                    removeAllPrompt.close();
                }
            }
        ]
    }

    // Pinned and running side by side, the others below them, each on a
    // panel of its own (as on Quick Setup); an empty group isn't shown.
    RowLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 40
        Layout.alignment: Qt.AlignHCenter
        spacing: Kirigami.Units.largeSpacing
        Group {
            section: "pinned"
            title: Wrappers.i18nc("Icon replacements group", "Pinned")
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 1
        }
        Group {
            section: "running"
            title: Wrappers.i18nc("Icon replacements group", "Running")
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 1
        }
    }
    Group {
        section: "others"
        title: Wrappers.i18nc("Icon replacements group", "Others")
    }

    component Group: ConfigPanel {
        id: group
        property string section
        property string title
        readonly property var rows: list.rows.filter(row => row.section === group.section)
        visible: rows.length > 0
        Kirigami.Heading {
            level: 4
            text: group.title
        }
        Repeater {
            model: group.rows
            Row {}
        }
    }

    component Row: RowLayout {
        id: row
        required property var modelData
        readonly property string replacement: list.replacements[row.modelData.key] || ""
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        // The key, for two rows that look the same.
        HoverHandler { id: rowHover }
        ToolTip.text: row.modelData.key
        ToolTip.visible: rowHover.hovered
        ToolTip.delay: Kirigami.Units.toolTipDelay

        Kirigami.Icon {
            implicitWidth: Kirigami.Units.iconSizes.medium
            implicitHeight: Kirigami.Units.iconSizes.medium
            source: row.modelData.icon
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: row.modelData.running
                    ? Wrappers.i18nc("%1 is an app name; the dot marks a running app", "%1 ●", row.modelData.name)
                    : row.modelData.name
            }
            Label {
                visible: row.modelData.sub !== ""
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: row.modelData.sub
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }
        Kirigami.Icon {
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            source: "go-next-symbolic"
            opacity: 0.6
        }
        Button {
            flat: true
            implicitWidth: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing
            implicitHeight: implicitWidth
            icon.name: row.replacement !== "" ? "" : "list-add"
            display: AbstractButton.IconOnly
            text: row.replacement !== "" ? Wrappers.i18n("Change Icon…") : Wrappers.i18n("Add Replacement…")
            ToolTip.text: text
            ToolTip.visible: hovered
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: list.pickIcon(row.modelData.key)
            Kirigami.Icon {
                visible: row.replacement !== ""
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.medium
                height: width
                source: row.replacement
            }
        }
        ToolButton {
            opacity: row.replacement !== "" ? 1 : 0
            enabled: row.replacement !== ""
            icon.name: "edit-delete-remove"
            display: AbstractButton.IconOnly
            text: Wrappers.i18n("Remove Replacement")
            ToolTip.text: text
            ToolTip.visible: hovered
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: list.setReplacement(row.modelData.key, "")
        }
    }
}
