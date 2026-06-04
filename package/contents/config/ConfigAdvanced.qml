/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../ui/code/singletones"

ConfigPage {
    id: advancedPage

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        LivePreview {
            cfg_page: cfg_page
            location: Plasmoid.location
            Layout.fillWidth: true
            visible: Plasmoid.location !== PlasmaCore.Types.Floating
        }

        ConfigScrollView {

            Kirigami.FormLayout {
                width: parent.width - Kirigami.Units.gridUnit * 2
                
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: Plasmoid.location !== PlasmaCore.Types.Floating
                    type: Kirigami.MessageType.Information
                    text: Wrappers.i18n("This option is disabled when the widget is on a panel.")
                }

                Label {
                    text: Wrappers.i18n("Floating Mode Settings:")
                    opacity: Plasmoid.location === PlasmaCore.Types.Floating ? 1.0 : 0.6
                }

                CheckBox {
                    id: overridePlasmaButtonDirection
                    text: Wrappers.i18n("Override system direction")
                    enabled: Plasmoid.location === PlasmaCore.Types.Floating
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

                Item { height: Kirigami.Units.largeSpacing }

                Label {
                    text: Wrappers.i18n("Panel Settings:")
                    opacity: panelSettingsEnabled ? 1.0 : 0.6

                    readonly property bool panelSettingsEnabled: Plasmoid.location !== PlasmaCore.Types.Floating
                }

                CheckBox {
                    id: cfg_unhideOnAttention
                    text: Wrappers.i18n("Unhide panel when a window wants attention")
                    enabled: Plasmoid.location !== PlasmaCore.Types.Floating
                    checked: advancedPage.cfg_unhideOnAttention
                    onToggled: advancedPage.cfg_unhideOnAttention = checked
                }

                CheckBox {
                    id: cfg_animateAttentionStatus
                    text: Wrappers.i18n("Animate task icon when a window wants attention")
                    enabled: Plasmoid.location !== PlasmaCore.Types.Floating
                    checked: advancedPage.cfg_animateAttentionStatus
                    onToggled: advancedPage.cfg_animateAttentionStatus = checked
                    visible: advancedPage.cfg_iconOnly === 1
                }

                Item { height: Kirigami.Units.largeSpacing }

                Label {
                    text: Wrappers.i18n("Layout settings:")
                    opacity: fillEnabled ? 1.0 : 0.6

                    readonly property bool fillEnabled: Plasmoid.location !== PlasmaCore.Types.Floating && advancedPage.cfg_iconOnly
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: Plasmoid.location === PlasmaCore.Types.Floating
                    type: Kirigami.MessageType.Information
                    text: Wrappers.i18n("These options are only available when the widget is on a panel.")
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: Plasmoid.location !== PlasmaCore.Types.Floating && !advancedPage.cfg_iconOnly
                    type: Kirigami.MessageType.Information
                    text: Wrappers.i18n("These options are only available in icon-only mode.")
                }

                CheckBox {
                    id: fill
                    text: Wrappers.i18n("Fill free space on panel")
                    enabled: Plasmoid.location !== PlasmaCore.Types.Floating && advancedPage.cfg_iconOnly
                    checked: advancedPage.cfg_fill
                    onToggled: advancedPage.cfg_fill = checked
                }

                RowLayout {
                    visible: fill.checked && fill.enabled
                    Item { implicitWidth: Kirigami.Units.gridUnit }

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

                Item { height: Kirigami.Units.largeSpacing }

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
                        color: Kirigami.Theme.textColor
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
                        color: Kirigami.Theme.textColor
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: cfg_showBrowserHistory.indicator.width + cfg_showBrowserHistory.spacing
                    }
                }

                RowLayout {
                    visible: cfg_showBrowserHistory.checked
                    Item { implicitWidth: Kirigami.Units.gridUnit }
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
            } // FormLayout
        } // ConfigScrollView
    } // ColumnLayout
}
