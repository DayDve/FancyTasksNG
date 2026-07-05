#!/bin/bash
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Collects system environment information needed to diagnose Fancy Tasks NG issues.
# Produces a plain-text report with personal data (home path, username, hostname)
# masked. Usage: ./tools/diag.sh [output_path]

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/functions.sh"

OUT="${1:-${SCRIPT_DIR}/../fancytasks-diag.txt}"
OUT="$(readlink -f "${OUT}")"
mkdir -p "$(dirname "${OUT}")"

REPO_ROOT="$(readlink -f "${SCRIPT_DIR}/..")"
METADATA_FILE="${REPO_ROOT}/package/metadata.json"
APPSRC="${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"

# Buffer for the detailed sections; summary values are collected separately.
BUF="$(mktemp)"
trap 'rm -f "${BUF}"' EXIT

# Summary fields (key=value), written to the top of the final report.
declare -A SUM

emit() { echo "$*" >> "${BUF}"; }
section() { echo "" >> "${BUF}"; echo "### ${1}" >> "${BUF}"; }

# --- Plasmoid version (source) ---------------------------------------------
FTN_ID="$(get_metadata 'Id' "${METADATA_FILE}" 2>/dev/null || echo '?')"
FTN_VER="$(get_metadata 'Version' "${METADATA_FILE}" 2>/dev/null || echo '?')"
SUM[plasmoid_id]="${FTN_ID}"
SUM[plasmoid_version]="${FTN_VER}"

section "Plasmoid version (source tree)"
emit "ID:      ${FTN_ID}"
emit "Version: ${FTN_VER}"

# --- Plasmoid version (installed) ------------------------------------------
section "Plasmoid version (installed)"
if command -v kpackagetool6 &> /dev/null; then
    kpackagetool6 -t Plasma/Applet --show "${FTN_ID}" 2>&1 | sed 's/^/  /' >> "${BUF}" || emit "(not installed)"
else
    emit "(kpackagetool6 not available)"
fi

# --- Git info ---------------------------------------------------------------
section "Git checkout"
if [ -d "${REPO_ROOT}/.git" ]; then
    GIT_BRANCH="$(git -C "${REPO_ROOT}" branch --show-current 2>/dev/null || echo '?')"
    GIT_COMMIT="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo '?')"
    GIT_DATE="$(git -C "${REPO_ROOT}" log -1 --format=%ci 2>/dev/null || echo '?')"
    GIT_DIRTY="$(git -C "${REPO_ROOT}" status --porcelain 2>/dev/null | wc -l)"
    emit "Branch:   ${GIT_BRANCH}"
    emit "Commit:   ${GIT_COMMIT}"
    emit "Date:     ${GIT_DATE}"
    emit "Dirty (uncommitted) files: ${GIT_DIRTY}"
    SUM[git_branch]="${GIT_BRANCH}"
    SUM[git_commit]="${GIT_COMMIT}"
    SUM[git_dirty]="${GIT_DIRTY}"
else
    emit "(not a git checkout — likely a ZIP download or installed .plasmoid)"
    SUM[git_branch]="(no git)"
fi

# --- OS --------------------------------------------------------------------
section "OS"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    emit "PRETTY_NAME: ${PRETTY_NAME:-(unset)}"
    emit "ID: ${ID:-(unset)}"
    emit "VERSION_ID: ${VERSION_ID:-(unset)}"
    SUM[os]="${PRETTY_NAME:-(unset)}"
else
    emit "(no /etc/os-release)"
    SUM[os]="(unknown)"
fi

section "Kernel"
KERN="$(uname -srm 2>/dev/null || echo '(uname unavailable)')"
emit "${KERN}"
SUM[kernel]="${KERN}"

section "Session"
SUM[session]="${XDG_SESSION_TYPE:-(unset)}"
emit "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-(unset)}"
emit "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-(unset)}"
emit "DISPLAY=${DISPLAY:-(unset)}"
emit "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-(unset)}"

section "Plasma / KWin"
PLASMA_VER="$(plasmashell --version 2>/dev/null | head -1 || echo '?')"
KWIN_VER="$(kwin_wayland --version 2>/dev/null || kwin_x11 --version 2>/dev/null | head -1 || echo '?')"
emit "${PLASMA_VER}"
emit "${KWIN_VER}"
SUM[plasma]="${PLASMA_VER}"
SUM[kwin]="${KWIN_VER}"

section "Qt (qmake)"
QT_VER="$(qmake6 --version 2>/dev/null | tail -1 || qmake --version 2>/dev/null | tail -1 || echo '?')"
emit "${QT_VER}" 2>/dev/null || emit "(qmake not available)"
SUM[qt]="${QT_VER}"

section "GPU (lspci)"
if command -v lspci &> /dev/null; then
    GPU_LINE="$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' | head -1)"
    emit "${GPU_LINE:-"(no GPU entries found)"}"
    SUM[gpu]="${GPU_LINE:-(unknown)}"
else
    emit "(lspci not available)"
    SUM[gpu]="(lspci unavailable)"
fi

section "Display / Scale (kscreen-doctor)"
if command -v kscreen-doctor &> /dev/null; then
    KSCREEN_OUT="$(kscreen-doctor --outputs 2>/dev/null | grep -E 'Output|enabled|Scale|Geometry')"
    emit "${KSCREEN_OUT}"
    SCALE_VAL="$(echo "${KSCREEN_OUT}" | grep -i 'Scale:' | head -1 | sed 's/.*Scale: *//')"
    SUM[scale]="${SCALE_VAL:-(unknown)}"
else
    emit "(kscreen-doctor not available)"
    SUM[scale]="(unknown)"
fi

section "Theme"
if command -v kreadconfig6 &> /dev/null; then
    THEME_LAF="$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage 2>/dev/null || echo '?')"
    THEME_STYLE="$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle 2>/dev/null || echo '?')"
    THEME_COLOR="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || echo '?')"
    emit "${THEME_LAF}"
    emit "${THEME_STYLE}"
    emit "${THEME_COLOR}"
    SUM[theme]="${THEME_LAF}"
else
    emit "(kreadconfig6 not available)"
    SUM[theme]="(unknown)"
fi

# --- Active containments & widgets (from plasma-appletsrc) -----------------
section "Active Plasma layout (containments and widgets)"
if [ -f "${APPSRC}" ]; then
    emit "Source: ${APPSRC}"
    emit ""
    awk '
    function reset_app() { app = ""; }
    /^\[Containments\]\[[0-9]+\]$/ {
        if (cont != "") { printf ")\n" }
        s = $0; sub(/^\[Containments\]\[/, "", s); sub(/\].*/, "", s)
        cont = s; reset_app()
        printf "Containment #%s (", cont
        first = 1
    }
    /^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]/ {
        s = $0
        sub(/^\[Containments\]\[[0-9]+\]\[Applets\]\[/, "", s)
        sub(/\].*/, "", s)
        app = s
    }
    /^plugin=/ {
        val = substr($0, 8)
        if (app != "") {
            printf "\n  Applet #%s: %s", app, val
        } else if (cont != "") {
            printf "%splugin=%s", (first ? "" : " "), val
            first = 0
        }
    }
    /^(location|formfactor|screen)=/ && app == "" && cont != "" {
        split($0, kv, "=")
        printf " %s=%s", kv[1], kv[2]
        first = 0
    }
    END { if (cont != "") printf ")\n" }
    ' "${APPSRC}" >> "${BUF}" 2>&1 || emit "(failed to parse appletsrc)"
else
    emit "(plasma-org.kde.plasma.desktop-appletsrc not found)"
fi

# --- Recent plasmashell logs ------------------------------------------------
section "Recent plasmashell logs (last 80 lines)"
if journalctl --user -b -u plasma-plasmashell.service --no-pager 2>/dev/null | tail -80 >> "${BUF}"; then
    :
else
    emit "(journalctl not available)"
fi

emit ""

# --- Build the final report: summary header + detailed buffer ---------------
{
    echo "Fancy Tasks NG — diagnostic report"
    echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo ""
    echo "## Summary"
    for key in plasmoid_id plasmoid_version git_branch git_commit git_dirty os kernel session plasma kwin qt gpu scale theme; do
        printf "%-18s %s\n" "${key}:" "${SUM[$key]:-(n/a)}"
    done
    echo ""
    echo "## Details"
    cat "${BUF}"
} > "${OUT}"

# --- Apply PII masking to the whole file ------------------------------------
REPORT_USER="$(id -un 2>/dev/null || echo "${USER:-unknown}")"
REPORT_HOST="$(hostname 2>/dev/null || echo '')"
sed -i \
    -e "s|/home/${REPORT_USER}|/home/\$USER|g" \
    -e "s|/Users/${REPORT_USER}|/Users/\$USER|g" \
    -e "s|\b${REPORT_USER}\b|\$USER|g" \
    -e 's/\b\([0-9a-fA-F]\{2\}:\)\{5\}[0-9a-fA-F]\{2\}\b/...MAC.../g' \
    -e 's/machine-id=[0-9a-fA-F]\{32\}/machine-id=...masked.../g' \
    -e 's/\b[0-9a-fA-F]\{8\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{12\}\b/...UUID.../g' \
    "${OUT}"

# Mask hostname only inside journalctl log lines (where it precedes "plasmashell[").
if [ -n "${REPORT_HOST}" ]; then
    sed -i -E "s/ ${REPORT_HOST} plasmashell\[/ \$HOSTNAME plasmashell[/g" "${OUT}"
fi

# Strip ANSI color codes for readability.
sed -i 's/\x1b\[[0-9;]*m//g' "${OUT}"

log_success "Diagnostic report written to: ${OUT}"
log_info "Review it, then attach to your GitHub issue."
