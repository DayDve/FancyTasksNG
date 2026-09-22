## What does this PR do?

<!-- Short description of the change and why it's needed. Link related issues, e.g. "fixes #123". -->

## How was this tested?

<!-- e.g. `make test` (plasmawindowed) on Plasma 6.x, Wayland/X11, or manual steps. -->

## Checklist

- [ ] Tested locally (`make test`, or `make install` if the change needs a full panel restart to verify)
- [ ] Ran `qmllint` on changed `.qml` files - no new warnings
- [ ] Updated `CHANGELOG.md` under `[Unreleased]` if this is a user-visible change
- [ ] New/changed UI strings use `Wrappers.i18n(...)`, not hardcoded text
- [ ] Targets Plasma 6.5+ / Qt6 (no `PlasmaCore` or other deprecated APIs)
