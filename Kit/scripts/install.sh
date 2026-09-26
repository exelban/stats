#!/bin/bash
set -eu

BUNDLE_ID="eu.exelban.Stats"
KEYCHAIN_SERVICE="${BUNDLE_ID}.remote"
AUTH_HOST="https://oauth.system-stats.com"
API_HOST="https://api.system-stats.com"
APP_HOST="https://app.system-stats.com"
CLIENT_ID="stats"
REPO="exelban/stats"
AGENT_LABEL="eu.exelban.Stats"
UID_NUM="$(id -u)"

STEP=""
VERSION="latest"
ENABLE_CONTROL="false"
ENABLE_UPDATE="false"
REAUTH=0
APP_DST="/Applications/Stats.app"
CUSTOM_APP_DST=0

usage() {
    echo "Usage: install.sh [options]"
    echo ""
    echo "Installs Stats, enables the Remote module, authorizes the machine"
    echo "against the System Stats account and registers a launchd agent."
    echo ""
    echo "Options:"
    echo "  -v, --version TAG    Install a specific release tag (default: latest)"
    echo "  -a, --app PATH       Target location of Stats.app (default: /Applications/Stats.app)"
    echo "  -c, --control        Allow remote control commands"
    echo "  -u, --update         Allow remote update trigger"
    echo "  -r, --reauth         Force a fresh login even if tokens already exist"
    echo "  -h, --help           Show this help"
}

while [[ "$#" -gt 0 ]]; do case "$1" in
  -v|--version) VERSION="$2"; shift;;
  -a|--app) APP_DST="$2"; CUSTOM_APP_DST=1; shift;;
  -c|--control) ENABLE_CONTROL="true";;
  -u|--update) ENABLE_UPDATE="true";;
  -r|--reauth) REAUTH=1;;
  -h|--help) usage; exit 0;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

json() {
    /usr/bin/plutil -p "$1" 2>/dev/null | awk -v k="\"$2\"" '$1 == k { v = $3; sub(/^"/, "", v); sub(/"$/, "", v); print v; exit }'
}

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script runs on macOS only"
    exit 1
fi

TMP="$(/usr/bin/mktemp -d)"
MOUNT=""
cleanup() {
    if [[ -n "$MOUNT" ]]; then
        if ! /usr/bin/hdiutil detach "$MOUNT" >/dev/null 2>&1; then
            echo "Could not unmount $MOUNT. Temporary files were kept at $TMP." >&2
            return
        fi
    fi
    rm -rf "$TMP"
}
trap 'INSTALL_EXIT_STATUS=$?; cleanup; exit "$INSTALL_EXIT_STATUS"' EXIT

if [[ -d "$APP_DST" ]]; then
    APP="$APP_DST"
elif [[ "$CUSTOM_APP_DST" -eq 0 && -d "$HOME/Applications/Stats.app" ]]; then
    APP="$HOME/Applications/Stats.app"
else
    if [[ "$VERSION" == "latest" ]]; then
        URL="https://github.com/$REPO/releases/latest/download/Stats.dmg"
    else
        URL="https://github.com/$REPO/releases/download/v$VERSION/Stats.dmg"
    fi
    echo "Downloading Stats ($VERSION)..."
    /usr/bin/curl -fL --retry 3 -o "$TMP/Stats.dmg" "$URL"
    MOUNT="$TMP/mount"
    /bin/mkdir -p "$MOUNT"
    /usr/bin/hdiutil attach -nobrowse -noautoopen -quiet -readonly -mountpoint "$MOUNT" "$TMP/Stats.dmg"

    DEST="$(dirname "$APP_DST")"
    INSTALL_PARENT="$DEST"
    while [[ ! -d "$INSTALL_PARENT" ]]; do
        INSTALL_PARENT="$(dirname "$INSTALL_PARENT")"
    done
    INSTALL_CMD=(command)
    if [[ ! -w "$INSTALL_PARENT" ]]; then
        if sudo -v 2>/dev/null; then
            INSTALL_CMD=(sudo)
        elif [[ "$CUSTOM_APP_DST" -eq 0 ]]; then
            DEST="$HOME/Applications"
            APP_DST="$DEST/Stats.app"
            echo "Installing to $DEST (no admin privileges)..."
        else
            echo "Cannot write to $DEST without admin privileges."
            exit 1
        fi
    fi
    "${INSTALL_CMD[@]}" /bin/mkdir -p "$DEST"
    if command -v ditto >/dev/null 2>&1; then
        "${INSTALL_CMD[@]}" ditto "$MOUNT/Stats.app" "$APP_DST"
    else
        "${INSTALL_CMD[@]}" cp -Rf "$MOUNT/Stats.app" "$APP_DST"
    fi
    /usr/bin/hdiutil detach "$MOUNT" >/dev/null 2>&1
    MOUNT=""
    "${INSTALL_CMD[@]}" /usr/bin/xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true
    APP="$APP_DST"
    echo "Installed Stats to $APP"
fi

HAS_GUI=0
if launchctl print "gui/$UID_NUM" >/dev/null 2>&1; then
    HAS_GUI=1
    launchctl bootout "gui/$UID_NUM/$AGENT_LABEL" 2>/dev/null || true
else
    echo "No active GUI session. Stats needs a logged-in user session and will start at the next login."
fi

if pgrep -x Stats >/dev/null 2>&1; then
    echo "Stopping running Stats..."
    pkill -x Stats || true
    sleep 1
fi

DEVICE_ID="$(/usr/bin/defaults read "$BUNDLE_ID" remote_id 2>/dev/null || true)"
if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(uuidgen | tr 'A-Z' 'a-z')"
fi

/usr/bin/defaults write "$BUNDLE_ID" remote_id "$DEVICE_ID"
/usr/bin/defaults write "$BUNDLE_ID" setupProcess -bool true
/usr/bin/defaults write "$BUNDLE_ID" Remote_state -bool true
/usr/bin/defaults write "$BUNDLE_ID" remote_monitoring -bool true
/usr/bin/defaults write "$BUNDLE_ID" remote_control -bool "$ENABLE_CONTROL"
/usr/bin/defaults write "$BUNDLE_ID" remote_update -bool "$ENABLE_UPDATE"
echo "Configured the Remote module (device: $DEVICE_ID)"

ACCESS_TOKEN=""
REFRESH_TOKEN=""

EXISTING_TOKEN="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a access_token -w 2>/dev/null || true)"
EXISTING_REFRESH_TOKEN="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a refresh_token -w 2>/dev/null || true)"
if [[ -n "$EXISTING_TOKEN" && -n "$EXISTING_REFRESH_TOKEN" && "$REAUTH" -eq 0 ]]; then
    echo "Found existing authorization, skipping login."
    ACCESS_TOKEN="$EXISTING_TOKEN"
    REFRESH_TOKEN="$EXISTING_REFRESH_TOKEN"
else
    echo "Requesting a device authorization code..."
    /usr/bin/curl -fsS -X POST "$AUTH_HOST/device" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=$CLIENT_ID" \
        -d "device_id=$DEVICE_ID" \
        -o "$TMP/device.json"
    DEVICE_CODE="$(json "$TMP/device.json" device_code)"
    USER_CODE="$(json "$TMP/device.json" user_code)"
    VERIFY_URL="$(json "$TMP/device.json" verification_uri_complete)"
    INTERVAL="$(json "$TMP/device.json" interval)"
    if [[ -z "$DEVICE_CODE" || -z "$VERIFY_URL" ]]; then
        echo "Device registration failed: $(cat "$TMP/device.json" 2>/dev/null)"
        exit 1
    fi
    case "$INTERVAL" in ''|*[!0-9]*) INTERVAL=5;; esac

    echo ""
    echo "Open this URL on any device and sign in to your System Stats account:"
    echo ""
    echo "    $VERIFY_URL"
    echo ""
    echo "    Code: $USER_CODE"
    echo ""
    echo "Waiting for authorization (5 minutes)..."

    DEADLINE=$(( $(date +%s) + 300 ))
    while [[ "$(date +%s)" -lt "$DEADLINE" && -z "$ACCESS_TOKEN" ]]; do
        sleep "$INTERVAL"
        HTTP_CODE="$(/usr/bin/curl -s -o "$TMP/token.json" -w '%{http_code}' -X POST "$AUTH_HOST/token" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "client_id=$CLIENT_ID" \
            -d "device_code=$DEVICE_CODE" \
            -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" || true)"
        if [[ "$HTTP_CODE" == "200" ]]; then
            ACCESS_TOKEN="$(json "$TMP/token.json" access_token)"
            REFRESH_TOKEN="$(json "$TMP/token.json" refresh_token)"
            if [[ -z "$ACCESS_TOKEN" || -z "$REFRESH_TOKEN" ]]; then
                echo "Authorization returned incomplete credentials. Existing tokens were not changed."
                exit 1
            fi
        elif [[ "$HTTP_CODE" == "400" ]]; then
            ERROR="$(json "$TMP/token.json" error)"
            case "$ERROR" in
                authorization_pending) ;;
                slow_down) INTERVAL=$(( INTERVAL + 5 )) ;;
                *) echo "Authorization failed: ${ERROR:-unknown error}. Re-run the script to try again."; exit 1 ;;
            esac
        else
            echo "Token polling returned HTTP $HTTP_CODE, retrying..."
        fi
    done
    if [[ -z "$ACCESS_TOKEN" ]]; then
        echo "Authorization timed out. Re-run the script to get a new code."
        exit 1
    fi
    echo "Authorized successfully."

    echo "Storing tokens in the keychain..."
    security add-generic-password -U -s "$KEYCHAIN_SERVICE" -a access_token -w "$ACCESS_TOKEN" \
        -T "$APP/Contents/MacOS/Stats" -T /usr/bin/security
    security add-generic-password -U -s "$KEYCHAIN_SERVICE" -a refresh_token -w "$REFRESH_TOKEN" \
        -T "$APP/Contents/MacOS/Stats" -T /usr/bin/security
    security find-generic-password -s "$KEYCHAIN_SERVICE" -a access_token -w >/dev/null || {
        echo "Token verification failed"
        exit 1
    }
fi

PLIST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
BIN="$APP/Contents/MacOS/Stats"
/bin/mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$AGENT_LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$BIN</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>15</integer>
	<key>ProcessType</key>
	<string>Interactive</string>
</dict>
</plist>
EOF
echo "Installed the launchd agent."

if [[ "$HAS_GUI" -eq 1 ]]; then
    if ! launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>/dev/null; then
        open "$APP" || echo "Failed to launch Stats"
    fi
    sleep 5
fi

VERSION_STR="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist" 2>/dev/null || true)"
FOUND=0
ONLINE=0
DEADLINE=$(( $(date +%s) + 90 ))
while [[ "$(date +%s)" -lt "$DEADLINE" ]]; do
    BODY="$(/usr/bin/curl -sS -H "Authorization: Bearer $ACCESS_TOKEN" "$API_HOST/v1/machine" 2>/dev/null || true)"
    if printf '%s' "$BODY" | grep -q "\"$DEVICE_ID\""; then
        FOUND=1
        if printf '%s' "$BODY" | tr -d '\n ' | grep -o "\"id\":\"$DEVICE_ID\"[^}]*" | grep -q "\"online\":true"; then
            ONLINE=1
            break
        fi
    fi
    sleep 3
done

echo ""
echo "Stats ${VERSION_STR:-unknown} installed at $APP"
echo "Machine ID: $DEVICE_ID"
if [[ "$ONLINE" -eq 1 ]]; then
    echo "Machine is online and streaming metrics."
elif [[ "$FOUND" -eq 1 ]]; then
    echo "Machine is registered and should come online shortly."
else
    echo "Machine is not visible in the account yet. If the GUI session is active, check with: pgrep -x Stats"
fi
echo "Dashboard: $APP_HOST/machine/$DEVICE_ID"
if [[ "$(uname -m)" == "x86_64" ]]; then
    echo "Optional: enable the SMC Helper in System Settings > General > Login Items for fan and sensor readings."
fi
