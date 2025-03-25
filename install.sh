#!/bin/sh
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
sh $SCRIPT_DIR/build.sh
kpackagetool6 -i $SCRIPT_DIR/release/FancyTasks.tar.gz
sh ./iconinstall.sh
