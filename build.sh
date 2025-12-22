#!/bin/bash
SCRIPT_DIR=$(dirname $(readlink -f "$0"))

cd "$SCRIPT_DIR/package/translate/"
bash ./merge
bash ./build
cd "$SCRIPT_DIR"

rm -rf "$SCRIPT_DIR/release"
mkdir -p "$SCRIPT_DIR/build"
mkdir -p "$SCRIPT_DIR/release"

cp -r "$SCRIPT_DIR/package/contents" "$SCRIPT_DIR/build"
cp "$SCRIPT_DIR/package/metadata.json" "$SCRIPT_DIR/build"
cp "$SCRIPT_DIR/package/FancyTasks.png" "$SCRIPT_DIR/build"

cd "$SCRIPT_DIR/build"
tar cf "$SCRIPT_DIR/release/FancyTasks.tar.gz" .
cd "$SCRIPT_DIR"

rm -rf "$SCRIPT_DIR/build"
echo "Build complete: $SCRIPT_DIR/release/FancyTasks.tar.gz"
