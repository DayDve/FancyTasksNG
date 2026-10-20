# Frequently Asked Questions

Answers to the questions that come up again and again in the issue tracker. If your problem isn't here, [open an issue](https://github.com/daydve/FancyTasksNG/issues/new/choose).

- [A pinned app jumps to the end when I open it](#a-pinned-app-jumps-to-the-end-when-i-open-it)
- [I updated the widget, but nothing changed (or it's acting weird)](#i-updated-the-widget-but-nothing-changed-or-its-acting-weird)
- ["PlasmaCore.WindowThumbnail is not a type" after a Plasma update](#plasmacorewindowthumbnail-is-not-a-type-after-a-plasma-update)
- [How do I try a fix that's only in `develop`?](#how-do-i-try-a-fix-thats-only-in-develop)
- [Zoomed icons get cut off at the top](#zoomed-icons-get-cut-off-at-the-top)
- [Can it be a dock? (glass effect, trash, app menu, its own panel)](#can-it-be-a-dock-glass-effect-trash-app-menu-its-own-panel)
- [What is this "+", blue line or number on my icons?](#what-is-this--blue-line-or-number-on-my-icons)

---

## A pinned app jumps to the end when I open it

This is a trade-off, not a bug. It comes from Plasma's task model (libtaskmanager), which this widget is built on: a pinned launcher and the windows of that app are separate entries in it. The model can either keep a window in its launcher's slot, or let you drag any task anywhere, but not both at once. Pick the mode that fits how you work in **Behavior → Sort tasks**:

| | **Manually** | **Do not sort** |
|---|---|---|
| Drag tasks to reorder them | Yes, anything anywhere | No |
| A newly opened window of a pinned app | Goes to the end of the list | Opens in the pinned app's slot |
| When that window closes | The launcher returns to its slot | The launcher stays in its slot |
| How to change the order of pinned apps | Drag them | **Pinned Applications** page in the settings |

Plasma's own Task Manager has exactly the same choice; there it's the "Keep launchers separate" checkbox.

## I updated the widget, but nothing changed (or it's acting weird)

A running Plasma keeps using the widget code it loaded at startup. Installing a new version through "Get New Widgets", `kpackagetool6` or a downloaded `.plasmoid` replaces the files on disk, but Plasma doesn't pick them up until it restarts. Until then you get the old version, or a mix of old and new code: empty settings pages, settings that seem to have no effect, leftover artifacts.

Restart Plasma after every update:

```bash
systemctl --user restart plasma-plasmashell
```

Logging out and back in works too. `make update` does this for you.

## "PlasmaCore.WindowThumbnail is not a type" after a Plasma update

```
ToolTipInstance.qml: PlasmaCore.WindowThumbnail is not a type
```

You're running a 2.0.x version of the widget. Plasma 6.7 removed the type it used for window thumbnails. Update to the latest release (2.1.0 or newer has the fix), then [restart Plasma](#i-updated-the-widget-but-nothing-changed-or-its-acting-weird). If you already updated and still see this error, the restart is the missing step.

## How do I try a fix that's only in `develop`?

Fixes land in the `develop` branch first and reach `master` and the KDE Store with the next release. To try one earlier, use either of these:

**A ready-made build (no tools needed).** Open the [Nightly Build workflow](https://github.com/daydve/FancyTasksNG/actions/workflows/nightly.yml), click the latest successful run and download the `.plasmoid` from its **Artifacts** section (you need to be signed in to GitHub). Then install it and restart Plasma:

```bash
kpackagetool6 -t Plasma/Applet --upgrade FancyTasksNG.plasmoid
systemctl --user restart plasma-plasmashell
```

Use `--install` instead of `--upgrade` if the widget isn't installed yet. GitHub delivers artifacts as a `.zip`; unpack it first to get the `.plasmoid`.

**From source.**

```bash
git clone https://github.com/daydve/FancyTasksNG.git   # skip if you already have a clone
cd FancyTasksNG
git checkout develop
git pull
make update        # or "make install" if the widget isn't installed yet
```

Without `git`, download the [`develop` branch as a ZIP](https://github.com/daydve/FancyTasksNG/archive/refs/heads/develop.zip), unpack it and run `make update` inside. The build needs `gettext` for translations; if it's missing, the script tells you how to install it for your distribution.

## Zoomed icons get cut off at the top

This is a limit of the Plasma panel, not a setting. A widget can only draw inside its panel plus a small margin (about 20 px) that Plasma reserves for the floating panel mode and shadows. A hover zoom that grows the icon beyond that margin gets clipped. Lower **Appearance → Icon zoom factor**, or make the panel thicker.

## Can it be a dock? (glass effect, trash, app menu, its own panel)

Fancy Tasks NG is a task manager widget that lives inside a regular Plasma panel, not a standalone dock like Latte Dock. So:

- **Panel background, transparency, blur, glass effects** are drawn by Plasma, not by the widget. Use [Panel Colorizer](https://github.com/luisbocanegra/plasma-panel-colorizer) or KWin's blur.
- **Trash, application menu** and similar are separate Plasma widgets. Add them to the same panel next to Fancy Tasks NG.
- **Its own panel:** a widget dropped onto an existing panel becomes part of that panel, like any other widget. To keep it separate, create a new panel first (right-click the desktop → **Add Panel**) and add Fancy Tasks NG to it.

## What is this "+", blue line or number on my icons?

- **"+" on a grouped app** is Plasma's standard group overlay. Fancy Tasks NG has its own group indicators; turn the overlay off with **Behavior → Standard group overlay**.
- **A line along the edge of the active task** comes from the Plasma theme's task frame. Turn it off with **Appearance → Use plasma borders**.
- **A number badge** is an app's notification count (unread messages, running jobs, and so on), not the number of open windows. The number of windows is shown by the indicators. Badge settings are under **Indicators → Show badges**.
- **Hover zoom settings are missing in classic mode** because hover effects only exist in the icons-only mode.
