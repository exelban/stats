#!/bin/bash
set -e

PROJECT="Stats.xcodeproj"
SCHEME="Stats"
CONFIG="Debug"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/Build/Products/$CONFIG/Stats.app"

# Kill any running instance
if pgrep -x "Stats" > /dev/null; then
    echo "Stopping existing Stats instance..."
    pkill -x "Stats"
    sleep 1
fi

echo "Building $SCHEME ($CONFIG)..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | grep -E "^(error:|warning:|Build succeeded|BUILD FAILED|CompileSwift|Ld )" | sed \
        -e 's/^error:/❌ error:/' \
        -e 's/^warning:/⚠️  warning:/' \
        -e 's/^Build succeeded/✅ Build succeeded/' \
        -e 's/^BUILD FAILED/❌ BUILD FAILED/'

# Check exit code of xcodebuild (not grep)
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "❌ Build failed. Run with verbose output:"
    echo "   xcodebuild -project $PROJECT -scheme $SCHEME -configuration $CONFIG -derivedDataPath $BUILD_DIR CODE_SIGN_IDENTITY=\"-\" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
    exit 1
fi

echo "Launching Stats.app..."
open "$APP_PATH"
