# Translations

Translations are generated within the repository and automatically bundled into the compiled `*.plasmoid` package.

## Updating and Compiling

Everything is managed via `make` from the **root directory of the project**:

* `make translate` - Extracts new translation strings from QML/C++ code into `template.pot`, merges them into existing `.po` files, and then compiles the `.po` files into binary `.mo` format.
* `make build` - Automatically triggers compiling translations before creating the plasmoid file.

## Adding a New Translation

1. Copy the `tools/translate/languages/template.pot` file.
2. Name it using your locale's code (e.g., `es.po` for Spanish, `de.po` for German).
3. Place it in `tools/translate/languages/`.
4. Run `make translate` to compile it.
5. Create a Pull Request with your `.po` file!

## Links

* [KDE Widget Translations](https://zren.github.io/kde/docs/widget/#translations-i18n)
* [KDE Localization Tutorial](https://techbase.kde.org/Development/Tutorials/Localization/i18n_Build_Systems)
* [KI18n Framework API](https://api.kde.org/frameworks/ki18n/html/prg_guide.html)

## Status
| Locale   | Lines   | % Done |
|----------|---------|--------|
| Template | 252     |        |
| nl       | 60/252  | 23%    |
| pt_BR    | 63/252  | 25%    |
| ru       | 252/252 | 100%   |
| zh_CN    | 60/252  | 23%    |
