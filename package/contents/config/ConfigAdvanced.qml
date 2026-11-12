/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Labs

import "../ui/code/singletones"

ConfigPage {
    id: advancedPage
    ConfigFormPage {
        cfg_page: advancedPage

    
        Label {
            text: Wrappers.i18n("Context menu:")
        }
    
        CheckBox {
            id: cfg_hideMoveToDesktopMenuWithOneDesktop
            text: Wrappers.i18n("Hide 'Move to Desktop' if only one virtual desktop is used")
            checked: advancedPage.cfg_hideMoveToDesktopMenuWithOneDesktop
            onToggled: advancedPage.cfg_hideMoveToDesktopMenuWithOneDesktop = checked
    
            Layout.fillWidth: true
    
            contentItem: Text {
                text: cfg_hideMoveToDesktopMenuWithOneDesktop.text
                font: cfg_hideMoveToDesktopMenuWithOneDesktop.font
                color: advancedPage.themeTextColor
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
                leftPadding: cfg_hideMoveToDesktopMenuWithOneDesktop.indicator.width + cfg_hideMoveToDesktopMenuWithOneDesktop.spacing
            }
        }
    
        CheckBox {
            id: cfg_showBrowserHistory
            text: Wrappers.i18n("Show browsing history in the context menu of web browsers (Experimental)")
            checked: advancedPage.cfg_showBrowserHistory
            onToggled: advancedPage.cfg_showBrowserHistory = checked
    
            Layout.fillWidth: true
    
            contentItem: Text {
                text: cfg_showBrowserHistory.text
                font: cfg_showBrowserHistory.font
                color: advancedPage.themeTextColor
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
                leftPadding: cfg_showBrowserHistory.indicator.width + cfg_showBrowserHistory.spacing
            }
        }
    
        RowLayout {
            visible: cfg_showBrowserHistory.checked
            Item { implicitWidth: advancedPage.gridUnit }
            Label {
                text: Wrappers.i18n("Number of browser history items:")
            }
            SpinBox {
                id: cfg_browserHistoryLimit
                from: 1
                to: 50
                value: advancedPage.cfg_browserHistoryLimit
                onValueModified: advancedPage.cfg_browserHistoryLimit = value
            }
        }

        Item { height: advancedPage.largeSpacing }

        Label {
            text: Wrappers.i18n("Configuration:")
        }

        RowLayout {
            spacing: advancedPage.smallSpacing

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
            color: configIoIsError ? advancedPage.themeNegativeTextColor : advancedPage.themeTextColor

            property bool configIoIsError: false
        }

        Labs.FileDialog {
            id: exportFileDialog
            title: Wrappers.i18n("Export FancyTasksNG Configuration")
            fileMode: Labs.FileDialog.SaveFile
            nameFilters: [Wrappers.i18n("JSON files (*.json)")]
            defaultSuffix: "json"
            onAccepted: advancedPage.exportConfig(exportFileDialog.file)
        }

        Labs.FileDialog {
            id: importFileDialog
            title: Wrappers.i18n("Import FancyTasksNG Configuration")
            fileMode: Labs.FileDialog.OpenFile
            nameFilters: [Wrappers.i18n("JSON files (*.json)")]
            onAccepted: advancedPage.importConfig(importFileDialog.file)
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
        return { app: advancedPage.configAppId, version: 1, settings: settings };
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
            try {
                advancedPage.applyImportedSettings(JSON.parse(result));
            } catch (e) {
                advancedPage.showConfigIoStatus(Wrappers.i18n("This file is not a valid FancyTasksNG configuration."), true);
            }
        });
    }

    function applyImportedSettings(parsed) {
        if (!parsed || parsed.app !== advancedPage.configAppId || typeof parsed.settings !== "object") {
            advancedPage.showConfigIoStatus(Wrappers.i18n("This file is not a valid FancyTasksNG configuration."), true);
            return;
        }
        const keys = Object.keys(parsed.settings);
        for (const key of keys) {
            const propName = "cfg_" + key;
            if (propName in advancedPage) {
                advancedPage[propName] = parsed.settings[key];
            }
        }
        advancedPage.showConfigIoStatus(Wrappers.i18n("Configuration imported. Click Apply to save the changes."), false);
    }
}
