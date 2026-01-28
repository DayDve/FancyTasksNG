#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
bash $SCRIPT_DIR/build.sh
kpackagetool6 -u $SCRIPT_DIR/release/FancyTasks.tar.gz
QML_DISABLE_DISK_CACHE=true plasmawindowed alexankitty.fancytasks
