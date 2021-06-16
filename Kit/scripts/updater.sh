#!/bin/bash

DMG_PATH="$HOME/Downloads/Stats.dmg"
MOUNT_PATH="/tmp/Stats"
APPLICATION_PATH="/Applications/"

STEP=""

while [[ "$#" > 0 ]]; do case $1 in
  -s|--step) STEP="$2"; shift;;
  -d|--dmg) DMG_PATH="$2"; shift;;
  -a|--app) APPLICATION_PATH="$2"; shift;;
  -m|--mount) MOUNT_PATH="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

if [[ "$STEP" == "2" ]]; then
    rm -rf $APPLICATION_PATH/Stats.app
    cp -rf $MOUNT_PATH/Stats.app $APPLICATION_PATH/Stats.app

    $APPLICATION_PATH/Stats.app/Contents/MacOS/Stats --dmg "$DMG_PATH"

    echo "New version started"
elif [[ "$STEP" == "3" ]]; then
    /usr/bin/hdiutil detach "$MOUNT_PATH"
    /bin/rm -rf "$MOUNT_PATH"
    /bin/rm -rf "$DMG_PATH"

    echo "Done"
else
    rm -rf $APPLICATION_PATH/Stats.app
    cp -rf $MOUNT_PATH/Stats.app $APPLICATION_PATH/Stats.app

    $APPLICATION_PATH/Stats.app/Contents/MacOS/Stats --dmg-path "$DMG_PATH" --mount-path "$MOUNT_PATH"

    echo "New version started"
fi
