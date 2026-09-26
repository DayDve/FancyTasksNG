# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Meta+Number Shortcuts:** Restored `activateTaskAtIndex()`, the method plasmashell calls in response to Meta+Number shortcuts — it was mistakenly removed as "dead code" in 2.1.0's refactor since it has no in-repo caller (it's invoked externally by plasmashell itself) (fixes #54).
- **Task Order Lost on Plasmashell Restart:** Already-running windows and manually-repositioned pinned buttons could land in the wrong spot after a `plasmashell --replace` restart, staying scrambled until fixed by hand. Fixed a real startup-ordering race in the task model configuration, and added a snapshot of the actual visible task order that's restored once the model settles after a restart (fixes #53).

## [2.2.0] - 2026-09-24

### Added
- **Attention Highlight:** Added a "Colorize the task button when a window wants attention" option with a custom color picker, using the same colorization effect as the existing button-color settings.
- **Configuration Export/Import:** Added "Export Configuration…"/"Import Configuration…" buttons on the Advanced page to back up and restore all settings as a JSON file.

### Fixed
- **Pinned Launchers Defaults:** "Reset to Defaults" for the Pinned Apps list now resets to the real default launcher set instead of an empty list.

### Refactored
- **Settings Pages:** Extracted the repeated Live Preview + scrollable form scaffold from the Appearance/Behavior/Indicators/Advanced pages into a shared component, and split the Pinned Apps page's per-item drag/reorder row into its own component. Removed dead defensive checks left over from earlier caching work. `cfg_*Default` values (used to silence KCM warnings) are now kept in sync with `main.xml` automatically on every build/install/test instead of by hand.

## [2.1.0] - 2026-09-21

### Added
- **Tooltip Media Bar:** Show an inline volume slider in the media bar when playback controls (e.g. play/pause/prev/next) are not present.
- **Task Filters:** Added an "Invert selected filters" option — hides tasks matching the active filters (current screen, virtual desktop, or activity) instead of showing them, making it easy to set up a secondary taskbar for other screens/desktops (fixes #28).
- **Notification Badges:** Added a badge background color mode setting — Adaptive (theme color, default), Fixed red (classic), System accent color, or Custom color with a picker (fixes #36).
- **Task Indicators:** Added a "Dim inactive indicators" option with a configurable opacity, decoupled from the active-highlight dimming logic, which is now restricted to grouped tasks to avoid unwanted dimming of single inactive window indicators (fixes #47).
- **Context Menu:** Added a per-activity pinning submenu for launchers, matching the stock Task Manager's behavior — with a single activity, "Pin to Task Manager" behaves as before; with 2+ activities, it shows a submenu (On All Activities / On The Current Activity / one entry per activity) so a shortcut can be pinned to specific activities (fixes #50, thanks to @leferi99 for the port in PR #51).

### Refactored
- **Property Caching & Optimization:** Extensively cached configuration, global settings, and context properties across multiple QML components to resolve performance bottlenecks, reduce CPU load, and optimize binding evaluation. Affected components:
  - **Task & TaskList:** Added asynchronous loading for badge, media, expander, and volume controls to make task list generation smoother. Optimized badge loading on-demand based on unread counters and audio state, and simplified `minimumWidth` calculation when in `iconsOnly` mode.
  - **Task:** Cached parent and list configuration values.
  - **TaskIconBox:** Cached configuration settings and context properties.
  - **ToolTipDelegate:** Cached config properties to simplify delegate bindings.
  - **ToolTipInstance:** Cached delegate-specific properties and configurations.
  - **ToolTipMediaBar:** Cached media controller properties.
  - **Settings Pages & Live Preview:** Cached layout metrics, units, theme colors, and configuration properties. Resolved `qmllint` warnings regarding ID shadowing, unqualified property access, and legacy `PropertyChanges` syntax.
  - **Task Controls & Context Menus:** Cached properties in `ContextMenu`, `PlayerController`, and `MouseHandler`. Removed redundant audio stream manager volume initialization.
- **Dead Code Removal (~150 lines):** Cleaned up dead symbols across 8 files: removed unused aliases and functions in `main.qml` (`taskRepeater`, `needLayoutRefresh`, `hasLauncher`, `activateTaskAtIndex`), dead flags in `MouseHandler` (`isGroupDialog`, `handleWheelEvents`), unused row helpers in `Task` (`itemIndex`, `modelRow`), `iconSource` Kirigami icon layer and `isCrossed`/`highlightColor` in `Badge`, `showContextMenuWithAllPlaces` in `ContextMenu`. Removed 4 dead KConfig schema entries (`indicatorReverse`, `indicatorMinLimit`, `indicatorResizeLength`, `indicatorResizeThickness`) and 3 phantom `cfg_*` pairs with no schema backing. Simplified `Indicators.qml` position states by removing dead `indicatorReverse` branches (setting no longer existed in schema).
- **Bridge & JS Cleanup:** Removed 6 dead media bridge readonly properties and 2 forwarding methods from `ToolTipInstance` — child loaders bind directly to `mediaController`. Removed per-badge-update `console.log` noise from `BadgeManager`. Removed 5 dead helpers from `layoutmetrics.js` (`rawLeft/Right/Top/BottomMargin`, `maximumContextMenuTextWidth`).
- **LivePreview Dependency Injection:** Promoted `cfg_page` from nullable `var` to `required property` in `LivePreview.qml`, removing 11 defensive null-guards — all 4 instantiation sites always supply the value.
- **Python Bridge:** Replaced 2 `subprocess qdbus6` shell-outs in `desktop_actions.py` with native `dbus-python` calls (`get_current_activity`, `ResourcesScoring.EmitChanged`). Moved deferred `dbus`/`GLib` imports to the top of the module.
- **Indicators Position Logic:** Deduplicated the near-identical edge-matching condition repeated across the 4 position `State`s (bottom/left/right/top) into a single `edgeMatches()` function; this also surfaced and removed one branch that was already fully redundant with the others.
- **Context Menu & Desktop Actions Cache:** Unified cache-key construction between `query()`, `prefetch()`, and `_doQuery()` in `DesktopActionsManager` behind one shared helper, and deduplicated the "should show browser history" predicate that was independently repeated in `Task.qml` and `ContextMenu.qml`.
- **Tooltip Root Index:** Replaced an implicit `||`-fallback for the tooltip's model index with an explicit check, removing reliance on an unenforced assumption about `modelIndex()`'s return value.

### Fixed
- **Badge Icon Color:** Fixed `Kirigami.Icon` color binding in `Badge.qml` to respect custom badge background color modes (modes 1, 2, and 3) in addition to urgent state (fixes #36).
- **Wayland Startup & Fit Content Panel:** Fixed the panel becoming invisible after logging into a Wayland session in "Fit Content" mode by preventing the plasmoid from shrinking to zero width/height during the initial startup phase before the tasks model is populated (fixes #35).
- **Layout Direction:** Fixed the `reverseMode` setting getting stuck on "To the left" by adding the missing `onToggled` handler to the first RadioButton in the configuration UI (fixes #23).
- **Parabolic Zoom:** Fixed the parabolic zoom animation being inverted and broken when `reverseMode` is active (for both mirrored horizontal layouts and rotated vertical layouts).
- **Pinned Tasks:** Fixed pinned applications order not being respected and launched applications jumping to the end of the panel (fixes #24, #23).
- **Reordering:** Optimized drag-and-drop performance by reducing task switching delay and restoring smooth slide animations.
- **Tooltip Volume Control:** Resolved layout-managed anchors and parent/sibling anchors constraints warnings in `ToolTipMediaBar.qml` by wrapping the volume `RowLayout` in a parent `Item` container.
- **X11 Window Thumbnails (Plasma 6.7+):** Dynamically load X11 `WindowThumbnail` components only during active X11 sessions, preventing loading failures and warnings on Wayland under newer Plasma versions (fixes #25).
- **Icon Blur & Scale Origin:** Fixed icon scaling starting from the center instead of the panel edge. Resolved visual blurriness by utilizing a dynamic rendering size—using native resolution when idle to maintain pixel-perfect sharpness, and switching to high-resolution texture on hover for smooth zooming (fixes #27).
- **Audio Controls & Context Menu:** Resolved context menu mute button toggle state inconsistencies and fixed potential audio control race conditions.
- **Plasmoid Sizing:** Fixed an issue where the plasmoid did not shrink to zero size when all visible tasks were filtered out (e.g., in "only minimized" or "only not minimized" modes), leaving an empty space on the panel (fixes #30).
- **Icon Sizing:** Fixed icons scaling up to giant sizes on right-click (context menu) when in classic mode or when hover zoom effects are disabled (fixes #29).
- **Tooltip Shrinkage:** Fixed an issue where the tooltip window would shrink to a small dot on show/hide and during transitions between task icons (fixes #32).
- **Indicator Dimming:** Fixed inactive-indicator dimming not applying to single (non-grouped) windows and decoupled the setting from `indicatorResize` (fixes #39).
- **Audio Mute Badge:** Fixed the mute badge remaining visible when "Indicate audio streams" is disabled (fixes #37).
- **File Descriptor Leak:** Fixed a crash caused by `plasmashell` running out of open files after extended use on Wayland, by guarding the PipeWire and X11 thumbnail loaders with the "Show thumbnails" setting so they stop grabbing frames when thumbnails are off (fixes #42).
- **Blank Tooltip Frame:** Fixed an empty tooltip frame appearing when "Show tooltips" is disabled (fixes #46).
- **Tooltip Fallback Icon:** Fixed the fallback app icon in tooltips briefly flashing before a live PipeWire preview loads, and fixed a bug where, once the fallback's fade-in animation had run, the icon's visibility could get permanently stuck regardless of the actual thumbnail state (thanks to @77x7 for the fix in PR #48).
- **Live Preview Thumbnail Cache:** Fixed a cached window preview sometimes failing to display or update in the tooltip fallback image, caused by a property reassignment that didn't propagate through the delegate chain.
- **Desktop Actions Cache Miss:** Fixed jump-list/recent-documents lookups missing their prefetched cache entry (and re-querying over D-Bus unnecessarily) for pinned, non-running applications, caused by inconsistent cache-key construction.
- **Desktop Actions Bridge Freeze:** Bounded the D-Bus call timeout when querying the current KDE Activity from the desktop-actions bridge, and reused a single D-Bus connection instead of opening a new one per call, preventing the bridge's single-threaded event loop from freezing indefinitely if the Activity Manager becomes unresponsive.

## [2.0.1] - 2026-06-08

### Fixed
- **Configuration UI:** Resolved an issue where the configuration dialog would fail to load (showing a `Unable to assign [undefined] to bool` error in plasmoidviewer) due to missing ID references in the `LivePreview` component on the Behavior, Indicators, and Advanced tabs.

## [2.0.0] - 2026-06-07

### Added
- **Task Alignment**: Added an option to align task icons to the center of the panel.
- **Live Preview**: Added a live preview component to the configuration window. You can now see changes applied in real time before saving them.
- **Icon Shape**: Added an option to visually round application icons. You can also enable a background behind the icons, the color of which automatically adapts to the icon itself or uses the system accent color (thanks to @Autumn1164 for the idea in issue #9).
- **Parabolic Zoom**: Added a new icon magnification effect on hover — a smooth "wave" animation (thanks to @slynobody for the request in issue #12).
- **Progress Indicators**: You can now choose the visual style of download/copy progress indicators on icons (e.g., full background fill or a progress strip on any side).
- **Pinned Apps Improvements**: Completely redesigned the pinned applications management interface in the settings. Additionally, you can now optionally unpin an application by simply dragging its icon out of the panel.
- **Notification & Task Badges**: Messengers and email clients (Telegram, KMail, etc.) now display unread message counters. File managers and browsers (Dolphin, Firefox) display the number of active tasks (downloads, copying, etc.). For pinned applications, this works even if the program is running in the background with no open windows.
- **Volume Control via Mouse Wheel**: Added a new optional setting (thanks to @ZeusOfTheCrows for PR #18) to change the volume of a specific window by scrolling the mouse wheel over its icon. Holding the Shift key adjusts the global system volume.
- **Media Controllers**: Added an option to hide media controls in tooltips or display them *below* the window thumbnails so they don't overlap the preview image (thanks to @GLUBSCHI-GD for the implementation in PR #16).
- **Removal Effects**: Added an optional "explosion/smoke" visual effect. It triggers when closing a window (by middle-clicking the icon) or when unpinning an application.
- **System Integration**:
  - Added support for the "Recent Documents" list in the right-click context menu.
  - Added a fully functional "Places" submenu for the Dolphin file manager directly from the panel.
  - (Experimental) Added tab history reading for popular browsers (Firefox, Chromium).
- **Hide Minimized Windows**: Added an option to hide minimized windows from the panel (thanks to @sirherrbatka for the request in issue #6).

### Changed
- **Drag & Drop**: Reordering tasks with the mouse is now smoother and more predictable. A clear visual drop indicator has been added.
- **Tooltips**: Updated the appearance of tooltips. Old textual counters for grouped windows have been replaced with elegant graphical badges.
- **Task Indicators**: The indicator styles settings menu has been simplified. Added separate visual configurations for active windows and inactive hovered windows.
- **Settings Interface**: The configuration menu is now more user-friendly, with many new options and pleasant drop shadows when scrolling through lists.
- **Plasma 6 Optimization**: The internal architecture was completely rewritten to comply with modern KDE Plasma 6 standards, resulting in smoother animations and improved overall stability.

### Fixed
- **Multi-row Layout**: Fixed bugs with the positioning and size of icons when the panel consists of multiple rows or columns. Previously, icons could shrink incorrectly or overflow the boundaries.
- **Large Window Previews**: Fixed the "Show large window previews" setting (triggered when clicking on a grouped task) — previously nothing happened when this was enabled (thanks to @Arclover524 for reporting in issue #17).
- **Audio Control**: Fully fixed unmuting via the task's speaker icon click and through the context menu. Also fixed a visual bug where the sound badge was hidden under the application icon (thanks to @kaos-55 for reporting in issue #4 and @ZeusOfTheCrows for the fix in PR #15).
- **Context Menu Buttons**: Resolved a bug with non-functional window control buttons (Close, Minimize, Maximize) (thanks to @Vistaus for reporting in issue #2), and fixed the "Move to Desktop" option (thanks to @bitran0 for reporting in issue #8).
- **Interface Glitches**: Fixed an issue where the context menu would close randomly or prematurely.
- **Classic Mode**: Fixed the alignment and scaling of elements in the mode where the icon is displayed alongside text (like in older Windows versions).

### Removed
- Removed broken or outdated indicator styles and animations, as well as legacy code that slowed down the panel and hindered compatibility with new KDE Plasma versions.
- Cleaned up old documentation files and unnecessary technical files.

...and more!

## [1.1.1] - 2026-03-11

### Fixed
- Fixed a backend layout issue that caused unnecessary and repetitive spam in the system journal.

## [1.1.0] - 2026-03-04

### Changed
- **Unified Tooltip Design**: Grouped tasks now use a consistent, modern tooltip interface regardless of whether window thumbnails are enabled or disabled. 

### Fixed
- Resolved erratic Drag-and-Drop behavior over grouped tasks when thumbnails were disabled.
- Fixed an issue where the applet's icon was missing (displaying as a blank sheet) in the Plasma Widget Explorer.
- Fixed missing localization (translations not loading) for users installing the pre-built `.plasmoid` package.

## [1.0.1] - 2026-03-03

### Changed
- Increased minimum Plasma API requirement to 6.5 in metadata.
- Removed animations for tooltip resizing to ensure instant and smoother transitions.

### Fixed
- **Plasma 6.6 Compatibility**: Fixed tooltip visibility, missing window management highlights, and icon clipping bugs introduced by Wayland panel rendering changes.
- Resolved a bug where live thumbnails would become stuck on the previously hovered window in single-window tooltips.

## [1.0.0] - 2026-02-19
### Added
- Initial release as Fancy Tasks NG (Next Generation), a modernized fork of Fancy Tasks / Fancy Tasks Plus.
- Full Russian localization context.

### Changed
- Fully adapted and modernized codebase for KDE Plasma 6.5+.
- Replaced outdated PlasmaComponents with QtQuick.Controls to fix UI coloring issues (e.g. black buttons in configuration dialogs).
- Refactored configuration pages to use `KCMUtils.SimpleKCM` resolving graphical scene errors and switching lag.
- Redesigned tooltip system to align with the native Plasma 6 component styles.
- General backend modernization, removing legacy code.
