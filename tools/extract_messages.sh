#!/bin/bash
# SPDX-FileCopyrightText: 2023 Alexandra Stone <alexankitty@gmail.com>
# SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/functions.sh"

# Use relative path so xgettext writes relative paths to .po files!
cd "$(readlink -f "${SCRIPT_DIR}/../")"

PACKAGE_DIR="package"
METADATA_FILE="${PACKAGE_DIR}/metadata.json"

# Use a unified function to retrieve data
plasmoidName=$(get_metadata "Id" "${METADATA_FILE}")
widgetName="${plasmoidName##*.}"
bugAddress=$(get_metadata "Website" "${METADATA_FILE}")

projectName="plasma_applet_${plasmoidName}"

if [ -z "$plasmoidName" ]; then
    log_error "Couldn't read 'Id' from metadata.json."
    exit 1
fi

if ! command -v xgettext &> /dev/null; then
    log_error "xgettext command not found."
    log_info "Running 'sudo apt install gettext'"
    sudo apt install gettext
fi

log_info "Extracting messages"
potArgs="--from-code=UTF-8 --width=200 --add-location=file"

grep -rl \
  --include="*.qml" \
  --include="*.js" \
  --include="*.cpp" \
  --include="*.h" \
  --include="*.c" 'i18n' "${PACKAGE_DIR}" \
| sort -u | \
xgettext \
    ${potArgs} \
    --files-from=- \
    -C -kde \
    -ci18n \
    -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
    -kki18n:1 -kki18nc:1c,2 -kki18np:1,2 -kki18ncp:1c,2,3 \
    -kxi18n:1 -kxi18nc:1c,2 -kxi18np:1,2 -kxi18ncp:1c,2,3 \
    -kkxi18n:1 -kkxi18nc:1c,2 -kkxi18np:1,2 -kkxi18ncp:1c,2,3 \
    -kI18N_NOOP:1 -kI18NC_NOOP:1c,2 \
    -kI18N_NOOP2:1c,2 -kI18N_NOOP2_NOSTRIP:1c,2 \
    -ktr2i18n:1 -ktr2xi18n:1 \
    -kN_:1 \
    -kaliasLocale \
    --package-name="${widgetName}" \
    --msgid-bugs-address="${bugAddress}" \
    -D "." \
    -o "tools/translate/languages/template.pot.new"

sed -i 's/# SOME DESCRIPTIVE TITLE./'"# Translation of ${widgetName} in LANGUAGE"'/' "tools/translate/languages/template.pot.new"
sed -i 's/# Copyright (C) YEAR THE PACKAGE'"'"'S COPYRIGHT HOLDER/'"# Copyright (C) $(date +%Y)"'/' "tools/translate/languages/template.pot.new"

cd "tools/translate/languages"

if [ -f "template.pot" ]; then
    # We use || true in grep to not fail if missing
    newPotDate=$(grep "POT-Creation-Date:" template.pot.new | sed 's/.\{3\}$//' || true)
    oldPotDate=$(grep "POT-Creation-Date:" template.pot | sed 's/.\{3\}$//' || true)
    
    if [ -n "$newPotDate" ] && [ -n "$oldPotDate" ]; then
        sed -i 's/'"${newPotDate}"'/'"${oldPotDate}"'/' "template.pot.new"
    fi
    
    # diff returns 1 if files differ, which triggers set -e, so we use || true
    changes=$(diff "template.pot" "template.pot.new" || true)
    
    if [ -n "$changes" ]; then
        if [ -n "$newPotDate" ] && [ -n "$oldPotDate" ]; then
            sed -i 's/'"${oldPotDate}"'/'"${newPotDate}"'/' "template.pot.new"
        fi
        mv "template.pot.new" "template.pot"
        log_info "Template updated."
    else
        rm "template.pot.new"
        log_info "No changes in template."
    fi
else
    mv "template.pot.new" "template.pot"
fi

log_success "Done extracting messages"

log_info "Merging messages"
catalogs=$(find . -name '*.po' | sort || true)
if [ -n "$catalogs" ]; then
    for cat in $catalogs; do
        log_info "$cat"
        catLocale=$(basename "${cat%.*}")
        
        cp "$cat" "$cat.new"
        sed -i 's/"Content-Type: text\/plain; charset=CHARSET\\n"/"Content-Type: text\/plain; charset=UTF-8\\n"/' "$cat.new"

        msgmerge \
            --width=400 \
            --add-location=file \
            --no-fuzzy-matching \
            -o "$cat.new" \
            "$cat.new" "${SCRIPT_DIR}/translate/languages/template.pot"

        sed -i 's/# SOME DESCRIPTIVE TITLE./'"# Translation of ${widgetName} in ${catLocale}"'/' "$cat.new"
        mv "$cat.new" "$cat"
    done
fi

update_translation_status "${SCRIPT_DIR}/translate/languages" "${SCRIPT_DIR}/translate/ReadMe.md"

log_success "Done merging messages"
