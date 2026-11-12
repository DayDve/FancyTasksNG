/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls

// A button that opens another section of the settings dialog. Hidden when
// the dialog's sidebar can't be found (see ConfigPage.openSection).
Button {
    id: link

    required property var cfgPage
    // The section's page file, e.g. "ConfigLayout.qml".
    required property string section

    visible: false
    // The sidebar is built by the time the page has finished loading.
    Component.onCompleted: Qt.callLater(() => link.visible = link.cfgPage.canOpenSection(link.section))
    onClicked: link.cfgPage.openSection(link.section)
}
