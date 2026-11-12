/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kquickcontrols as KQuickAddons

import "../ui/code/singletones"

// Window indicators: Fancy Tasks NG's own indicators, plus the two marks the
// Plasma theme draws. Any combination of the three is valid.
ConfigPage {
    id: indicatorsPage
    fullTitle: Wrappers.i18n("Window Indicators")

    readonly property bool isLineStyle: indicatorsPage.cfg_indicatorStyle === 0
    readonly property string offReason: Wrappers.i18n("Fancy Tasks NG indicators are turned off.")


    ConfigTabbedPage {
        cfg_page: indicatorsPage

        header: Kirigami.FormLayout {
            CheckBox {
                text: Wrappers.i18n("Fancy Tasks NG indicators")
                checked: indicatorsPage.cfg_indicatorsEnabled
                onToggled: indicatorsPage.cfg_indicatorsEnabled = checked
            }
            RowLayout {
                CheckBox {
                    id: useBorders
                    // The stripe is the edge of the button background.
                    enabled: !indicatorsPage.cfg_disableButtonSvg
                    text: Wrappers.i18n("Use Plasma borders")
                    checked: indicatorsPage.cfg_useBorders
                    onToggled: indicatorsPage.cfg_useBorders = checked
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
                    enabled: indicatorsPage.cfg_groupingStrategy === 1 && indicatorsPage.cfg_groupPopups
                    text: Wrappers.i18n("Group overlay from the Plasma theme")
                    checked: indicatorsPage.cfg_groupIconEnabled
                    onToggled: indicatorsPage.cfg_groupIconEnabled = checked
                }
                ConfigHint {
                    target: groupIconEnabled
                    info: Wrappers.i18n("A \"+\" sign from the Plasma theme on a group button, as in the standard task manager.")
                    reason: Wrappers.i18n("Only when the windows of an application are combined into one button.")
                }
            }
        }

        ConfigTab {
            title: Wrappers.i18n("Look")
            iconName: "games-config-theme"
            available: indicatorsPage.cfg_indicatorsEnabled
            unavailableReason: indicatorsPage.offReason

            CheckBox {
                text: Wrappers.i18n("Animate indicators")
                checked: indicatorsPage.cfg_indicatorsAnimated
                onToggled: indicatorsPage.cfg_indicatorsAnimated = checked
            }

            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Label {
                    text: Wrappers.i18n("Style:")
                }
                ComboBox {
                    Layout.fillWidth: true
                    model: [Wrappers.i18n("Line"), Wrappers.i18n("Dashes")]
                    currentIndex: indicatorsPage.cfg_indicatorStyle
                    onActivated: (index) => indicatorsPage.cfg_indicatorStyle = index
                }
            }

            CheckBox {
                id: indicatorOverride
                text: Wrappers.i18n("Override indicator location")
                checked: indicatorsPage.cfg_indicatorOverride
                onToggled: indicatorsPage.cfg_indicatorOverride = checked
            }
            RowLayout {
                ComboBox {
                    id: indicatorLocation
                    Layout.fillWidth: true
                    enabled: indicatorOverride.checked
                    model: [
                        Wrappers.i18n("Bottom"),
                        Wrappers.i18n("Left"),
                        Wrappers.i18n("Right"),
                        Wrappers.i18n("Top")
                    ]
                    currentIndex: indicatorsPage.cfg_indicatorLocation
                    onActivated: (index) => indicatorsPage.cfg_indicatorLocation = index
                }
            }

            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Label {
                    text: Wrappers.i18n("Edge offset:")
                }
                SpinBox {
                    from: 0
                    to: 999
                    value: indicatorsPage.cfg_indicatorEdgeOffset
                    onValueModified: indicatorsPage.cfg_indicatorEdgeOffset = value
                }
                Label {
                    text: "px"
                }
            }

            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Label {
                    text: Wrappers.i18n("Roundness:")
                }
                SpinBox {
                    from: 0
                    to: 100
                    value: indicatorsPage.cfg_indicatorRadius
                    onValueModified: indicatorsPage.cfg_indicatorRadius = value
                }
                Label {
                    text: "%"
                }
            }

            Item { height: indicatorsPage.largeSpacing }

            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Label {
                    text: Wrappers.i18n("Max segments:")
                }
                SpinBox {
                    from: 1
                    to: 99
                    value: indicatorsPage.cfg_indicatorMaxLimit
                    onValueModified: indicatorsPage.cfg_indicatorMaxLimit = value
                }
            }
            CheckBox {
                text: Wrappers.i18n("Show '+' on overflow")
                checked: indicatorsPage.cfg_indicatorShowPlus
                onToggled: indicatorsPage.cfg_indicatorShowPlus = checked
            }
        }

        ConfigTab {
            id: sizeTab
            title: Wrappers.i18n("Size")
            iconName: "transform-scale"
            available: indicatorsPage.cfg_indicatorsEnabled
            unavailableReason: indicatorsPage.offReason

            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Label {
                    text: Wrappers.i18n("Thickness:")
                }
                SpinBox {
                    from: 1
                    to: 999
                    value: indicatorsPage.cfg_indicatorSize
                    onValueModified: indicatorsPage.cfg_indicatorSize = value
                }
                Label {
                    text: "px"
                }
                Item { implicitWidth: indicatorsPage.largeSpacing }
                Label {
                    text: Wrappers.i18n("Segment length:")
                }
                SpinBox {
                    from: 1
                    to: 999
                    value: indicatorsPage.cfg_indicatorLength
                    onValueModified: indicatorsPage.cfg_indicatorLength = value
                }
                Label {
                    text: "px"
                }
            }

            RowLayout {
                spacing: indicatorsPage.smallSpacing
                RowLayout {
                    id: indicatorShrink
                    enabled: indicatorsPage.isLineStyle
                    spacing: indicatorsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Side padding:")
                    }
                    SpinBox {
                        from: 0
                        to: 999
                        value: indicatorsPage.cfg_indicatorShrink
                        onValueModified: indicatorsPage.cfg_indicatorShrink = value
                    }
                    Label {
                        text: "px"
                    }
                }
                ConfigHint {
                    target: indicatorShrink
                    reason: Wrappers.i18n("Only for the Line style.")
                }
            }

            Item { height: indicatorsPage.largeSpacing }

            CheckBox {
                id: indicatorResize
                text: Wrappers.i18n("Resize the indicator when its window is active or hovered")
                checked: indicatorsPage.cfg_indicatorResize
                onToggled: indicatorsPage.cfg_indicatorResize = checked
            }


            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Item { implicitWidth: indicatorsPage.gridUnit }
                RowLayout {
                    id: activeSize
                    enabled: indicatorResize.checked
                    spacing: indicatorsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Thickness:")
                    }
                    SpinBox {
                        from: 1
                        to: 999
                        value: indicatorsPage.cfg_indicatorActiveSize
                        onValueModified: indicatorsPage.cfg_indicatorActiveSize = value
                    }
                    Label {
                        text: "px"
                    }
                    Item { implicitWidth: indicatorsPage.largeSpacing }
                    Label {
                        text: Wrappers.i18n("Length:")
                    }
                    SpinBox {
                        from: 1
                        to: 999
                        value: indicatorsPage.cfg_indicatorActiveLength
                        onValueModified: indicatorsPage.cfg_indicatorActiveLength = value
                    }
                    Label {
                        text: "px"
                    }
                }
            }

            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Item { implicitWidth: indicatorsPage.gridUnit }
                RowLayout {
                    id: indicatorAlignment
                    enabled: indicatorResize.checked
                    spacing: indicatorsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Segment alignment:")
                    }
                    ComboBox {
                        model: {
                            const isVertical = indicatorsPage.cfg_indicatorOverride
                                ? (indicatorsPage.cfg_indicatorLocation === 1 || indicatorsPage.cfg_indicatorLocation === 2)
                                : (indicatorsPage.plasmoidLocation === PlasmaCore.Types.LeftEdge || indicatorsPage.plasmoidLocation === PlasmaCore.Types.RightEdge);
                            return isVertical
                                ? [Wrappers.i18n("Align Left"), Wrappers.i18n("Align Center"), Wrappers.i18n("Align Right")]
                                : [Wrappers.i18n("Align Top"), Wrappers.i18n("Align Center"), Wrappers.i18n("Align Bottom")];
                        }
                        currentIndex: indicatorsPage.cfg_indicatorAlignment
                        onActivated: (index) => indicatorsPage.cfg_indicatorAlignment = index
                    }
                }
            }

            RowLayout {
                Item { implicitWidth: indicatorsPage.gridUnit }
                CheckBox {
                    id: indicatorHoverSeparate
                    enabled: indicatorResize.checked
                    text: Wrappers.i18n("Separate settings for hovered indicators")
                    checked: indicatorsPage.cfg_indicatorHoverSeparate
                    onToggled: indicatorsPage.cfg_indicatorHoverSeparate = checked
                }
            }
            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Item { implicitWidth: indicatorsPage.gridUnit * 2 }
                RowLayout {
                    id: hoverSize
                    enabled: indicatorHoverSeparate.enabled && indicatorHoverSeparate.checked
                    spacing: indicatorsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Thickness:")
                    }
                    SpinBox {
                        from: 1
                        to: 999
                        value: indicatorsPage.cfg_indicatorHoverSize
                        onValueModified: indicatorsPage.cfg_indicatorHoverSize = value
                    }
                    Label {
                        text: "px"
                    }
                    Item { implicitWidth: indicatorsPage.largeSpacing }
                    Label {
                        text: Wrappers.i18n("Length:")
                    }
                    SpinBox {
                        from: 1
                        to: 999
                        value: indicatorsPage.cfg_indicatorHoverLength
                        onValueModified: indicatorsPage.cfg_indicatorHoverLength = value
                    }
                    Label {
                        text: "px"
                    }
                }
            }

            RowLayout {
                Item { implicitWidth: indicatorsPage.gridUnit }
                CheckBox {
                    id: indicatorGroupSeparate
                    enabled: indicatorResize.checked
                    text: Wrappers.i18n("Separate settings for group indicators")
                    checked: indicatorsPage.cfg_indicatorGroupSeparate
                    onToggled: indicatorsPage.cfg_indicatorGroupSeparate = checked
                }
            }
            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Item { implicitWidth: indicatorsPage.gridUnit * 2 }
                RowLayout {
                    id: groupSize
                    enabled: indicatorGroupSeparate.enabled && indicatorGroupSeparate.checked
                    spacing: indicatorsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Thickness:")
                    }
                    SpinBox {
                        from: 1
                        to: 999
                        value: indicatorsPage.cfg_indicatorGroupSize
                        onValueModified: indicatorsPage.cfg_indicatorGroupSize = value
                    }
                    Label {
                        text: "px"
                    }
                    Item { implicitWidth: indicatorsPage.largeSpacing }
                    Label {
                        text: Wrappers.i18n("Length:")
                    }
                    SpinBox {
                        from: 1
                        to: 999
                        value: indicatorsPage.cfg_indicatorGroupLength
                        onValueModified: indicatorsPage.cfg_indicatorGroupLength = value
                    }
                    Label {
                        text: "px"
                    }
                }
            }
        }

        ConfigTab {
            id: colorTab
            title: Wrappers.i18n("Color")
            iconName: "color-management"
            available: indicatorsPage.cfg_indicatorsEnabled
            unavailableReason: indicatorsPage.offReason

            Label {
                text: Wrappers.i18n("Colors:")
            }
            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Layout.fillWidth: true
                ComboBox {
                    id: indicatorColorCombo
                    Layout.fillWidth: true
                    Layout.minimumWidth: indicatorsPage.gridUnit * 14
                    model: [
                        Wrappers.i18n("Use plasma accent color"),
                        Wrappers.i18n("Use dominant icon color"),
                        Wrappers.i18n("Custom color")
                    ]
                    currentIndex: indicatorsPage.cfg_indicatorAccentColor ? 0 : (indicatorsPage.cfg_indicatorDominantColor ? 1 : 2)
                    onActivated: (index) => {
                        indicatorsPage.cfg_indicatorAccentColor = index === 0;
                        indicatorsPage.cfg_indicatorDominantColor = index === 1;
                    }
                }
                KQuickAddons.ColorButton {
                    enabled: indicatorColorCombo.currentIndex === 2
                    showAlphaChannel: true
                    Layout.maximumHeight: indicatorColorCombo.height
                    color: indicatorsPage.cfg_indicatorCustomColor
                    onColorChanged: {
                        if (!Qt.colorEqual(color, indicatorsPage.cfg_indicatorCustomColor))
                            indicatorsPage.cfg_indicatorCustomColor = color;
                    }
                }
            }

            Item { height: indicatorsPage.largeSpacing }

            CheckBox {
                text: Wrappers.i18n("Highlight active window in group")
                checked: indicatorsPage.cfg_indicatorHighlightActive
                onToggled: indicatorsPage.cfg_indicatorHighlightActive = checked
            }
            CheckBox {
                id: indicatorDimInactive
                text: Wrappers.i18n("Dim inactive indicators")
                checked: indicatorsPage.cfg_indicatorDimInactive
                onToggled: indicatorsPage.cfg_indicatorDimInactive = checked
            }
            RowLayout {
                spacing: indicatorsPage.smallSpacing
                Item { implicitWidth: indicatorsPage.gridUnit }
                RowLayout {
                    id: inactiveOpacity
                    enabled: indicatorDimInactive.checked
                    spacing: indicatorsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Inactive indicator opacity:")
                    }
                    SpinBox {
                        from: 0
                        to: 100
                        stepSize: 5
                        value: indicatorsPage.cfg_indicatorInactiveOpacity
                        onValueModified: indicatorsPage.cfg_indicatorInactiveOpacity = value
                    }
                    Label {
                        text: "%"
                    }
                }
            }
            CheckBox {
                text: Wrappers.i18n("Desaturate when minimized")
                checked: indicatorsPage.cfg_indicatorDesaturate
                onToggled: indicatorsPage.cfg_indicatorDesaturate = checked
            }
        }
    }
}
