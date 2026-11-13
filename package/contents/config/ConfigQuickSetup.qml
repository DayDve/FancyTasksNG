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

        ConfigTab {
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

            // The size in the unit chosen under Task Layout › Buttons. A
            // short slider: it's one option among many here.
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                readonly property bool absolute: quickPage.cfg_iconSizeOverride

                Label {
                    text: Wrappers.i18n("Icon size:")
                }
                // No stepSize: with it the style draws a tick per step.
                Slider {
                    id: iconSize
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    from: 0
                    to: parent.absolute ? 100 : 300
                    value: parent.absolute ? quickPage.cfg_iconSizePx : quickPage.cfg_iconScale
                    onMoved: {
                        if (parent.absolute)
                            quickPage.cfg_iconSizePx = Math.round(value);
                        else
                            quickPage.cfg_iconScale = Math.round(value);
                    }
                }
                SpinBox {
                    from: 0
                    to: parent.absolute ? 100 : 300
                    editable: true
                    value: Math.round(iconSize.value)
                    onValueModified: {
                        if (parent.absolute)
                            quickPage.cfg_iconSizePx = value;
                        else
                            quickPage.cfg_iconScale = value;
                    }
                }
                Label {
                    Layout.minimumWidth: unitMetrics.advanceWidth
                    text: parent.absolute ? "px" : "%"
                    TextMetrics {
                        id: unitMetrics
                        text: "px"
                    }
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

            Kirigami.Separator {
                Layout.fillWidth: true
            }

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
            SectionLink {
                cfgPage: quickPage
                section: "ConfigWindowIndicators.qml"
                icon.name: "preferences-desktop-navigation"
                text: Wrappers.i18n("Window Indicators")
            }

            Item { height: Kirigami.Units.smallSpacing }

            Kirigami.Heading {
                level: 4
                text: Wrappers.i18n("App Signals")
            }
            RowLayout {
                CheckBox {
                    text: Wrappers.i18n("Show app signals")
                    checked: quickPage.cfg_showAppSignals
                    onToggled: quickPage.cfg_showAppSignals = checked
                }
                ConfigHint {
                    info: Wrappers.i18n("Some apps send signals about audio playback, notification count and operation progress. When on, Fancy Tasks NG receives these signals and shows the matching indicators on the buttons of such apps.")
                }
            }
            SectionLink {
                cfgPage: quickPage
                section: "ConfigAppSignals.qml"
                icon.name: "preferences-desktop-notification-bell"
                text: Wrappers.i18n("App Signals")
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            // --- Task list and tooltips, side by side ---
            RowLayout {
                spacing: Kirigami.Units.gridUnit * 2

                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
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
                    SectionLink {
                        cfgPage: quickPage
                        section: "ConfigTaskList.qml"
                        icon.name: "view-list-details"
                        text: Wrappers.i18n("Task List")
                    }
                }

                // One choice for enableToolTips and showToolTips.
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    Kirigami.Heading {
                        level: 4
                        text: Wrappers.i18n("Task Tooltips")
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
                    SectionLink {
                        cfgPage: quickPage
                        section: "ConfigTooltips.qml"
                        icon.name: "help-hint"
                        text: Wrappers.i18n("Task Tooltips")
                    }
                }
            }
        }
    }
}
