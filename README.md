<h1 align="center">Fancy Tasks NG</h1>
<p align="center">
  <img src="package/icon.svg" alt="Fancy Tasks NG"/>
</p>
<p align="center">
  <strong>A feature-rich and highly customizable alternative task manager for KDE Plasma 6.</strong>
</p>
<p align="center">
  <a href="https://github.com/daydve/FancyTasksNG/releases/latest">
    <img src="https://img.shields.io/github/v/release/daydve/FancyTasksNG?style=flat-square&label=Latest%20Release&color=6c63ff" alt="Latest Release"/>
  </a>
  <img src="https://img.shields.io/badge/Plasma-6.5%2B-blue?style=flat-square&logo=kde&logoColor=white" alt="Plasma 6.5+"/>
  <img src="https://img.shields.io/badge/Qt-6-green?style=flat-square&logo=qt&logoColor=white" alt="Qt6"/>
  <img src="https://img.shields.io/badge/License-GPL--3.0-orange?style=flat-square" alt="License"/>
</p>

---

![Fancy Tasks NG Screenshot](media/screenshots.png)

---

## What is this?

**Fancy Tasks NG** is an alternative task manager for KDE Plasma 6. It builds upon the native task manager concepts by offering deeper customization and additional visual features like animated activity indicators, smart notification badges on app icons, volume scroll controls, dynamic hover zoom, centered alignment, and rich tooltips.

## Why this fork exists (A personal story)

I used the original [FancyTasks](https://github.com/alexankitty/FancyTasks) by [alexankitty](https://github.com/alexankitty) for many years. When Plasma 6 came out, I thought the project was dead. Later, I found a fork ([FancyTasksPlus](https://github.com/SushiTrashXD/FancyTasksPlus) by [SushiTrashXD](https://github.com/SushiTrashXD)) that attempted to port it to Plasma 6. 

Unfortunately, as Plasma continued to evolve (especially after 6.4), the code started breaking and the widget stopped working entirely. I temporarily went back to the standard Plasma task manager, but I really missed the features I was used to. 

So, I decided to fork the project for myself just to restore basic compatibility with modern Plasma. After getting it to work, I started making a few small tweaks here and there. What started as a simple compatibility fix quickly grew into a major overhaul. I ended up completely rewriting large chunks of the codebase, removing legacy code, and adding a bunch of new features I had always wanted. Thus, **Fancy Tasks NG** (Next Generation) was born.

## Overview of Capabilities

Fancy Tasks NG is a standalone task manager widget that includes the following features:
- **Alignment:** Built-in option to align tasks to the center of the panel.
- **Background Data Integration:** A custom D-Bus bridge enables the display of unread message badges and task progress bars directly on pinned icons, even if the application has no active windows.
- **Interaction Shortcuts:** Support for adjusting the volume of individual applications via mouse wheel scroll over their icons.
- **Configuration Preview:** A Live Preview component in the settings window displays changes in real time before they are applied.
- **Visual Effects:** Configurable options for icon hover zoom animations, custom indicator styles, and particle effects when closing windows.

For a complete list of features and version history, refer to the [CHANGELOG](CHANGELOG.md).

## Requirements

- **KDE Plasma 6.5** (or newer)

## How to install

### From source (Highly Recommended)
This is the best way to ensure you have the absolute latest version:

```bash
# 1. Grab the code
git clone https://github.com/daydve/FancyTasksNG.git
cd FancyTasksNG

# 2. Build and install (this handles everything for you)
make install
```
Once it's done, right-click your panel, select **Add Widgets**, and look for **"Fancy Tasks NG"**.

### From a pre-built package
If you prefer not to use `make`, you can download the latest `FancyTasksNG.plasmoid` file from the [Releases page](https://github.com/daydve/FancyTasksNG/releases) and install it from the terminal:

```bash
kpackagetool6 -t Plasma/Applet --install FancyTasksNG.plasmoid
```

### From the KDE Store
You can also grab it from the [KDE Store](https://store.kde.org/p/2350434) straight through the Plasma "Get New Widgets" dialog.
*(Note: The KDE Store version might occasionally be a bit behind the GitHub releases.)*

## Keeping it updated

If you installed from source, updating is a breeze. Just open a terminal in your cloned `FancyTasksNG` folder and run:

```bash
git pull
make update
```
This will fetch the latest code, recompile what's needed, install the update, and seamlessly restart Plasma for you. 

## Uninstallation

If you ever need to remove it, make sure you first delete any Fancy Tasks NG widgets from your panels. Then run:

```bash
make uninstall
```

## Contributing
Found a bug? Have a great idea for a feature? Want to help translate the widget into your language? All contributions are welcome! 

Head over to the [GitHub Issues tracker](https://github.com/daydve/FancyTasksNG/issues) to report bugs or request features. If you want to help with translations, you'll find the `.po` files in the `tools/translate/` directory.

## Acknowledgements

This project wouldn't exist without the amazing work of the original authors and the KDE community. A massive thank you to:

| Who | What they did |
|---|---|
| [SushiTrashXD](https://github.com/SushiTrashXD) | Created FancyTasksPlus (the initial Plasma 6 port that served as the base for this fork). |
| [Alexandra Stone](https://github.com/alexankitty) | Created the original FancyTasks for Plasma 5, pioneering the animated indicators and badges. |
| [Luis Bocanegra](https://github.com/luisbocanegra) | Implemented the original hover-zoom logic. |
| The Community | Everyone who has submitted bug reports, PRs, and ideas. |

---

<p align="center">
  <sub>Licensed under GPL-3.0-or-later &nbsp;·&nbsp; Maintained by <a href="https://github.com/daydve">Vitaliy Elin</a></sub>
</p>
