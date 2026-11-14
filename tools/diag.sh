#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Collects the information needed to diagnose Fancy Tasks NG issues into a
# plain-text report with personal data (home path, username, hostname) masked.
#
# Self-contained on purpose: the bug report template allows downloading just
# this file, so it must not source functions.sh. Also deliberately not
# `set -e` - a diagnostic run must survive any single probe failing.
#
# Usage: ./tools/diag.sh [output_path]   (or: make diag)

set -uo pipefail

PLUGIN_ID="io.github.daydve.fancytasksng"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(readlink -f "${SCRIPT_DIR}/..")"
if [ -f "${REPO_ROOT}/package/metadata.json" ]; then
    SOURCE_PKG="${REPO_ROOT}/package"
    DEFAULT_OUT="${REPO_ROOT}/fancytasks-diag.txt"
else
    SOURCE_PKG=""
    DEFAULT_OUT="${PWD}/fancytasks-diag.txt"
fi

OUT="$(readlink -f "${1:-${DEFAULT_OUT}}")"
mkdir -p "$(dirname "${OUT}")"

CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
APPSRC="${CONFIG_HOME}/plasma-org.kde.plasma.desktop-appletsrc"
SHELLRC="${CONFIG_HOME}/plasmashellrc"

# Probes run under an English locale so output (kinfo, dates) is greppable
# and readable regardless of the reporter's language. Must be a UTF-8 one:
# under plain "C" every Qt tool prints a locale warning on each call.
if locale -a 2> /dev/null | grep -qiE '^c\.utf-?8$'; then
    export LC_ALL=C.UTF-8
fi

BUF="$(mktemp)"
trap 'rm -f "${BUF}"' EXIT

declare -A SUM
WARNINGS=()

emit() { printf '%s\n' "$*" >> "${BUF}"; }
section() { printf '\n### %s\n' "$1" >> "${BUF}"; }
warn() { WARNINGS+=("$1"); }
have() { command -v "$1" &> /dev/null; }

# Usage: json_value <key> <metadata.json>
json_value() {
    grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$2" 2> /dev/null | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/'
}

# Prints every line of every KConfig group whose header starts with $2.
# Usage: kconfig_groups <file> <group_prefix>
kconfig_groups() {
    awk -v prefix="$2" '
        /^\[/ { inGroup = (index($0, prefix) == 1); if (inGroup) print ""; }
        inGroup && NF { print "  " $0 }
    ' "$1"
}

# Fingerprint of a package's code, comparable between a reporter's install
# and a release .plasmoid: compiled translations and Python bytecode differ
# per machine and are excluded, as is metadata.json (version-stamped on build).
package_fingerprint() {
    (cd "$1" && find contents -type f ! -path 'contents/locale/*' ! -name '*.pyc' -print0 \
        | sort -z | xargs -0 md5sum 2> /dev/null | md5sum | cut -c1-12)
}

# --- Installed copies --------------------------------------------------------
# plasmashell resolves the plasmoid through XDG_DATA_HOME first, then
# XDG_DATA_DIRS in order - the first hit is the copy actually loaded, any
# later one is shadowed. A stale copy in one of these is a common cause of
# "it still shows the old error after updating".
section "Installed copies (first one is what plasmashell loads)"
DATA_DIRS=("${XDG_DATA_HOME:-${HOME}/.local/share}")
IFS=':' read -r -a _xdg_dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
DATA_DIRS+=("${_xdg_dirs[@]}")

EFFECTIVE_PKG=""
declare -A SEEN_DIRS
for d in "${DATA_DIRS[@]}"; do
    [ -n "${d}" ] || continue
    pkg="$(readlink -f "${d}/plasma/plasmoids/${PLUGIN_ID}" 2> /dev/null)" || continue
    [ -f "${pkg}/metadata.json" ] || continue
    [ -z "${SEEN_DIRS[${pkg}]:-}" ] || continue
    SEEN_DIRS[${pkg}]=1

    ver="$(json_value Version "${pkg}/metadata.json")"
    newest="$(find "${pkg}" -type f -printf '%C@\n' 2> /dev/null | sort -n | tail -1 | cut -d. -f1)"
    if [ -z "${EFFECTIVE_PKG}" ]; then
        EFFECTIVE_PKG="${pkg}"
        EFFECTIVE_MTIME="${newest:-0}"
        emit "[loaded]   ${pkg}"
        SUM[installed_version]="${ver:-?}"
    else
        emit "[shadowed] ${pkg}"
        warn "More than one installed copy found; only ${EFFECTIVE_PKG} is used."
    fi
    emit "  Version:     ${ver:-?}"
    emit "  Installed:   $(date -d "@${newest:-0}" '+%Y-%m-%d %H:%M:%S %z' 2> /dev/null)"
    emit "  Fingerprint: $(package_fingerprint "${pkg}")"
    [ -L "${d}/plasma/plasmoids/${PLUGIN_ID}" ] && emit "  (symlink)"
done
if [ -z "${EFFECTIVE_PKG}" ]; then
    emit "(not installed in any of: ${DATA_DIRS[*]})"
    SUM[installed_version]="(not installed)"
    warn "Fancy Tasks NG is not installed for this user."
fi

# --- Source checkout (only when run from a clone) ---------------------------
if [ -n "${SOURCE_PKG}" ]; then
    section "Source tree this script was run from"
    SRC_VER="$(json_value Version "${SOURCE_PKG}/metadata.json")"
    emit "Path:        ${REPO_ROOT}"
    emit "Version:     ${SRC_VER:-?}"
    if [ -d "${REPO_ROOT}/.git" ] && have git; then
        DESCRIBE="$(git -C "${REPO_ROOT}" describe --tags --always --dirty 2> /dev/null)"
        emit "Git:         ${DESCRIBE:-?} ($(git -C "${REPO_ROOT}" branch --show-current 2> /dev/null), $(git -C "${REPO_ROOT}" log -1 --format=%ci 2> /dev/null))"
        SUM[source_tree]="${DESCRIBE:-?}"
    else
        SUM[source_tree]="${SRC_VER:-?} (no git)"
    fi
    if [ -n "${EFFECTIVE_PKG}" ]; then
        if diff -rq -x locale -x '__pycache__' -x '*.pyc' "${SOURCE_PKG}/contents" "${EFFECTIVE_PKG}/contents" &> /dev/null; then
            emit "Installed copy matches this source tree: yes"
        else
            emit "Installed copy matches this source tree: NO"
            warn "The installed copy differs from the source tree diag.sh was run from (run 'make update' to install it)."
        fi
    fi
fi

# --- plasmashell process -----------------------------------------------------
section "plasmashell process"
SHELL_PID="$(pgrep -u "$(id -u)" -x plasmashell 2> /dev/null | head -1)"
if [ -n "${SHELL_PID}" ]; then
    ELAPSED="$(ps -o etimes= -p "${SHELL_PID}" 2> /dev/null | tr -d ' ')"
    SHELL_START=$(( $(date +%s) - ${ELAPSED:-0} ))
    emit "PID:     ${SHELL_PID}"
    emit "Started: $(date -d "@${SHELL_START}" '+%Y-%m-%d %H:%M:%S %z')"
    if [ -n "${EFFECTIVE_PKG}" ] && [ "${EFFECTIVE_MTIME:-0}" -gt "${SHELL_START}" ]; then
        emit "Installed copy is NEWER than the running plasmashell"
        warn "plasmashell was not restarted after the last install/update - it still runs the previously loaded code. Restart it: systemctl --user restart plasma-plasmashell"
    fi
else
    emit "(plasmashell is not running)"
fi

# --- System ------------------------------------------------------------------
section "System"
if have kinfo; then
    kinfo 2> /dev/null >> "${BUF}"
    SUM[plasma]="$(kinfo 2> /dev/null | sed -n 's/^KDE Plasma Version: //p')"
    SUM[frameworks]="$(kinfo 2> /dev/null | sed -n 's/^KDE Frameworks Version: //p')"
    SUM[qt]="$(kinfo 2> /dev/null | sed -n 's/^Qt Version: //p')"
else
    . /etc/os-release 2> /dev/null
    emit "Operating System: ${PRETTY_NAME:-?}"
    emit "Kernel: $(uname -srm)"
    SUM[plasma]="$(plasmashell --version 2> /dev/null | awk '{print $2}')"
    SUM[qt]="$(qtpaths6 --qt-version 2> /dev/null)"
fi
. /etc/os-release 2> /dev/null
SUM[os]="${PRETTY_NAME:-?}"
SUM[session]="${XDG_SESSION_TYPE:-?}"
emit "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-(unset)}  XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-(unset)}"
if have lspci; then
    lspci -nn 2> /dev/null | grep -iE 'vga|3d|display' | sed 's/^/GPU: /' >> "${BUF}"
fi

# --- Displays ----------------------------------------------------------------
section "Displays"
if have kscreen-doctor; then
    kscreen-doctor --outputs 2> /dev/null | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -E '^Output|enabled|disabled|Geometry|Scale|Modes' \
        | sed -E 's/(Modes: ).*/\1(omitted)/' >> "${BUF}"
    SUM[scale]="$(kscreen-doctor --outputs 2> /dev/null | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/.*Scale: *//p' | paste -sd' ')"
else
    emit "(kscreen-doctor not available)"
fi

# --- Theme -------------------------------------------------------------------
section "Theme"
if have kreadconfig6; then
    emit "Global theme:  $(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)"
    emit "Plasma style:  $(kreadconfig6 --file plasmarc --group Theme --key name --default default)"
    emit "Color scheme:  $(kreadconfig6 --file kdeglobals --group General --key ColorScheme)"
    emit "Widget style:  $(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle)"
    emit "Icon theme:    $(kreadconfig6 --file kdeglobals --group Icons --key Theme)"
    SUM[theme]="$(kreadconfig6 --file plasmarc --group Theme --key name --default default) / $(kreadconfig6 --file kdeglobals --group General --key ColorScheme)"
else
    emit "(kreadconfig6 not available)"
fi

# --- QML module dependencies -------------------------------------------------
# Every module the plasmoid imports must resolve, otherwise the whole widget
# fails to load ("Type X unavailable"). Checked against the copy that's
# actually loaded, so a stale install is checked for what it really imports.
section "QML modules imported by the plasmoid"
CHECK_PKG="${EFFECTIVE_PKG:-${SOURCE_PKG}}"
QML_DIRS=()
for q in "${QML_IMPORT_PATH:-}" "${QML2_IMPORT_PATH:-}" \
         "$(qtpaths6 --query QT_INSTALL_QML 2> /dev/null)" \
         /usr/lib/qt6/qml /usr/lib64/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/qml /usr/lib/aarch64-linux-gnu/qt6/qml; do
    IFS=':' read -r -a _parts <<< "${q}"
    for p in "${_parts[@]}"; do
        [ -n "${p}" ] && [ -d "${p}" ] && QML_DIRS+=("$(readlink -f "${p}")")
    done
done
mapfile -t QML_DIRS < <(printf '%s\n' "${QML_DIRS[@]}" | awk '!seen[$0]++')
emit "Import paths: ${QML_DIRS[*]:-(none found)}"
if [ -n "${CHECK_PKG}" ] && [ "${#QML_DIRS[@]}" -gt 0 ]; then
    MISSING=0
    while read -r module; do
        rel="${module//.//}"
        found=""
        for qd in "${QML_DIRS[@]}"; do
            if [ -f "${qd}/${rel}/qmldir" ]; then found="${qd}"; break; fi
        done
        if [ -n "${found}" ]; then
            emit "  ok       ${module}"
        else
            emit "  MISSING  ${module}"
            MISSING=$((MISSING + 1))
        fi
    done < <(grep -rhoE '^\s*import\s+[A-Za-z][A-Za-z0-9_.]*' --include='*.qml' "${CHECK_PKG}" | awk '{print $2}' | sort -u)
    if [ "${MISSING}" -gt 0 ]; then
        warn "${MISSING} QML module(s) imported by the plasmoid were not found - see the QML modules section."
    fi
fi

# --- Python D-Bus bridges ----------------------------------------------------
# Badges/progress (unity_bridge.py) and jump-list actions (desktop_actions.py)
# depend on these; without them the widget loads but those features are dead.
section "Python bridges (badges, progress, jump lists)"
if have python3; then
    emit "python3: $(python3 --version 2>&1)"
    if PYERR="$(python3 -c 'import dbus, dbus.service; from gi.repository import GLib' 2>&1)"; then
        emit "Modules dbus + gi (GLib): ok"
    else
        emit "Modules dbus + gi (GLib): FAILED - ${PYERR##*$'\n'}"
        warn "python3 dbus/gi modules are missing - badges, progress and desktop actions will not work (install python-dbus and python-gobject)."
    fi
else
    emit "python3: NOT FOUND"
    warn "python3 is not installed - badges, progress and desktop actions will not work."
fi
for name in Bridge DesktopActions; do
    if have busctl && busctl --user status "io.github.daydve.fancytasksng.${name}" &> /dev/null; then
        emit "D-Bus name io.github.daydve.fancytasksng.${name}: registered"
    else
        emit "D-Bus name io.github.daydve.fancytasksng.${name}: not registered"
    fi
done

# --- Layout ------------------------------------------------------------------
section "Plasma layout (containments and widgets)"
if [ -f "${APPSRC}" ]; then
    awk '
    /^\[Containments\]\[[0-9]+\]$/ {
        if (cont != "") printf ")\n"
        s = $0; sub(/^\[Containments\]\[/, "", s); sub(/\].*/, "", s)
        cont = s; app = ""
        printf "Containment #%s (", cont
        next
    }
    /^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$/ {
        s = $0; sub(/.*\[Applets\]\[/, "", s); sub(/\]$/, "", s)
        app = s
        next
    }
    /^\[/ { app = "-"; next }
    /^plugin=/ {
        val = substr($0, 8)
        if (app != "" && app != "-") printf "\n  Applet #%s: %s", app, val
        else if (app == "") printf " plugin=%s", val
    }
    /^(location|formfactor|lastScreen)=/ && app == "" { printf " %s", $0 }
    END { if (cont != "") printf ")\n" }
    ' "${APPSRC}" >> "${BUF}" 2>&1
    emit "(location: 3=top 4=bottom 5=left 6=right; widgets inside the system tray are its own containment)"
else
    emit "(${APPSRC} not found)"
fi

# --- Per-instance: panel + widget settings ----------------------------------
# Read straight from the KConfig files rather than via any runtime API - if
# plasmashell itself is what's broken, this still has to work.
section "Fancy Tasks NG instances"
if [ -f "${APPSRC}" ]; then
    mapfile -t INSTANCES < <(awk -v id="${PLUGIN_ID}" '
        /^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$/ {
            s = $0; sub(/^\[Containments\]\[/, "", s); sub(/\]\[Applets\]\[.*/, "", s); cont = s
            s = $0; sub(/.*\[Applets\]\[/, "", s); sub(/\]$/, "", s); app = s
            next
        }
        /^\[/ { cont = ""; app = "" }
        /^plugin=/ && cont != "" && substr($0, 8) == id { print cont "/" app }
    ' "${APPSRC}")
    SUM[instances]="${#INSTANCES[@]}"
    if [ "${#INSTANCES[@]}" -eq 0 ]; then
        emit "(no instance found in the layout)"
        warn "No Fancy Tasks NG widget is placed on any panel."
    fi
    for inst in "${INSTANCES[@]}"; do
        cont="${inst%/*}"
        app="${inst#*/}"
        emit ""
        emit "== Instance: Containment #${cont}, Applet #${app}"
        emit "Panel containment:"
        awk -v group="[Containments][${cont}]" '
            /^\[/ { inGroup = ($0 == group); next }
            inGroup && /^(plugin|location|formfactor|lastScreen|immutability)=/ { print "  " $0 }
        ' "${APPSRC}" >> "${BUF}"
        if [ -f "${SHELLRC}" ]; then
            emit "Panel view (plasmashellrc):"
            kconfig_groups "${SHELLRC}" "[PlasmaViews][Panel ${cont}]" >> "${BUF}"
        fi
        emit "Widget settings (non-default values only - anything absent is at its default):"
        kconfig_groups "${APPSRC}" "[Containments][${cont}][Applets][${app}]" >> "${BUF}"
    done
else
    emit "(${APPSRC} not found)"
fi

section "Saved task order (one group per instance, by applet id)"
TASK_ORDER_FILE="${CONFIG_HOME}/kde.org/plasmashell.conf"
if [ -f "${TASK_ORDER_FILE}" ]; then
    kconfig_groups "${TASK_ORDER_FILE}" "[TaskOrder" >> "${BUF}"
else
    emit "(none saved)"
fi

# --- Logs --------------------------------------------------------------------
# Only lines from this boot that concern the plasmoid: the unfiltered tail is
# dominated by other widgets and is useless here.
# The Python helpers log under the "fancytasksng" syslog identifier.
section "plasmashell and helper log lines about Fancy Tasks NG (this boot, last 150)"
if have journalctl; then
    LOG="$(journalctl --user -b --no-pager -o short-iso _COMM=plasmashell + SYSLOG_IDENTIFIER=fancytasksng 2> /dev/null \
        | grep -iE 'fancytasks|io\.github\.daydve|unity_bridge|desktop_actions')"
    if [ -n "${LOG}" ]; then
        printf '%s\n' "${LOG}" | tail -150 >> "${BUF}"
    else
        emit "(no matching lines)"
    fi
else
    emit "(journalctl not available)"
fi

section "Recent plasmashell crashes"
if have coredumpctl; then
    CRASHES="$(coredumpctl list --no-pager --no-legend --since=-7d plasmashell 2> /dev/null | tail -5)"
    emit "${CRASHES:-(none in the last 7 days)}"
    [ -n "${CRASHES}" ] && warn "plasmashell crashed in the last 7 days - see Recent plasmashell crashes."
else
    emit "(coredumpctl not available)"
fi

# --- Assemble: warnings + summary first, details after ----------------------
{
    echo "Fancy Tasks NG - diagnostic report"
    echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""
    if [ "${#WARNINGS[@]}" -gt 0 ]; then
        echo "## Warnings"
        printf -- '- %s\n' "${WARNINGS[@]}"
        echo ""
    fi
    echo "## Summary"
    for key in installed_version source_tree instances plasma frameworks qt os session scale theme; do
        [ -n "${SUM[$key]:-}" ] && printf '%-18s %s\n' "${key}:" "${SUM[$key]}"
    done
    echo ""
    echo "## Details"
    cat "${BUF}"
} > "${OUT}"

# --- PII masking -------------------------------------------------------------
REPORT_USER="$(id -un 2> /dev/null || echo "${USER:-unknown}")"
REPORT_HOST="$(hostname 2> /dev/null || cat /proc/sys/kernel/hostname 2> /dev/null || echo '')"
# The plugin id is shielded first so a username that happens to appear in it
# (the maintainer's own) doesn't get masked out of the id.
sed -i \
    -e "s|${PLUGIN_ID}|@@PLUGIN_ID@@|g" \
    -e "s|${HOME}|/home/\$USER|g" \
    -e "s|\b${REPORT_USER}\b|\$USER|g" \
    -e "s|@@PLUGIN_ID@@|${PLUGIN_ID}|g" \
    -e 's/\b\([0-9a-fA-F]\{2\}:\)\{5\}[0-9a-fA-F]\{2\}\b/...MAC.../g' \
    -e 's/\b[0-9a-fA-F]\{8\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{12\}\b/...UUID.../g' \
    "${OUT}"
# The hostname is only masked where journalctl puts it (right after the
# timestamp) - masking a short hostname everywhere would mangle other text.
if [ -n "${REPORT_HOST}" ]; then
    sed -i -E "s/^([0-9T:+-]+) ${REPORT_HOST} /\1 \$HOSTNAME /" "${OUT}"
fi
sed -i 's/\x1b\[[0-9;]*m//g' "${OUT}"

echo "Diagnostic report written to: ${OUT}"
if [ "${#WARNINGS[@]}" -gt 0 ]; then
    echo "Warnings found:"
    printf -- '  - %s\n' "${WARNINGS[@]}"
fi
echo "Review it, then attach it to your GitHub issue."
