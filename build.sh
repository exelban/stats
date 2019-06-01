#!/bin/sh

if [ ! -d "./create-dmg" ]; then
    git clone https://github.com/andreyvit/create-dmg
fi

xcodebuild -configuration Distribution clean build

cp -rf $PWD/build/Release/Stats.app ./
rm -rf echo $PWD/build

./create-dmg/create-dmg \
    --volname "Stats" \
    --background "./resources/background.png" \
    --window-pos 200 120 \
    --window-size 500 320 \
    --icon-size 80 \
    --icon "Stats.app" 125 175 \
    --hide-extension "Stats.app" \
    --app-drop-link 375 175 \
    "Stats.dmg" \
    "Stats.app"

rm -rf ./create-dmg
rm -rf Stats.app
