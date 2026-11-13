#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-FileCopyrightText: 2022-2023 Alexandra <alexankitty@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/functions.sh"

PACKAGE_DIR="$(readlink -f "${SCRIPT_DIR}/../package")"
TEMP_SHARE="/tmp/fancytasks-preview-$(whoami)/share"

log_info "1. Compiling translations..."
"${SCRIPT_DIR}/compile_messages.sh"

log_info "1b. Syncing cfg_*Default values with main.xml..."
python3 "${SCRIPT_DIR}/sync_defaults.py"

log_info "2. Setting up temporary locale prefix..."
# Create a fake XDG data structure to allow gettext/KI18n to find catalogs
# without installing the package into the system.
rm -rf "$(dirname "${TEMP_SHARE}")"
mkdir -p "${TEMP_SHARE}"
ln -s "${PACKAGE_DIR}/contents/locale" "${TEMP_SHARE}/locale"

# Modes:
#   window   (default) plasmawindowed in the current session.
#   panel    a nested KWin + plasmashell with the widget in a bottom panel.
#   desktop  the same, with the widget on the desktop instead.
# For panel and desktop, SCREEN=WIDTHxHEIGHT opens the nested KWin as a window
# of that size; without it, it goes full screen on the current monitor. The
# nested screen is as large as that window in this monitor's logical pixels,
# so a screen bigger than the monitor is modelled by its proportions:
# 5120x1440 -> SCREEN=2560x720.
MODE="${1:-window}"

# Point XDG_DATA_DIRS to our fake share directory.
# This ensures plasmawindowed finds the translations for our domain.
export XDG_DATA_DIRS="${TEMP_SHARE}:${XDG_DATA_DIRS:-}"
export QT_LOGGING_RULES="kf.*=false;org.kde.*=false"
export QML_DISABLE_DISK_CACHE="true"

if [[ "${MODE}" == "window" ]]; then
    log_info "3. Starting plasmawindowed from local source..."
    plasmawindowed "${PACKAGE_DIR}"
    exit 0
fi

if [[ "${MODE}" != "panel" && "${MODE}" != "desktop" ]]; then
    log_error "Unknown mode '${MODE}', expected window, panel or desktop"
    exit 1
fi

KWIN_SIZE=(--fullscreen true)
if [[ -n "${SCREEN:-}" ]]; then
    if [[ ! "${SCREEN}" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        log_error "SCREEN must look like 2560x720, got '${SCREEN}'"
        exit 1
    fi
    KWIN_SIZE=(--width "${BASH_REMATCH[1]}" --height "${BASH_REMATCH[2]}")
fi

log_info "3. Starting a nested KWin + plasmashell (${MODE}, screen ${SCREEN:-full screen})..."
log_info "   Right Ctrl in the nested window grabs or releases the pointer."

NEST_DIR="$(dirname "${TEMP_SHARE}")"
mkdir -p "${NEST_DIR}/config" "${TEMP_SHARE}/plasma/plasmoids" "${NEST_DIR}/dbus-services"
# The widget straight from the source tree; the real data dir stays behind it
# for themes and icons.
ln -s "${PACKAGE_DIR}" "${TEMP_SHARE}/plasma/plasmoids/io.github.daydve.fancytasksng"
# The look of the real session, nothing else from its config. plasma-welcomerc
# keeps the Welcome Center from opening as on a first login.
for f in kdeglobals plasmarc kwinrc plasma-welcomerc; do
    [[ -f "${HOME}/.config/${f}" ]] && cp "${HOME}/.config/${f}" "${NEST_DIR}/config/"
done

# The GTK config module of kded6 finds xsettingsd with pgrep and signals it to
# reload, and pgrep finds the real session's one too. Hide it from the nested
# session with a pgrep that never finds xsettingsd.
mkdir -p "${NEST_DIR}/bin"
cat > "${NEST_DIR}/bin/pgrep" <<'EOS'
#!/bin/bash
[[ " $* " == *xsettingsd* ]] && exit 1
exec /usr/bin/pgrep "$@"
EOS
chmod +x "${NEST_DIR}/bin/pgrep"

# Everything runs on its own D-Bus session bus: on the real one the nested
# KWin takes over the global shortcuts (Alt+Tab etc.) and leaves them dead on
# exit. Services that talk to the outside world are masked on that bus.
for svc in org.kde.kdeconnect; do
    printf '[D-BUS Service]\nName=%s\nExec=/bin/false\n' "${svc}" > "${NEST_DIR}/dbus-services/${svc}.service"
done
cat > "${NEST_DIR}/dbus.conf" <<EOS
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <servicedir>${NEST_DIR}/dbus-services</servicedir>
  <include>/usr/share/dbus-1/session.conf</include>
</busconfig>
EOS

# Wallpaper with the controls written on it: in full screen the nested
# session covers the whole monitor and there's no title bar to hint at them.
# It's fitted, not cropped, so the text survives on any screen shape, and the
# bars around it are the image's own colour. (The layout script below is in
# single quotes: no apostrophes in it.)
cat > "${NEST_DIR}/wallpaper.svg" <<'EOS'
<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">
  <rect width="1600" height="900" fill="#1d2a36"/>
  <g fill="#c8d3dc" font-family="sans-serif" text-anchor="middle">
    <text x="800" y="90" font-size="44" font-weight="bold">Fancy Tasks NG test session</text>
    <text x="800" y="145" font-size="30">Alt+F4: quit (while the pointer isn't grabbed)</text>
    <text x="800" y="190" font-size="30">Right Ctrl: grab or release the pointer and keyboard</text>
  </g>
</svg>
EOS

if [[ "${MODE}" == "panel" ]]; then
    TASKS_IN_PANEL='p.addWidget("io.github.daydve.fancytasksng");'
    TASKS_ON_DESKTOP=''
else
    TASKS_IN_PANEL=''
    TASKS_ON_DESKTOP='desktops()[0].addWidget("io.github.daydve.fancytasksng", 100, 260, 900, 120);'
fi

# kwin_wayland starts a single program, so the session is a script. It waits
# for plasmashell to lay out its default panel, then replaces the layout.
cat > "${NEST_DIR}/session.sh" <<EOS
#!/bin/bash
plasmashell --no-respawn &
shell=\$!
eval_js() { qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "\$1" 2>/dev/null; }
for _ in \$(seq 100); do
    [[ "\$(eval_js 'print(panels().length)')" =~ ^[1-9] ]] && break
    sleep 0.2
done
eval_js '
panels().forEach(function (old) { old.remove(); });
var p = new Panel;
p.location = "bottom";
p.addWidget("org.kde.plasma.kickoff");
${TASKS_IN_PANEL}
p.addWidget("org.kde.plasma.marginsseparator");
p.addWidget("org.kde.plasma.systemtray");
p.addWidget("org.kde.plasma.digitalclock");
p.addWidget("org.kde.plasma.showdesktop");
${TASKS_ON_DESKTOP}
desktops().forEach(function (d) {
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file://${NEST_DIR}/wallpaper.svg");
    d.writeConfig("FillMode", 1);
    d.writeConfig("Color", "#1d2a36");
});
'
# A couple of windows, so tasks and tooltips have something to show.
konsole --separate &
kcalc &
wait \${shell}
EOS
chmod +x "${NEST_DIR}/session.sh"

# The nested KWin and everything the private bus starts on demand (kded6,
# dconf, kactivitymanagerd, portals...) inherit this environment, so it must
# point away from the real session before dbus-run-session: otherwise kded6
# alone rewrites the real GTK and xsettingsd config, and the reload that
# follows crashes some running apps (Bitwarden). DISPLAY goes too, so nothing
# reaches the real session's Xwayland. The real data dir stays readable,
# behind the temporary one, for themes and icons.
mkdir -p "${NEST_DIR}/state" "${NEST_DIR}/cache"
export XDG_CONFIG_HOME="${NEST_DIR}/config"
export XDG_DATA_HOME="${TEMP_SHARE}"
export XDG_STATE_HOME="${NEST_DIR}/state"
export XDG_CACHE_HOME="${NEST_DIR}/cache"
export XDG_DATA_DIRS="${XDG_DATA_DIRS}:${HOME}/.local/share"
unset DISPLAY XAUTHORITY
export PATH="${NEST_DIR}/bin:${PATH}"

# Services the private bus starts on demand (kded6, portals, ksecretd...)
# outlive the session, and they hold the log pipe below open, so the script
# wouldn't even return. Everything still running with the test config dir in
# its environment is ended right after the session, and on Ctrl+C.
end_test_processes() {
    local pid
    for pid in $(pgrep -u "$(id -u)"); do
        grep -qzF "XDG_CONFIG_HOME=${NEST_DIR}/config" "/proc/${pid}/environ" 2> /dev/null && kill "${pid}" 2> /dev/null
    done
    return 0
}
trap end_test_processes EXIT

# dbus-daemon logs every service activation; that's noise here.
{
    dbus-run-session --config-file="${NEST_DIR}/dbus.conf" \
        kwin_wayland "${KWIN_SIZE[@]}" --no-lockscreen "${NEST_DIR}/session.sh" || true
    end_test_processes
} 2>&1 | { grep --line-buffered -v '^dbus-daemon\[' || true; }
