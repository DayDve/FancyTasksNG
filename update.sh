#!/bin/sh
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
sh $SCRIPT_DIR/build.sh
kpackagetool6 -u $SCRIPT_DIR/release/FancyTasks.tar.gz

# Restart plasmashell
if systemctl --user is-active --quiet plasma-plasmashell.service; then
    systemctl --user restart plasma-plasmashell.service
else
    killall plasmashell
    plasmashell > /dev/null 2>&1 &
fi

sh ./iconinstall.sh
