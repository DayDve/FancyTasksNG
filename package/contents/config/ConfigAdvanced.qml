/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import "../ui/code/singletones"

ConfigPage {
    id: advancedPage
    ConfigTabbedPage {
        cfg_page: advancedPage
        // Nothing here changes the task buttons.
        showPreview: false

        ConfigTab {
            Label {
                text: Wrappers.i18n("Configuration:")
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Button {
                    text: Wrappers.i18n("Export Configuration…")
                    icon.name: "document-export"
                    onClicked: exportFileDialog.open()
                }

                Button {
                    text: Wrappers.i18n("Import Configuration…")
                    icon.name: "document-import"
                    onClicked: importFileDialog.open()
                }
            }

            Label {
                id: configIoStatusLabel
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: text.length > 0
                color: configIoIsError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor

                property bool configIoIsError: false
            }

            FileDialog {
                id: exportFileDialog
                title: Wrappers.i18n("Export Fancy Tasks NG Configuration")
                fileMode: FileDialog.SaveFile
                // A zip: the settings and the icons of the icon replacements.
                nameFilters: [Wrappers.i18n("Fancy Tasks NG settings (*.zip)")]
                defaultSuffix: "zip"
                onAccepted: advancedPage.exportConfig(exportFileDialog.selectedFile)
            }

            FileDialog {
                id: importFileDialog
                title: Wrappers.i18n("Import Fancy Tasks NG Configuration")
                fileMode: FileDialog.OpenFile
                // .json: exported before the icons came along.
                nameFilters: [Wrappers.i18n("Fancy Tasks NG settings (*.zip *.json)")]
                onAccepted: advancedPage.importConfig(importFileDialog.selectedFile)
            }
        }
    }

    readonly property string configAppId: "io.github.daydve.fancytasksng"

    function toLocalPath(fileUrl) {
        // File dialogs return percent-encoded URLs ("My%20Files", Cyrillic).
        return decodeURIComponent(fileUrl.toString().replace(/^file:\/\//, ""));
    }

    function showConfigIoStatus(text, isError) {
        configIoStatusLabel.text = text;
        configIoStatusLabel.configIoIsError = isError;
    }

    function collectConfigForExport() {
        const settings = {};
        const keys = Object.keys(advancedPage.plasmoidConfiguration);
        for (const key of keys) {
            if (key === "expanding" || key === "length") continue;
            const propName = "cfg_" + key;
            if (!(propName in advancedPage)) continue;
            settings[key] = advancedPage[propName];
        }
        // 2: exported as a zip with the icons of the icon replacements (the
        // helper adds them); 1, a plain .json, is still imported.
        return { app: advancedPage.configAppId, version: 2, settings: settings };
    }

    function exportConfig(fileUrl) {
        const path = advancedPage.toLocalPath(fileUrl);
        const payload = JSON.stringify(advancedPage.collectConfigForExport(), null, 2);
        configIoStatusLabel.text = "";
        DesktopActionsManager.exportConfig(path, payload, (result) => {
            if (result === "OK") {
                advancedPage.showConfigIoStatus(Wrappers.i18n("Configuration exported successfully."), false);
            } else {
                advancedPage.showConfigIoStatus(Wrappers.i18n("Failed to export configuration."), true);
            }
        });
    }

    function importConfig(fileUrl) {
        const path = advancedPage.toLocalPath(fileUrl);
        configIoStatusLabel.text = "";
        DesktopActionsManager.importConfig(path, (result) => {
            if (result.startsWith("ERROR:")) {
                advancedPage.showConfigIoStatus(Wrappers.i18n("Failed to read the configuration file."), true);
                return;
            }
            let parsed;
            try {
                parsed = JSON.parse(result);
            } catch (e) {
                parsed = null;
            }
            if (!parsed || parsed.app !== advancedPage.configAppId || typeof parsed.settings !== "object") {
                advancedPage.showConfigIoStatus(Wrappers.i18n("This file is not a valid Fancy Tasks NG configuration."), true);
                return;
            }
            DesktopActionsManager.settingsSections(sections => importDialog.ask(path, parsed, sections));
        });
    }

    // The sections as the sidebar names them, the icon replacements apart.
    readonly property var sectionNames: ({
        ConfigLayout: Wrappers.i18nc("Short section name in the settings sidebar", "Task Layout"),
        ConfigTaskStyle: Wrappers.i18nc("Short section name in the settings sidebar", "Task Styling"),
        ConfigWindowIndicators: Wrappers.i18nc("Short section name in the settings sidebar", "Window Indicators"),
        ConfigAppSignals: Wrappers.i18nc("Short section name in the settings sidebar", "App Signals"),
        ConfigTaskList: Wrappers.i18nc("Short section name in the settings sidebar", "Task List"),
        ConfigTaskActions: Wrappers.i18nc("Short section name in the settings sidebar", "Task Actions"),
        ConfigTooltips: Wrappers.i18nc("Short section name in the settings sidebar", "Task Tooltips"),
        ConfigContextMenu: Wrappers.i18nc("Short section name in the settings sidebar", "Context Menu"),
        ConfigAdvanced: Wrappers.i18n("Advanced"),
        ConfigPinnedApps: Wrappers.i18nc("Short section name in the settings sidebar", "Pinned Applications"),
        iconReplacements: Wrappers.i18n("Icon Replacements")
    })

    // What to import: the sections the file has settings of, each with a
    // checkbox; for the icon replacements, how their icons come in.
    Kirigami.Dialog {
        id: importDialog
        property string path
        property var payload: null
        property var keySections: ({})
        // [{ page, name, count, checked }]
        property var entries: []

        function ask(path: string, payload: var, sections: var): void {
            importDialog.path = path;
            importDialog.payload = payload;
            importDialog.keySections = sections.keys || {};
            const counts = {};
            for (const key of Object.keys(payload.settings)) {
                if (key === "expanding" || key === "length" || !(("cfg_" + key) in advancedPage))
                    continue;
                if (key === "iconReplacements") {
                    const n = Object.keys(JSON.parse(payload.settings[key] || "{}")).length;
                    if (n > 0)
                        counts.iconReplacements = n;
                    continue;
                }
                const page = importDialog.keySections[key] || "ConfigAdvanced";
                counts[page] = (counts[page] || 0) + 1;
            }
            const order = (sections.pages || []).length > 0 ? sections.pages : Object.keys(advancedPage.sectionNames);
            importDialog.entries = order.filter(page => counts[page] > 0)
                .map(page => ({ page: page, name: advancedPage.sectionNames[page] || page, count: counts[page], checked: true }));
            importDialog.open();
        }
        function isChecked(page: string): bool {
            return importDialog.entries.some(entry => entry.page === page && entry.checked);
        }

        title: Wrappers.i18n("Import Settings")
        padding: Kirigami.Units.largeSpacing
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: Wrappers.i18nc("Import the chosen settings", "Import")
                icon.name: "document-import"
                enabled: importDialog.entries.some(entry => entry.checked)
                onTriggered: {
                    advancedPage.applyImport();
                    importDialog.close();
                }
            }
        ]

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            Label {
                text: Wrappers.i18n("Import from this file:")
            }
            Repeater {
                model: importDialog.entries
                CheckBox {
                    required property var modelData
                    required property int index
                    text: modelData.page === "iconReplacements"
                        ? Wrappers.i18np("%2 (%1 app)", "%2 (%1 apps)", modelData.count, modelData.name)
                        : modelData.name
                    checked: modelData.checked
                    onToggled: {
                        const entries = importDialog.entries.slice();
                        entries[index] = Object.assign({}, entries[index], { checked: checked });
                        importDialog.entries = entries;
                    }
                }
            }
            IconImportOptions {
                id: iconImportOptions
                visible: importDialog.isChecked("iconReplacements")
                Layout.leftMargin: Kirigami.Units.gridUnit
            }
        }
    }

    function applyImport() {
        const payload = importDialog.payload;
        for (const key of Object.keys(payload.settings)) {
            if (key === "expanding" || key === "length" || key === "iconReplacements")
                continue;
            const propName = "cfg_" + key;
            if (propName in advancedPage && importDialog.isChecked(importDialog.keySections[key] || "ConfigAdvanced"))
                advancedPage[propName] = payload.settings[key];
        }
        if (!importDialog.isChecked("iconReplacements")) {
            advancedPage.showConfigIoStatus(Wrappers.i18n("Configuration imported. Click Apply to save the changes."), false);
            return;
        }
        const add = iconImportOptions.addToCurrent;
        DesktopActionsManager.importIcons(importDialog.path, iconImportOptions.themeMode, text => {
            let map;
            try {
                map = JSON.parse(text);
            } catch (e) {
                advancedPage.showConfigIoStatus(Wrappers.i18n("Failed to import the icon replacements."), true);
                return;
            }
            let current = {};
            try {
                current = JSON.parse(advancedPage.cfg_iconReplacements || "{}");
            } catch (e) {
                current = {};
            }
            const merged = add ? Object.assign(current, map) : map;
            advancedPage.cfg_iconReplacements = Object.keys(merged).length > 0 ? JSON.stringify(merged) : "";
            advancedPage.showConfigIoStatus(Wrappers.i18n("Configuration imported. Click Apply to save the changes."), false);
        });
    }
}
