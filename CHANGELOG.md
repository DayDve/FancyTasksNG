# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Badges as Dots:** New "Show badges as dots" option under Indicators: never, always, or only when the badges would be smaller than a set size (the default, 10 px). A dot grows into the full badge while its task is hovered.
- **No Tooltips for Pinned Apps That Aren't Running:** New option under Behavior, below "Show tooltips": keep tooltips for running apps but don't show them for pinned apps that aren't running, whose tooltip only repeats the app's name and description. Off by default.

### Changed
- **Badge Layout:** In icons-only mode the audio and notification badges are now sized and placed from the task button rather than from the icon, so changing the icon's size or offset no longer drags them along or leaves the button's corners empty. They sit in the button's corners away from the panel edge: audio on the left and the count on the right on horizontal panels, audio on top and the count below on vertical ones. On hover they grow with the icon in place, from their corner facing the button's center, without shaking as the zoom animates, and a longer count widens away from the icon. Pointing at a badge keeps its task hovered, so the audio badge can be clicked while the icon is zoomed.
- **Audio Badge Icon:** The speaker is now drawn as a vector shape instead of a font glyph, so it looks the same whatever fonts are installed and stays sharp at any size; muted, it's crossed by a red "no" sign. Digits in the notification count are centered by their actual shape, no longer sitting high.
- **Tooltip Volume Controls:** The volume slider on window thumbnails and in tooltips without thumbnails is now the same thin one as everywhere else in tooltips, and the wheel over it in a tooltip without thumbnails changes the volume too.

### Fixed
- **Badge Count Rounding:** Shortened counts were rounded up, so 9 999 read "10k" and 1 960 read "2k"; they now round down ("9.9k", "1.9k").
- **Urgent Badge for Windows Demanding Attention:** The notification count was meant to turn urgent when its window demands attention, but checked a property that doesn't exist.
- **Doubled Volume Controls in Tooltips:** An app playing a single audio stream with no media player (Telegram, for one) got the stream listed under its volume slider as well, with a second mute button and a second slider. The list now shows up only when there's more than one stream, or audio playing while the app's player is paused, and its sliders are the same thin ones as the app's instead of the theme's oversized slider.
- **Count Badge Shown With Badges Turned Off:** With "Show badges" off, an app that played audio also showed its notification count.
- **Notification Badges for Apps Reporting Another Id:** Badge counts and progress are now matched to a task by the process that sends them, then by app id as before. An app that reports an id other than the one of the desktop file it was started from, such as Telegram forks like 64Gram after recent updates, gets its badge again.
- **Launch Feedback on Every Panel:** With a widget on each screen's panel set to show only that screen's tasks, launching a pinned app showed the launch feedback on every panel. It now shows only on the panel it was launched from; a panel that pins the same app keeps its pin, without the busy indicator. Launches from elsewhere (the app menu, KRunner) still show everywhere, since there's no telling which screen they're for.
- **Pinned Apps Losing Their Activities:** Reordering pinned apps on the Pinned Applications settings page made every pinned app that was limited to certain activities show up on all of them. Apps pinned to only some activities also weren't recognized as pinned there, so they could be pinned a second time.
- **Unpinning by Dragging Off the Panel:** Dragging a pinned app off the panel to unpin it often dropped a copy of its .desktop file wherever the cursor stopped (on the desktop, in a Dolphin window) and left it pinned, and dropping it back onto the panel could unpin it instead. A pinned app is now unpinned exactly when it's dropped anywhere outside the widget, and no longer carries a file to drop.
- **Running Apps Jumping to the Start When Pinning From Settings:** With manual sorting, pinning or unpinning an app on the Pinned Applications settings page moved every running pinned app to the start of the panel, away from its pin. Only the pin added or removed changes now, as when pinning from a task's context menu.
- **Clicking a Pinned App in Settings Moved It to the Top:** On the Pinned Applications settings page, a plain click on an app (without dragging) moved it to the top of the list.
- **Old Thumbnails in Tooltips:** A window's tooltip could show a thumbnail captured long ago while its live preview was loading; cached thumbnails older than two minutes are no longer shown.
- **"No Titlebar and Frame" Always Disabled:** The context menu item can be used again on windows that support it.
- **Volume Wheel Over a Pinned App:** With pinned apps kept separate from windows, Shift+wheel over a pinned app whose app is playing audio did nothing until its audio state changed.
- **Play/Pause in the Context Menu:** If playback started or stopped while the context menu was open, the item kept its old label and state, and clicking it did the opposite of what the player needed.
- **Mute From a Window Thumbnail Muted the Whole Group:** In a group's tooltip, Mute in a window thumbnail's context menu muted (and showed the state of) every window of the group. It now acts on that window's app process only, and the media controls in that menu show up only when the window's own process runs the player, as in its tooltip.
- **Context Menu Opening Before It Was Complete:** From the second time a task's context menu was opened (when its jump list was already cached), the menu opened before its media controls and mute item were added, so they could be missing or end up in the wrong place.
- **Thumbnail Menu Left Without Its Tooltip:** Moving the cursor from a window thumbnail into its context menu closed the tooltip and left the menu hanging. The tooltip now stays while the menu is open, and the menu closes when another task's tooltip takes over.
- **Mute Item Position in the Context Menu:** For a group, Mute sat at the top of the context menu, above the jump list; it's now below it, as for a single window.
- **Same Action on Wheel and Ctrl+Wheel:** Choosing the Ctrl+wheel action as the plain wheel action left both set to it, while the Ctrl box showed a different one. The two are now swapped.
- **Settings Undoing Changes Made From the Panel:** Pressing Apply in the widget settings put back the pinned apps and the "don't group" lists as they were when the settings page was opened, undoing apps pinned, unpinned or reordered on the panel in the meantime. Settings not changed on the page now keep their current values.
- **Helper Open to Any App (security):** The widget's background helper, which runs jump list actions, opens files and reads browser history for the context menu, answered every program on the session bus, so any app with bus access (Flatpak apps included) could make it run arbitrary commands, read or write files, or read the browsing history. It now only answers the Plasma shell that started it, and jump list actions are launched from the app's .desktop file instead of a command line passed to it.
- **Opening Recent Files and Places With Spaces:** Recent documents, folders and places whose path contains spaces (or a backslash) opened the wrong thing or nothing at all.
- **Forgetting Recent Documents:** Clearing an app's recent documents now goes through the activity manager instead of editing its database behind its back.
- **Browser History in the Context Menu:** Recent pages were often missing (visits the browser hadn't flushed to its database yet), the list could come up empty, and some apps whose names merely contain a browser's name (Hedgewars for Edge) got browser history lookups.
- **Badge Count Reset by Progress Updates:** An app reporting only its progress (or only its count) reset the other value, so a download in progress could clear the unread count.
- **Exporting and Importing Settings:** Failed for files whose path contains spaces or non-Latin characters.
- **Moving Tasks With Ctrl+Shift+Arrows:** With a filter that hides some tasks (only the current screen, only minimized windows and so on), the keyboard shortcut moved a different task than the focused one, or moved it to the wrong place.
- **Volume of New Audio Streams:** A new audio stream from an app got the volume it had last been set to in this session for that process id, overriding the volume the sound server restores for it, and could hand that volume to an unrelated app that later got the same process id.
- **Fill in Classic Mode:** "Fill free space on panel" was greyed out in the classic (icons + text) mode, yet always on there, so the widget took the whole panel with its buttons at one end. It can now be turned off in classic mode too, leaving the widget as wide as its buttons.
- **Rows With Narrow Classic Buttons:** In the classic mode with a small maximum button width, the widget kept a minimum width larger than a button and started a new row of tasks too late.
- **Preview Toggle Asking to Apply:** Showing or hiding the preview at the top of the settings pages, or changing its panel thickness, made the settings dialog ask to Apply. These are now remembered on their own.
- **Wheel Volume in Tooltips:** Scrolling over a tooltip's volume controls always changed the volume by 5%; it now uses the same step as the wheel over a task (the volume step set in the Audio Volume widget).
- **Media Controls Lingering in Tooltips:** After playback ended or its audio stream went away, a tooltip kept showing the media controls for up to two seconds. They now go away right away.
- **Stream List Flashing on Pause:** Pausing a player such as mpv or VLC from its tooltip briefly showed the list of audio streams.
- **No Audio Indicator on a Player's First Launch:** The first time a player such as mpv or VLC was started, its button showed no audio indicator and its tooltip no volume controls; starting it again worked.

## [2.3.0] - 2026-11-05

### Added
- **Cursor-Following Glow:** New option under Advanced → Effects: a soft glow on the panel underneath the task buttons that follows the cursor, tinted with the dominant color of the hovered app's icon and blending smoothly between apps. Off by default.
- **Fit Button Width to Title:** New option for the classic (icons + text) mode on horizontal panels: instead of every button being the maximum width, each button is as wide as its icon and title, kept between a configurable minimum and the existing maximum width. Titles longer than the maximum are still elided. Off by default (#52).
- **Tooltip Thumbnail Sizing:** Added a "Thumbnail aspect ratio" option under Behavior: screen-based sizing (the default) or sizing from window geometry. In window mode every thumbnail keeps the same height as in screen mode and is as wide as its window's shape makes it, so there are no empty bands at the sides and a small window's preview is never bigger than a maximized one's; it follows windows resized while the tooltip is open. Grouped previews are also constrained to the panel's screen (thanks @77x7, #49).
- **Shared Media Panel in Group Tooltips:** A browser plays every tab of every window from one process, with one media player, so there's no telling which of its windows in a group tooltip the audio comes from. Such an app now gets one panel with its media controls and volume below the window previews instead of controls on every window, or on the wrong one when the playing tab is in the background. Apps that run a process per window, like VLC or mpv, keep their controls on each window. The new "In group tooltips" option under the media controls settings can hide the panel.
- **Audio Streams in Tooltips:** When an app plays more than one audio stream, or plays audio its media player doesn't control (a browser's background tab, say), the tooltip lists the streams with a mute button, a volume slider and a level meter each, so the noisy tab can be found and silenced on its own. Clicking a stream's name brings up the window and, with Plasma Browser Integration, the browser tab it plays in. In a group tooltip, a window whose title matches a playing stream gets a speaker badge on its preview: click it to mute, scroll on it to change the volume.

### Changed
- **Task Sorting Settings:** "Do not sort" is gone from the Sort tasks list; it's now **Manually** with the new **Keep launchers separate** checkbox, as in Plasma's own Task Manager, and a hint under it explains what each choice does. With **Keep launchers separate** (the default) tasks can now be reordered too, as in Plasma's Icons-only Task Manager: pinned apps stay first and keep their slots when launched, and can be dragged among themselves, other tasks among themselves (#59). Without it any task can be dragged anywhere. Saved settings are unchanged.
- **Diagnostic Report:** Reworked `make diag` / `tools/diag.sh` to collect what's actually needed to diagnose a report: which installed copy plasmashell really loads (with its own version, install time and a content fingerprint) instead of the version of the source tree the script happened to be run from, whether plasmashell was restarted after the last install, whether every QML module the widget imports is present, whether the Python D-Bus bridges can run, the panel's settings next to the widget's, and only the log lines that concern Fancy Tasks NG instead of an unfiltered tail of the whole shell log. Detected problems are listed at the top of the report. The script no longer depends on the rest of the repository, so downloading just `tools/diag.sh` works as the bug report template says.
- **Task Order Storage:** Switched the saved task order from the deprecated `Qt.labs.settings` to `QtCore`'s `Settings`, silencing a deprecation warning plasmashell logged on every start. Both store into the same file, so the already-saved order is kept.

### Fixed
- **Meta+Number Shortcuts:** Restored `activateTaskAtIndex()`, the method plasmashell calls in response to Meta+Number shortcuts — it was mistakenly removed as "dead code" in 2.1.0's refactor since it has no in-repo caller (it's invoked externally by plasmashell itself) (fixes #54).
- **Task Order Lost on Plasmashell Restart:** Already-running windows and manually-repositioned pinned buttons could land in the wrong spot after a `plasmashell --replace` restart, staying scrambled until fixed by hand. Fixed a real startup-ordering race in the task model configuration, and added a snapshot of the actual visible task order that's restored once the model settles after a restart, kept separately for each widget instance (fixes #53).
- **Tooltip Track Title Not Clickable:** Clicking the track/artist title in a tooltip's media controls (both the overlay-on-thumbnail and under-thumbnail styles) did nothing instead of activating the window, since the scrolling-text component silently absorbed the click (fixes #55).
- **Pinned App Jumping to the End After Closing:** With the default "Do not sort" mode, closing the last window of a pinned app put its launcher at the end of the pinned group instead of back in its own slot. Plasma's task model orders launchers in that mode by a row number that gets reshuffled when the launcher reappears; the mode now runs on the manual-sort model, which orders launchers by the pinned list itself. Manual reordering (drag-and-drop, Ctrl+Shift+arrows) stays limited to the "Manually" mode as before.
- **Tooltip Corners Poking Out of the Shadow:** The tooltip background's nearly square corners stuck out past its drop shadow, which a blurred shadow always draws fainter at the corners than along the edges - most visible on light themes. The tooltip now uses the theme's corner radius and a thin contrast outline, and a narrower shadow nudged slightly down and right that hugs the outline instead of thinning out at the corners (fixes #57).
- **Group Tooltip Media Controls Cut Off:** With media controls under the thumbnails, a group tooltip was sized to the thumbnails alone and cut the controls off (fixes #60).
- **Audio Indicator on the Wrong App:** With two separate installs of the same app running as separate tasks (e.g. two Firefox builds with different desktop files), the one that wasn't playing also showed the audio indicator, and muting it muted the other one. Audio streams now belong to the process that plays them: a stream whose process (or, for Chromium-family browsers that play audio from a helper process, its parent) owns a window is only ever shown on that window's task, even when the window is on another screen hidden by "show only tasks from the current screen". The app-name fallback is left for streams no window process owns, and notification sounds played by Plasma on an app's behalf no longer light up that app's audio indicator.
- **Tiny Window Previews on Ultrawide Monitors:** Tooltip thumbnails sized themselves from the physical monitor's aspect ratio, which on an extreme ultrawide screen squashed the preview into a sliver most windows rendered tiny inside of. Clamped to the range of ordinary desktop monitor shapes (4:3 through 21:9); normal screens are unaffected (fixes #55).
- **VLC Can't Be Resumed After Pausing:** After pausing VLC from a tooltip or the context menu, the Play button stayed disabled until plasmashell was restarted. VLC reports that it can't play while it starts up and never says when that changes, and Plasma keeps the stale value (its own Task Manager has the same problem). A paused player's Play button is now always enabled, and Play is sent to the player directly when Plasma would refuse it.

### Refactored
- **Media Attribution:** Replaced `AudioStreamManager` and the separate MPRIS model instances with a single `MediaRegistry` that decides which task an audio stream or media player belongs to, used by task buttons, tooltips and the context menu alike. Groundwork for the reworked group tooltip media controls.

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
