/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Labs
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kquickcontrols as KQuickAddons

import "../ui/code/singletones"

ConfigPage {
    id: advancedPage
    ConfigFormPage {
        cfg_page: advancedPage

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: advancedPage.plasmoidLocation !== PlasmaCore.Types.Floating
            type: Kirigami.MessageType.Information
            text: Wrappers.i18n("This option is disabled when the widget is on a panel.")
        }
    
        Label {
            text: Wrappers.i18n("Floating Mode Settings:")
            opacity: advancedPage.plasmoidLocation === PlasmaCore.Types.Floating ? 1.0 : 0.6
        }
    
        CheckBox {
            id: overridePlasmaButtonDirection
            text: Wrappers.i18n("Override system direction")
            enabled: advancedPage.plasmoidLocation === PlasmaCore.Types.Floating
            checked: advancedPage.cfg_overridePlasmaButtonDirection
            onToggled: advancedPage.cfg_overridePlasmaButtonDirection = checked
        }
    
        ComboBox {
            id: plasmaButtonDirection
            Layout.fillWidth: true
            enabled: overridePlasmaButtonDirection.enabled && overridePlasmaButtonDirection.checked
            visible: overridePlasmaButtonDirection.checked
            model: [
                Wrappers.i18n("As on top panel"),
                Wrappers.i18n("As on bottom panel"),
                Wrappers.i18n("As on left panel"),
                Wrappers.i18n("As on right panel")
            ]
            currentIndex: advancedPage.cfg_plasmaButtonDirection
            onActivated: (index) => advancedPage.cfg_plasmaButtonDirection = index
        }
    
        Item { height: advancedPage.largeSpacing }
    
        Label {
            text: Wrappers.i18n("When a window wants attention:")
        }

        CheckBox {
            id: cfg_unhideOnAttention
            text: Wrappers.i18n("Unhide panel when a window wants attention")
            enabled: advancedPage.plasmoidLocation !== PlasmaCore.Types.Floating
            checked: advancedPage.cfg_unhideOnAttention
            onToggled: advancedPage.cfg_unhideOnAttention = checked
        }

        CheckBox {
            id: cfg_animateAttentionStatus
            text: Wrappers.i18n("Animate task icon when a window wants attention")
            checked: advancedPage.cfg_animateAttentionStatus
            onToggled: advancedPage.cfg_animateAttentionStatus = checked
            visible: advancedPage.cfg_iconOnly === 1
        }

        RowLayout {
            spacing: advancedPage.smallSpacing

            CheckBox {
                id: cfg_attentionCustomColorEnabled
                text: Wrappers.i18n("Colorize the task button when a window wants attention")
                checked: advancedPage.cfg_attentionCustomColorEnabled
                onToggled: advancedPage.cfg_attentionCustomColorEnabled = checked
            }

            KQuickAddons.ColorButton {
                id: attentionCustomColorBtn
                visible: advancedPage.cfg_attentionCustomColorEnabled
                showAlphaChannel: true
                Layout.maximumHeight: cfg_attentionCustomColorEnabled.height
                color: advancedPage.cfg_attentionCustomColor
                onColorChanged: {
                    if (!Qt.colorEqual(color, advancedPage.cfg_attentionCustomColor)) {
                        advancedPage.cfg_attentionCustomColor = color
                    }
                }
            }
        }

        Item { height: advancedPage.largeSpacing }
    
        Label {
            text: Wrappers.i18n("Layout settings:")
            opacity: fillEnabled ? 1.0 : 0.6
    
            readonly property bool fillEnabled: advancedPage.plasmoidLocation !== PlasmaCore.Types.Floating && advancedPage.cfg_iconOnly
        }
    
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: advancedPage.plasmoidLocation === PlasmaCore.Types.Floating
            type: Kirigami.MessageType.Information
            text: Wrappers.i18n("These options are only available when the widget is on a panel.")
        }
    
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: advancedPage.plasmoidLocation !== PlasmaCore.Types.Floating && !advancedPage.cfg_iconOnly
            type: Kirigami.MessageType.Information
            text: Wrappers.i18n("These options are only available in icon-only mode.")
        }
    
        CheckBox {
            id: fill
            text: Wrappers.i18n("Fill free space on panel")
            enabled: advancedPage.plasmoidLocation !== PlasmaCore.Types.Floating && advancedPage.cfg_iconOnly
            checked: advancedPage.cfg_fill
            onToggled: advancedPage.cfg_fill = checked
        }
    
        RowLayout {
            visible: fill.checked && fill.enabled
            Item { implicitWidth: advancedPage.gridUnit }
    
            Label {
                text: Wrappers.i18n("Alignment:")
            }
            ComboBox {
                id: fillAlignment
                Layout.fillWidth: true
                model: [
                    Wrappers.i18n("Edge"),
                    Wrappers.i18n("Center")
                ]
                currentIndex: advancedPage.cfg_fillAlignment
                onActivated: (index) => advancedPage.cfg_fillAlignment = index
            }
        }
    
        Item { height: advancedPage.largeSpacing }
    
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
        return fileUrl.toString().replace(/^file:\/\//, "");
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
