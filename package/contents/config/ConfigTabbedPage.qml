/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

// A settings section split into tabs: the Live Preview, then the options
// that apply to the whole section (header), then a tab bar over a
// scrollable form. Content declared inside an instance must be ConfigTab
// items; each becomes a tab.
ColumnLayout {
    id: tabbedPage

    required property var cfg_page
    property bool showPreview: true
    // A form above the tab bar, for the options of the whole section.
    property Component header: null
    default property alias tabs: tabColumn.data
    property int currentTab: 0

    anchors.fill: parent
    spacing: tabbedPage.cfg_page.largeSpacing

    // Inactive tabs stay visible, just transparent and disabled: a hidden
    // form isn't laid out, and text that wraps (InlineMessage) keeps the
    // height it measured at zero width when its tab is shown.
    function _syncTabs(): void {
        const tabs = tabColumn.children;
        for (let i = 0; i < tabs.length; ++i)
            tabs[i].current = i === tabbedPage.currentTab;
        scrollView.scrollToTop();
    }
    readonly property ConfigTab _currentTabItem: tabColumn.children[tabbedPage.currentTab] as ConfigTab
    // Only pages with tabs that can be greyed out reserve a line for why.
    readonly property bool _hasUnavailableTabs: {
        for (const tab of tabColumn.children) {
            if ((tab as ConfigTab).unavailableReason !== "")
                return true;
        }
        return false;
    }
    onCurrentTabChanged: _syncTabs()
    Component.onCompleted: _syncTabs()

    LivePreview {
        cfg_page: tabbedPage.cfg_page
        location: tabbedPage.cfg_page.plasmoidLocation
        Layout.fillWidth: true
        visible: tabbedPage.showPreview && tabbedPage.cfg_page.plasmoidLocation !== PlasmaCore.Types.Floating
    }

    Loader {
        Layout.fillWidth: true
        Layout.leftMargin: tabbedPage.cfg_page.gridUnit
        Layout.rightMargin: tabbedPage.cfg_page.gridUnit
        active: tabbedPage.header !== null
        visible: active
        sourceComponent: tabbedPage.header
    }

    Instantiator {
        id: tabActions
        model: tabColumn.children.length
        delegate: Kirigami.Action {
            required property int index
            readonly property ConfigTab tab: tabColumn.children[index] as ConfigTab
            text: tab ? tab.title : ""
            icon.name: tab ? tab.iconName : ""
            checked: tabbedPage.currentTab === index
            onTriggered: tabbedPage.currentTab = index
        }
    }

    Kirigami.NavigationTabBar {
        Layout.fillWidth: true
        visible: tabActions.count > 1
        maximumContentWidth: tabbedPage.cfg_page.gridUnit * 8 * Math.max(tabActions.count, 3)
        actions: {
            const list = [];
            for (let i = 0; i < tabActions.count; ++i)
                list.push(tabActions.objectAt(i));
            return list;
        }
    }

    // Why the current tab is greyed out. It keeps its place when there's
    // nothing to say, so the form under it doesn't jump.
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        visible: tabbedPage._hasUnavailableTabs
        opacity: !!tabbedPage._currentTabItem && !tabbedPage._currentTabItem.available ? 1 : 0
        spacing: tabbedPage.cfg_page.smallSpacing
        Kirigami.Icon {
            source: "dialog-information"
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
        }
        QQC2.Label {
            text: tabbedPage._currentTabItem ? tabbedPage._currentTabItem.unavailableReason : ""
        }
    }

    ConfigScrollView {
        id: scrollView
        cfg_page: tabbedPage.cfg_page

        // The tabs are stacked; the stack is as tall as the current one.
        Item {
            id: tabColumn
            width: parent.width - tabbedPage.cfg_page.gridUnit * 2
            implicitHeight: {
                const tab = children[tabbedPage.currentTab];
                return tab ? tab.implicitHeight : 0;
            }
            // A form as wide as the page centers its rows, and the margins
            // on both sides shrink with the window.
            onWidthChanged: {
                for (const tab of children)
                    tab.width = width;
            }
            onChildrenChanged: {
                for (const tab of children)
                    tab.width = width;
            }
        }
    }
}
