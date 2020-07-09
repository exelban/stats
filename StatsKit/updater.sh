#!/bin/bash

DMG_PATH="$HOME/Download/Stats.dmg"
MOUNT_PATH="/tmp/Stats"
APPLICATION_PATH="/Applications/"

while [[ "$#" > 0 ]]; do case $1 in
  -d|--dmg) DMG_PATH="$2"; shift;;
  -a|--app) APPLICATION_PATH="$2"; shift;;
  -m|--mount) MOUNT_PATH="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

rm -rf $APPLICATION_PATH/Stats.app
cp -rf $MOUNT_PATH/Stats.app $APPLICATION_PATH/Stats.app

$APPLICATION_PATH/Stats.app/Contents/MacOS/Stats --dmg-path "$DMG_PATH" --mount-path "$MOUNT_PATH"

echo "New version started"
