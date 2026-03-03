# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
