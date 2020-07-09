#!/bin/bash

STEP=1

CURRENT_PATH=""
DMG_PATH="$HOME/Download/Stats.dmg"
MOUNT_PATH="/tmp/Stats"
APP_PATH=""
PID=""

while [[ "$#" > 0 ]]; do case $1 in
  -d|--dmg) DMG_PATH="$2"; shift;;
  -s|--step) STEP="$2"; shift;;
  -a|--app) APP_PATH="$2"; shift;;
  -p|--pid) PID="$2"; shift;;
  -c|--current) CURRENT_PATH="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

echo "Starting step #$STEP"

if [[ "$STEP" == "1" ]]; then
    if [ -d "$MOUNT_PATH" ]; then
      /usr/bin/hdiutil detach "$MOUNT_PATH"
      if [ -d "$MOUNT_PATH" ]; then
        /bin/rm -rf "$MOUNT_PATH"
      fi
    fi

    /usr/bin/mktemp -d $MOUNT_PATH
    /usr/bin/hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_PATH" -noverify -nobrowse -noautoopen

    cp $MOUNT_PATH/Stats.app/Contents/Resources/Scripts/updater.sh $TMPDIR/updater.sh
    sh $TMPDIR/updater.sh --step 2 --app "$CURRENT_PATH" --dmg "$DMG_PATH" >/dev/null &

    kill -9 $PID

    echo "DMG is mounted under $MOUNT_PATH. Starting step #2"
elif [[ "$STEP" == "2" ]]; then
    rm -rf $APP_PATH/Stats.app
    cp -rf $MOUNT_PATH/Stats.app $APP_PATH/Stats.app

    $APP_PATH/Stats.app/Contents/MacOS/Stats --dmg "$DMG_PATH"

    echo "New version started"
elif [[ "$STEP" == "3" ]]; then
    /usr/bin/hdiutil detach "$MOUNT_PATH"
    /bin/rm -rf "$MOUNT_PATH"
    /bin/rm -rf "$DMG_PATH"

    echo "Done"
else
    echo "Step not defined"
fi
