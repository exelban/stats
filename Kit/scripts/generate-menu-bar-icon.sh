#!/bin/bash
set -eu

ICON_TOOL="${DEVELOPER_DIR}/../Applications/Icon Composer.app/Contents/Executables/ictool"
ICON_COPY="${DERIVED_FILE_DIR}/MenuBarIcon.icon"
ICON_RESOURCES="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

if [[ ! -x "$ICON_TOOL" ]]; then
    echo "error: Icon Composer is required to generate the menu bar icon."
    exit 1
fi

# Icon Composer rewrites documents during export, so use a build copy.
ditto "${SRCROOT}/Stats/Supporting Files/Stats.icon" "$ICON_COPY"
mkdir -p "$ICON_RESOURCES"

plutil -replace fill -json '{"linear-gradient":["srgb:0.98039,0.98039,0.98039,1.00000","srgb:0.90980,0.90980,0.90980,1.00000"]}' "$ICON_COPY/icon.json"
sed -i '' 's/#404040/#D8D8D8/g' "$ICON_COPY/Assets/grid.svg"

for ICON_SCALE in 1 2; do
    ICON_OUTPUT="${ICON_RESOURCES}/MenuBarIcon.png"
    if [[ "$ICON_SCALE" == 2 ]]; then
        ICON_OUTPUT="${ICON_RESOURCES}/MenuBarIcon@2x.png"
    fi
    "$ICON_TOOL" "$ICON_COPY" --export-image --output-file "$ICON_OUTPUT" \
        --platform macOS --rendition Default --width 16 --height 16 --scale "$ICON_SCALE"
done
