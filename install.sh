#!/bin/bash
SCRIPT_DIR=$(dirname $(readlink -f "$0"))

echo "Compiling translations..."
bash "$SCRIPT_DIR/package/translate/build"

echo "Installing plasmoid ..."
kpackagetool6 -t Plasma/Applet --install "$SCRIPT_DIR/package"

bash "$SCRIPT_DIR/iconinstall.sh"
echo "Install complete."
