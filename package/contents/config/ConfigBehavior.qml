/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts


import "../ui/code/singletones"

ConfigPage {
    id: behaviorPage
    ConfigFormPage {
        cfg_page: behaviorPage

        CheckBox {
            id: enableToolTips
            text: Wrappers.i18n("Show tooltips when hovering over task buttons")
            checked: behaviorPage.cfg_enableToolTips
            onToggled: behaviorPage.cfg_enableToolTips = checked
        }
    
        RowLayout {
            visible: enableToolTips.checked
            Item {
                implicitWidth: behaviorPage.gridUnit
            }
            CheckBox {
                text: Wrappers.i18n("Not for pinned apps that aren't running")
                checked: behaviorPage.cfg_hideLauncherToolTips
                onToggled: behaviorPage.cfg_hideLauncherToolTips = checked
            }
        }

        RowLayout {
            visible: enableToolTips.checked
            Item {
                implicitWidth: behaviorPage.gridUnit
            }
            CheckBox {
                id: showToolTips
                text: Wrappers.i18n("Show window thumbnails in tooltips")
                checked: behaviorPage.cfg_showToolTips
                onToggled: behaviorPage.cfg_showToolTips = checked
            }
        }
    
        RowLayout {
            visible: enableToolTips.checked && showToolTips.checked
            Item {
                implicitWidth: behaviorPage.gridUnit * 2
            }
            Label {
                text: Wrappers.i18n("Thumbnail aspect ratio:")
            }
            ComboBox {
                Layout.fillWidth: true
                Layout.minimumWidth: behaviorPage.gridUnit * 12
                model: [Wrappers.i18n("Match screen aspect ratio"), Wrappers.i18n("Match window aspect ratio")]
                currentIndex: behaviorPage.cfg_tooltipMatchWindowAspectRatio ? 1 : 0
                onActivated: index => behaviorPage.cfg_tooltipMatchWindowAspectRatio = (index === 1)
            }
        }

        RowLayout {
            visible: enableToolTips.checked
            Item {
                implicitWidth: behaviorPage.gridUnit
            }
            CheckBox {
                id: highlightWindows
                text: Wrappers.i18n("Hide other windows when hovering over a window in the tooltip")
                checked: behaviorPage.cfg_highlightWindows
                onToggled: behaviorPage.cfg_highlightWindows = checked
            }
        }
    
        RowLayout {
            visible: enableToolTips.checked
            Item {
                implicitWidth: behaviorPage.gridUnit
            }
            CheckBox {
                id: showMediaControls
                text: Wrappers.i18n("Show media controls")
                checked: behaviorPage.cfg_showMediaControls
                onToggled: behaviorPage.cfg_showMediaControls = checked
            }
        }

        RowLayout {
            visible: enableToolTips.checked && showMediaControls.checked
            Item {
                implicitWidth: behaviorPage.gridUnit * 2
            }
            // -1 follows the audio mark on buttons, which these were tied to before.
            CheckBox {
                text: Wrappers.i18n("Show volume controls")
                checked: behaviorPage.cfg_tooltipVolumeControls < 0 ? behaviorPage.cfg_indicateAudioStreams : behaviorPage.cfg_tooltipVolumeControls === 1
                onToggled: behaviorPage.cfg_tooltipVolumeControls = checked ? 1 : 0
            }
        }
    
        RowLayout {
            visible: enableToolTips.checked && showToolTips.checked && showMediaControls.checked
            Item {
                implicitWidth: behaviorPage.gridUnit * 2
            }
            Label {
                text: Wrappers.i18n("Media controls location:")
            }
            ComboBox {
                id: cfg_mediaControlsLocation
                Layout.fillWidth: true
                Layout.minimumWidth: behaviorPage.gridUnit * 12
                model: [Wrappers.i18n("On thumbnails (Overlay)"), Wrappers.i18n("Under thumbnails")]
                currentIndex: behaviorPage.cfg_mediaControlsLocation
                onActivated: index => behaviorPage.cfg_mediaControlsLocation = index
            }
        }

        RowLayout {
            visible: enableToolTips.checked && showMediaControls.checked
            Item {
                implicitWidth: behaviorPage.gridUnit * 2
            }
            Label {
                text: Wrappers.i18n("In group tooltips:")
            }
            ComboBox {
                id: cfg_groupMediaControls
                Layout.fillWidth: true
                Layout.minimumWidth: behaviorPage.gridUnit * 12
                model: [Wrappers.i18n("One panel below the windows"), Wrappers.i18n("Hidden")]
                currentIndex: behaviorPage.cfg_groupMediaControls
                onActivated: index => behaviorPage.cfg_groupMediaControls = index
            }
        }
        Label {
            visible: enableToolTips.checked && showMediaControls.checked
            Layout.fillWidth: true
            Layout.preferredWidth: behaviorPage.gridUnit * 14
            Layout.leftMargin: behaviorPage.gridUnit * 2
            text: Wrappers.i18n("For apps that play from one process for all their windows, such as web browsers. Apps with a process per window keep their controls on each window.")
            wrapMode: Text.WordWrap
            font: behaviorPage.themeSmallFont
            opacity: 0.7
        }
    }
}
