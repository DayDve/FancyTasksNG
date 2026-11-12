/*
    SPDX-FileCopyrightText: 2026 Vitaliy Elin <daydve@smbit.pro>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

.pragma library

// Mock tasks for the settings previews (PreviewPanel), with TasksModel role
// names; the mock* roles stand for what the delegates otherwise get from
// the app (notification count, progress, audio).

function mockTask(icon, name, extra) {
    return Object.assign({
        decoration: icon, display: name, AppId: "",
        IsWindow: true, IsLauncher: false, IsStartup: false,
        IsActive: false, IsMinimized: false, IsDemandingAttention: false,
        IsGroupParent: false, ChildCount: 0,
        mockBadgeCount: 0, mockProgress: -1, mockPlaying: false, mockMuted: false
    }, extra);
}

// Fills model with tasks laid out for the grouping settings. Row 1 is the
// active Dolphin window (or group). compact leaves out the last ones, for
// small previews.
function fill(model, groupMode, groupPopups, compact) {
    model.clear();
    const grouped = groupMode !== 0 && groupPopups;
    const sideBySide = groupMode !== 0 && !groupPopups;
    model.append(mockTask("plasmadiscover", "Discover", { IsMinimized: true, mockProgress: 0.7 }));
    model.append(mockTask("org.kde.dolphin", "Dolphin", grouped
        ? { IsActive: true, IsGroupParent: true, ChildCount: 2, mockBadgeCount: 3 }
        : { IsActive: true, mockBadgeCount: 3 }));
    if (sideBySide)
        model.append(mockTask("org.kde.dolphin", "Dolphin", {}));
    model.append(mockTask("utilities-terminal", "Konsole", { mockBadgeCount: 12 }));
    if (compact)
        return;
    model.append(mockTask("internet-web-browser", "Browser", { mockPlaying: true }));
    if (groupMode === 0)
        model.append(mockTask("org.kde.dolphin", "Dolphin", {}));
}
