/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

import "../ui/code/singletones"

// Quick setup: the most used options, each also in its own section, laid
// out like System Settings' Quick Settings. The dialog hands every page the
// current values when it opens and saves only the page that's open, so the
// copies don't get in each other's way.
ConfigPage {
    id: quickPage
    fullTitle: Wrappers.i18n("Quick Setup")

    readonly property bool iconsOnly: quickPage.cfg_iconOnly === 1
    readonly property bool onPanel: quickPage.plasmoidLocation !== PlasmaCore.Types.Floating

    // The window indicator cards are presets: picking one sets the look,
    // not just the style. It counts as picked while its style is on.
    readonly property var linePreset: ({
        cfg_indicatorsEnabled: true,
        cfg_indicatorStyle: 0,
        cfg_indicatorSize: 3,
        cfg_indicatorRadius: 100,
        cfg_indicatorShrink: 6,
        cfg_indicatorResize: false
    })
    readonly property var dashesPreset: ({
        cfg_indicatorsEnabled: true,
        cfg_indicatorStyle: 1,
        cfg_indicatorSize: 4,
        cfg_indicatorLength: 8,
        cfg_indicatorRadius: 100,
        cfg_indicatorResize: true,
        cfg_indicatorActiveSize: 4,
        cfg_indicatorActiveLength: 16,
        cfg_indicatorHoverSeparate: false,
        cfg_indicatorGroupSeparate: false
    })
    function applyPreset(preset: var): void {
        for (const key in preset)
            quickPage[key] = preset[key];
    }

    ConfigTabbedPage {
        cfg_page: quickPage
        showPreview: false
        // Each group of options has a panel of its own.
        framed: false

        ConfigTab {
            ConfigPanel {
                // --- Task buttons ---
                Kirigami.Heading {
                    level: 4
                    text: Wrappers.i18n("Display")
                }
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    PreviewCard {
                        implicitWidth: Kirigami.Units.gridUnit * 13
                        cfgPage: quickPage
                        overrides: ({ cfg_iconOnly: 1 })
                        text: Wrappers.i18n("Show icons only")
                        checked: quickPage.cfg_iconOnly === 1
                        onClicked: quickPage.cfg_iconOnly = 1
                    }
                    PreviewCard {
                        implicitWidth: Kirigami.Units.gridUnit * 13
                        cfgPage: quickPage
                        overrides: ({ cfg_iconOnly: 0 })
                        text: Wrappers.i18n("Classic panel")
                        checked: quickPage.cfg_iconOnly === 0
                        onClicked: quickPage.cfg_iconOnly = 0
                    }
                }

                Item { height: Kirigami.Units.smallSpacing }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Label {
                        text: Wrappers.i18n("Icon size:")
                    }
                    // A short slider: it's one option among many here.
                    IconSizeControl {
                        page: quickPage
                        sliderWidth: Kirigami.Units.gridUnit * 10
                    }
                }
                RowLayout {
                    spacing: Kirigami.Units.gridUnit
                    RowLayout {
                        CheckBox {
                            id: taskHoverEffect
                            enabled: quickPage.iconsOnly
                            text: Wrappers.i18n("Icon hover effects")
                            checked: quickPage.cfg_taskHoverEffect
                            onToggled: quickPage.cfg_taskHoverEffect = checked
                        }
                        ConfigHint {
                            target: taskHoverEffect
                            reason: Wrappers.i18n("Only in the icons-only mode.")
                        }
                    }
                    RowLayout {
                        CheckBox {
                            id: fill
                            enabled: quickPage.onPanel
                            text: Wrappers.i18n("Fill free space on panel")
                            checked: quickPage.cfg_fill
                            onToggled: quickPage.cfg_fill = checked
                        }
                        ConfigHint {
                            target: fill
                            reason: Wrappers.i18n("Only when the widget is on a panel.")
                        }
                    }
                }
                RowLayout {
                    SectionLink {
                        cfgPage: quickPage
                        section: "ConfigLayout.qml"
                        icon.name: "distribute-horizontal-x"
                        text: Wrappers.i18n("Task Layout")
                    }
                    SectionLink {
                        cfgPage: quickPage
                        section: "ConfigTaskStyle.qml"
                        icon.name: "preferences-desktop-color"
                        text: Wrappers.i18n("Task Styling")
                    }
                }
            }

            ConfigPanel {
                // --- Indicators and signals ---
                Kirigami.Heading {
                    level: 4
                    text: Wrappers.i18n("Window Indicators")
                }
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    PreviewCard {
                        cfgPage: quickPage
                        classicTasks: 1
                        // A highlighted classic button hides its indicator.
                        buttonBackground: quickPage.cfg_iconOnly === 1
                        overrides: quickPage.linePreset
                        text: Wrappers.i18n("Line")
                        checked: quickPage.cfg_indicatorsEnabled && quickPage.cfg_indicatorStyle === 0
                        onClicked: quickPage.applyPreset(quickPage.linePreset)
                    }
                    PreviewCard {
                        cfgPage: quickPage
                        classicTasks: 1
                        // A highlighted classic button hides its indicator.
                        buttonBackground: quickPage.cfg_iconOnly === 1
                        overrides: quickPage.dashesPreset
                        text: Wrappers.i18n("Dashes")
                        checked: quickPage.cfg_indicatorsEnabled && quickPage.cfg_indicatorStyle === 1
                        onClicked: quickPage.applyPreset(quickPage.dashesPreset)
                    }
                    PreviewCard {
                        cfgPage: quickPage
                        classicTasks: 1
                        // A highlighted classic button hides its indicator.
                        buttonBackground: quickPage.cfg_iconOnly === 1
                        overrides: ({ cfg_indicatorsEnabled: false })
                        text: Wrappers.i18nc("No window indicators", "None")
                        checked: !quickPage.cfg_indicatorsEnabled
                        onClicked: quickPage.cfg_indicatorsEnabled = false
                    }
                }
                RowLayout {
                    spacing: Kirigami.Units.gridUnit
                    RowLayout {
                        CheckBox {
                            id: useBorders
                            enabled: !quickPage.cfg_disableButtonSvg
                            text: Wrappers.i18n("Use Plasma borders")
                            checked: quickPage.cfg_useBorders
                            onToggled: quickPage.cfg_useBorders = checked
                        }
                        ConfigHint {
                            target: useBorders
                            info: Wrappers.i18n("Task buttons are drawn with the borders from the Plasma theme. In Breeze it's a stripe along the panel edge; in other themes it may look different.")
                            reason: Wrappers.i18n("Buttons have no background (Task Styling › Background).")
                        }
                    }
                    RowLayout {
                        CheckBox {
                            id: groupIconEnabled
                            enabled: quickPage.cfg_groupingStrategy === 1 && quickPage.cfg_groupPopups
                            text: Wrappers.i18n("Group overlay from the Plasma theme")
                            checked: quickPage.cfg_groupIconEnabled
                            onToggled: quickPage.cfg_groupIconEnabled = checked
                        }
                        ConfigHint {
                            target: groupIconEnabled
                            info: Wrappers.i18n("A \"+\" sign from the Plasma theme on a group button, as in the standard task manager.")
                            reason: Wrappers.i18n("Only when the windows of an application are combined into one button.")
                        }
                    }
                }
                SectionLink {
                    cfgPage: quickPage
                    section: "ConfigWindowIndicators.qml"
                    icon.name: "preferences-desktop-navigation"
                    text: Wrappers.i18n("Window Indicators")
                }
            }

            ConfigPanel {
                // --- Keyboard ---
                Kirigami.Heading {
                    level: 4
                    text: Wrappers.i18n("Keyboard")
                }
                // The picture follows the switches; it isn't a choice itself.
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    PreviewCard {
                        implicitWidth: Kirigami.Units.gridUnit * 13
                        cfgPage: quickPage
                        taskNumbers: quickPage.cfg_taskEntryShortcuts && quickPage.cfg_showTaskNumbers
                        hoverEnabled: false
                        focusPolicy: Qt.NoFocus
                        Accessible.ignored: true
                    }
                    ColumnLayout {
                        RowLayout {
                            KeyCheckBox {
                                id: quickTaskEntryShortcuts
                                keys: ["Meta", "1", "9"]
                                text: Wrappers.i18nc("%1 is Meta, %2 and %3 are 1 and 9, drawn as keys", "%1+%2…%3: activate a task")
                                checked: quickPage.cfg_taskEntryShortcuts
                                onToggled: quickPage.cfg_taskEntryShortcuts = checked
                            }
                            ConfigHint {
                                info: Wrappers.i18n("As in Plasma's task manager.")
                            }
                        }
                        RowLayout {
                            Item { implicitWidth: Kirigami.Units.gridUnit }
                            KeyCheckBox {
                                enabled: quickTaskEntryShortcuts.checked
                                keys: ["Meta"]
                                text: Wrappers.i18nc("%1 is Meta, drawn as a key", "Show task numbers while %1 is held")
                                checked: quickPage.cfg_showTaskNumbers
                                onToggled: quickPage.cfg_showTaskNumbers = checked
                            }
                        }
                    }
                }
                SectionLink {
                    cfgPage: quickPage
                    section: "ConfigTaskActions.qml"
                    icon.name: "input-keyboard"
                    text: Wrappers.i18n("Task Actions")
                }
            }

            // --- Signals, grouping and tooltips, side by side ---
            RowLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 40
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing

                ConfigPanel {
                    Layout.alignment: Qt.AlignTop
                    Layout.fillHeight: true
                    Layout.preferredWidth: implicitWidth
                    Kirigami.Heading {
                        level: 4
                        text: Wrappers.i18n("App Signals")
                    }
                    RowLayout {
                        CheckBox {
                            text: Wrappers.i18nc("App signals", "Show")
                            checked: quickPage.cfg_showAppSignals
                            onToggled: quickPage.cfg_showAppSignals = checked
                        }
                        ConfigHint {
                            info: Wrappers.i18n("Some apps send signals about audio playback, notification count and operation progress. When on, Fancy Tasks NG shows the matching indicators on the buttons of such apps.")
                        }
                    }
                    // The link to the section sits at the bottom of the panel.
                    Item { Layout.fillHeight: true }
                    SectionLink {
                        cfgPage: quickPage
                        section: "ConfigAppSignals.qml"
                        icon.name: "preferences-desktop-notification-bell"
                        text: Wrappers.i18n("App Signals")
                    }
                }

                ConfigPanel {
                    Layout.alignment: Qt.AlignTop
                    Layout.fillHeight: true
                    Layout.preferredWidth: implicitWidth
                    Kirigami.Heading {
                        level: 4
                        text: Wrappers.i18n("Grouping of tasks")
                    }
                    ButtonGroup {
                        id: groupingGroup
                    }
                    RadioButton {
                        ButtonGroup.group: groupingGroup
                        text: Wrappers.i18nc("State", "Disabled")
                        checked: quickPage.cfg_groupingStrategy === 0
                        onToggled: if (checked) quickPage.cfg_groupingStrategy = 0
                    }
                    RadioButton {
                        ButtonGroup.group: groupingGroup
                        text: Wrappers.i18n("Windows side by side")
                        checked: quickPage.cfg_groupingStrategy === 1 && !quickPage.cfg_groupPopups
                        onToggled: {
                            if (checked) {
                                quickPage.cfg_groupingStrategy = 1;
                                quickPage.cfg_groupPopups = false;
                            }
                        }
                    }
                    RadioButton {
                        ButtonGroup.group: groupingGroup
                        text: Wrappers.i18n("Combined into one button")
                        checked: quickPage.cfg_groupingStrategy === 1 && quickPage.cfg_groupPopups
                        onToggled: {
                            if (checked) {
                                quickPage.cfg_groupingStrategy = 1;
                                quickPage.cfg_groupPopups = true;
                            }
                        }
                    }
                    // The link to the section sits at the bottom of the panel.
                    Item { Layout.fillHeight: true }
                    SectionLink {
                        cfgPage: quickPage
                        section: "ConfigTaskList.qml"
                        icon.name: "view-list-details"
                        text: Wrappers.i18n("Task List")
                    }
                }

                // One choice for enableToolTips and showToolTips.
                ConfigPanel {
                    Layout.alignment: Qt.AlignTop
                    Layout.fillHeight: true
                    Layout.preferredWidth: implicitWidth
                    Kirigami.Heading {
                        level: 4
                        text: Wrappers.i18nc("Quick Setup group", "Tooltips")
                    }
                    ButtonGroup {
                        id: tooltipsGroup
                    }
                    RadioButton {
                        ButtonGroup.group: tooltipsGroup
                        text: Wrappers.i18n("Off")
                        checked: !quickPage.cfg_enableToolTips
                        onToggled: if (checked) quickPage.cfg_enableToolTips = false
                    }
                    RadioButton {
                        ButtonGroup.group: tooltipsGroup
                        text: Wrappers.i18n("Without window thumbnails")
                        checked: quickPage.cfg_enableToolTips && !quickPage.cfg_showToolTips
                        onToggled: {
                            if (checked) {
                                quickPage.cfg_enableToolTips = true;
                                quickPage.cfg_showToolTips = false;
                            }
                        }
                    }
                    RadioButton {
                        ButtonGroup.group: tooltipsGroup
                        text: Wrappers.i18n("With window thumbnails")
                        checked: quickPage.cfg_enableToolTips && quickPage.cfg_showToolTips
                        onToggled: {
                            if (checked) {
                                quickPage.cfg_enableToolTips = true;
                                quickPage.cfg_showToolTips = true;
                            }
                        }
                    }
                    // The link to the section sits at the bottom of the panel.
                    Item { Layout.fillHeight: true }
                    SectionLink {
                        cfgPage: quickPage
                        section: "ConfigTooltips.qml"
                        icon.name: "help-hint"
                        text: Wrappers.i18nc("Quick Setup group", "Tooltips")
                    }
                }
            }
        }
    }
}
