/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../ui/code/singletones"

// Task tooltips: the tooltip itself, its window thumbnails and its media
// controls. Everything below the switch on top needs tooltips on.
ConfigPage {
    id: tooltipsPage
    fullTitle: Wrappers.i18n("Task Tooltips")


    ConfigTabbedPage {
        cfg_page: tooltipsPage

        header: Kirigami.FormLayout {
            CheckBox {
                text: Wrappers.i18n("Show tooltips when hovering over task buttons")
                checked: tooltipsPage.cfg_enableToolTips
                onToggled: tooltipsPage.cfg_enableToolTips = checked
            }
        }

        ConfigTab {
            available: tooltipsPage.cfg_enableToolTips
            unavailableReason: Wrappers.i18n("Tooltips are turned off.")

            CheckBox {
                text: Wrappers.i18n("Not for pinned apps that aren't running")
                checked: tooltipsPage.cfg_hideLauncherToolTips
                onToggled: tooltipsPage.cfg_hideLauncherToolTips = checked
            }
            CheckBox {
                text: Wrappers.i18n("Hide other windows when hovering over a window in the tooltip")
                checked: tooltipsPage.cfg_highlightWindows
                onToggled: tooltipsPage.cfg_highlightWindows = checked
            }

            Item { height: tooltipsPage.largeSpacing }

            Label {
                text: Wrappers.i18n("Window thumbnails:")
            }
            CheckBox {
                id: showToolTips
                text: Wrappers.i18n("Show window thumbnails in tooltips")
                checked: tooltipsPage.cfg_showToolTips
                onToggled: tooltipsPage.cfg_showToolTips = checked
            }
            RowLayout {
                spacing: tooltipsPage.smallSpacing
                Item { implicitWidth: tooltipsPage.gridUnit }
                RowLayout {
                    id: aspectRatio
                    enabled: showToolTips.checked
                    spacing: tooltipsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Thumbnail aspect ratio:")
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        Layout.minimumWidth: tooltipsPage.gridUnit * 12
                        model: [Wrappers.i18n("Match screen aspect ratio"), Wrappers.i18n("Match window aspect ratio")]
                        currentIndex: tooltipsPage.cfg_tooltipMatchWindowAspectRatio ? 1 : 0
                        onActivated: (index) => tooltipsPage.cfg_tooltipMatchWindowAspectRatio = index === 1
                    }
                }
            }

            Item { height: tooltipsPage.largeSpacing }

            Label {
                text: Wrappers.i18n("Media controls:")
            }
            CheckBox {
                id: showMediaControls
                text: Wrappers.i18n("Show media controls")
                checked: tooltipsPage.cfg_showMediaControls
                onToggled: tooltipsPage.cfg_showMediaControls = checked
            }
            RowLayout {
                Item { implicitWidth: tooltipsPage.gridUnit }
                // -1 follows the audio indicator on buttons, which these were
                // tied to before.
                CheckBox {
                    id: volumeControls
                    enabled: showMediaControls.checked
                    text: Wrappers.i18n("Show volume controls")
                    checked: tooltipsPage.cfg_tooltipVolumeControls < 0 ? tooltipsPage.cfg_indicateAudioStreams : tooltipsPage.cfg_tooltipVolumeControls === 1
                    onToggled: tooltipsPage.cfg_tooltipVolumeControls = checked ? 1 : 0
                }
            }
            RowLayout {
                spacing: tooltipsPage.smallSpacing
                Item { implicitWidth: tooltipsPage.gridUnit }
                RowLayout {
                    id: mediaControlsLocation
                    enabled: showMediaControls.checked && showToolTips.checked
                    spacing: tooltipsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("Media controls location:")
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        Layout.minimumWidth: tooltipsPage.gridUnit * 12
                        model: [Wrappers.i18n("On thumbnails (Overlay)"), Wrappers.i18n("Under thumbnails")]
                        currentIndex: tooltipsPage.cfg_mediaControlsLocation
                        onActivated: (index) => tooltipsPage.cfg_mediaControlsLocation = index
                    }
                }
            }
            RowLayout {
                spacing: tooltipsPage.smallSpacing
                Item { implicitWidth: tooltipsPage.gridUnit }
                RowLayout {
                    id: groupMediaControls
                    enabled: showMediaControls.checked
                    spacing: tooltipsPage.smallSpacing
                    Label {
                        text: Wrappers.i18n("In group tooltips:")
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        Layout.minimumWidth: tooltipsPage.gridUnit * 12
                        model: [Wrappers.i18n("One panel below the windows"), Wrappers.i18n("Hidden")]
                        currentIndex: tooltipsPage.cfg_groupMediaControls
                        onActivated: (index) => tooltipsPage.cfg_groupMediaControls = index
                    }
                }
                ConfigHint {
                    target: groupMediaControls
                    info: Wrappers.i18n("Some apps, such as web browsers, don't report which window plays the audio. For them, the playback controls are shown once for the whole group.")
                }
            }
        }
    }
}
