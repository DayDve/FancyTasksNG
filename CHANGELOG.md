# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
