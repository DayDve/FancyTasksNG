#!/bin/bash
SCRIPT_DIR=$(dirname $(readlink -f "$0"))

echo "Compiling translations..."
bash "$SCRIPT_DIR/package/translate/build"

echo "Updating plasmoid ..."
kpackagetool6 -t Plasma/Applet --upgrade "$SCRIPT_DIR/package"

echo "Restarting Plasma..."
if systemctl --user is-active --quiet plasma-plasmashell.service; then
  systemctl --user restart plasma-plasmashell.service
else
  plasmashell --replace > /dev/null 2>&1 &
  disown
fi

bash "$SCRIPT_DIR/iconinstall.sh"
echo "Update complete."
