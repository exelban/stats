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
  -v|--version)
    if [[ "$#" -lt 2 || -z "$2" || "$2" == -* || "$2" == "v" ]]; then
        echo "Missing release tag for $1"
        exit 1
    fi
    VERSION="${2#v}"; shift;;
  -a|--app)
    if [[ "$#" -lt 2 || -z "$2" || "$2" == -* ]]; then
        echo "Missing app path for $1"
        exit 1
    fi
    APP_DST="$2"; CUSTOM_APP_DST=1; shift;;
  -c|--control) ENABLE_CONTROL="true";;
  -u|--update) ENABLE_UPDATE="true";;
  -r|--reauth) REAUTH=1;;
  -h|--help) usage; exit 0;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

json() {
    local VALUE
    VALUE="$(/usr/bin/plutil -extract "$2" raw -expect "${3:-string}" -o - "$1" 2>/dev/null)" || return 0
    printf '%s' "$VALUE"
}

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script runs on macOS only"
    exit 1
fi

if [[ "$UID_NUM" -eq 0 ]]; then
    echo "Run this script as the user who will run Stats, without sudo."
    exit 1
fi
if [[ "$APP_DST" != /* ]]; then
    APP_DST="$PWD/$APP_DST"
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

BIN="$APP/Contents/MacOS/Stats"
if [[ ! -x "$BIN" ]]; then
    echo "Stats executable not found at $BIN"
    exit 1
fi

KEYCHAIN="$(security default-keychain -d user | sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//')"
if [[ -z "$KEYCHAIN" ]]; then
    echo "No default user keychain found. Create a login keychain before running this script."
    exit 1
fi

unlock_keychain() {
    echo "Unlock the keychain to allow Stats authorization to be saved."
    if ( : </dev/tty ) 2>/dev/null; then
        if security unlock-keychain "$KEYCHAIN" </dev/tty; then
            return 0
        fi
    fi
    echo "Run security unlock-keychain in this session, then run the installer again. Over SSH, use ssh -t for the password prompt."
    return 1
}

check_keychain() {
    local ACCOUNT="install_probe_$(uuidgen)"
    local VALUE
    security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$ACCOUNT" -w probe \
        -T "$BIN" -T /usr/bin/security "$KEYCHAIN" >/dev/null 2>&1 || return 1
    VALUE="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$ACCOUNT" -w "$KEYCHAIN" 2>/dev/null || true)"
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$ACCOUNT" "$KEYCHAIN" >/dev/null 2>&1 || return 1
    [[ "$VALUE" == "probe" ]]
}

if ! check_keychain; then
    unlock_keychain
    if ! check_keychain; then
        echo "Cannot read and write authorization in the keychain. No login code was requested."
        exit 1
    fi
fi

HAS_GUI=0
if launchctl print "gui/$UID_NUM" >/dev/null 2>&1; then
    HAS_GUI=1
    launchctl bootout "gui/$UID_NUM/$AGENT_LABEL" 2>/dev/null || true
else
    echo "No active GUI session. Stats needs a logged-in user session and will start at the next login."
fi

if pgrep -u "$UID_NUM" -x Stats >/dev/null 2>&1; then
    echo "Stopping running Stats..."
    pkill -u "$UID_NUM" -x Stats || true
    for (( ATTEMPT=0; ATTEMPT<10; ATTEMPT++ )); do
        if ! pgrep -u "$UID_NUM" -x Stats >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    if pgrep -u "$UID_NUM" -x Stats >/dev/null 2>&1; then
        echo "Stats is still running. Quit it before running this script again."
        exit 1
    fi
fi

DEVICE_ID="$(/usr/bin/defaults read "$BUNDLE_ID" remote_id 2>/dev/null || true)"
if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(/usr/bin/defaults read "$BUNDLE_ID" telemetry_id 2>/dev/null || true)"
fi
if [[ ! "$DEVICE_ID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
    DEVICE_ID="$(uuidgen)"
    REAUTH=1
fi
CANONICAL_ID="$(printf '%s' "$DEVICE_ID" | tr 'a-f' 'A-F')"
if [[ "$DEVICE_ID" != "$CANONICAL_ID" ]]; then
    echo "Normalizing the device ID. A fresh login is required."
    DEVICE_ID="$CANONICAL_ID"
    REAUTH=1
fi

ACCESS_TOKEN=""
REFRESH_TOKEN=""

EXISTING_TOKEN="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a access_token -w "$KEYCHAIN" 2>/dev/null || true)"
EXISTING_REFRESH_TOKEN="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a refresh_token -w "$KEYCHAIN" 2>/dev/null || true)"
if [[ -n "$EXISTING_TOKEN" && -n "$EXISTING_REFRESH_TOKEN" && "$REAUTH" -eq 0 ]]; then
    echo "Found existing authorization, skipping login."
    ACCESS_TOKEN="$EXISTING_TOKEN"
    REFRESH_TOKEN="$EXISTING_REFRESH_TOKEN"
else
    echo "Requesting a device authorization code..."
    /usr/bin/curl -fsS --connect-timeout 10 --max-time 30 -X POST "$AUTH_HOST/device" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "client_id=$CLIENT_ID" \
        --data-urlencode "device_id=$DEVICE_ID" \
        -o "$TMP/device.json"
    DEVICE_CODE="$(json "$TMP/device.json" device_code)"
    USER_CODE="$(json "$TMP/device.json" user_code)"
    VERIFY_URL="$(json "$TMP/device.json" verification_uri_complete)"
    INTERVAL="$(json "$TMP/device.json" interval integer)"
    EXPIRES_IN="$(json "$TMP/device.json" expires_in integer)"
    if [[ -z "$DEVICE_CODE" || -z "$VERIFY_URL" ]]; then
        echo "Device registration returned an invalid authorization code or URL."
        exit 1
    fi
    case "$INTERVAL" in ''|0|*[!0-9]*) INTERVAL=5;; esac
    case "$EXPIRES_IN" in ''|0|*[!0-9]*) EXPIRES_IN=300;; esac

    echo ""
    echo "Open this URL on any device and sign in to your System Stats account:"
    echo ""
    echo "    $VERIFY_URL"
    echo ""
    echo "    Code: $USER_CODE"
    echo ""
    echo "Waiting for authorization ($EXPIRES_IN seconds)..."

    DEADLINE=$(( $(date +%s) + EXPIRES_IN ))
    while [[ "$(date +%s)" -lt "$DEADLINE" && -z "$ACCESS_TOKEN" ]]; do
        if [[ $(( $(date +%s) + INTERVAL )) -ge "$DEADLINE" ]]; then
            break
        fi
        sleep "$INTERVAL"
        HTTP_CODE="$(/usr/bin/curl -sS --connect-timeout 10 --max-time 30 -o "$TMP/token.json" -w '%{http_code}' -X POST "$AUTH_HOST/token" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            --data-urlencode "client_id=$CLIENT_ID" \
            --data-urlencode "device_code=$DEVICE_CODE" \
            --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:device_code" || true)"
        if [[ "$HTTP_CODE" == "200" ]]; then
            ACCESS_TOKEN="$(json "$TMP/token.json" access_token)"
            REFRESH_TOKEN="$(json "$TMP/token.json" refresh_token)"
            if [[ -z "$ACCESS_TOKEN" || -z "$REFRESH_TOKEN" ]]; then
                echo "Authorization returned incomplete credentials. Existing tokens were not changed."
                exit 1
            fi
        elif [[ "$HTTP_CODE" == "400" ]]; then
            ERROR="$(json "$TMP/token.json" error)"
            if [[ "$ERROR" == "BAD_REQUEST" || -z "$ERROR" ]]; then
                ERROR="$(json "$TMP/token.json" message)"
            fi
            case "$ERROR" in
                authorization_pending) ;;
                slow_down) INTERVAL=$(( INTERVAL + 5 )) ;;
                *) echo "Authorization failed: ${ERROR:-unknown error}. Re-run the script to try again."; exit 1 ;;
            esac
        elif [[ "$HTTP_CODE" == "000" || "$HTTP_CODE" == 5?? || "$HTTP_CODE" == "429" ]]; then
            if [[ "$HTTP_CODE" == "429" ]]; then
                INTERVAL=$(( INTERVAL + 5 ))
            fi
            echo "Token polling returned HTTP $HTTP_CODE, retrying..."
        else
            echo "Authorization failed with HTTP $HTTP_CODE. Re-run the script to try again."
            exit 1
        fi
    done
    if [[ -z "$ACCESS_TOKEN" ]]; then
        echo "Authorization timed out. Re-run the script to get a new code."
        exit 1
    fi
    echo "Authorized successfully."

    echo "Storing tokens in the keychain..."
    for ACCOUNT in refresh_token access_token; do
        TOKEN="$REFRESH_TOKEN"
        if [[ "$ACCOUNT" == "access_token" ]]; then
            TOKEN="$ACCESS_TOKEN"
        fi
        if ! security add-generic-password -U -s "$KEYCHAIN_SERVICE" -a "$ACCOUNT" -w "$TOKEN" \
            -T "$BIN" -T /usr/bin/security "$KEYCHAIN"; then
            unlock_keychain
            security add-generic-password -U -s "$KEYCHAIN_SERVICE" -a "$ACCOUNT" -w "$TOKEN" \
                -T "$BIN" -T /usr/bin/security "$KEYCHAIN"
        fi
        if [[ "$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$ACCOUNT" -w "$KEYCHAIN")" != "$TOKEN" ]]; then
            echo "Token verification failed for $ACCOUNT"
            exit 1
        fi
    done
fi

# Prevent the app's legacy migration from replacing the keychain credentials.
/usr/bin/defaults write "$BUNDLE_ID" remote_tokens_migrated_to_keychain -bool true
/usr/bin/defaults delete "$BUNDLE_ID" access_token >/dev/null 2>&1 || true
/usr/bin/defaults delete "$BUNDLE_ID" refresh_token >/dev/null 2>&1 || true
/usr/bin/defaults write "$BUNDLE_ID" remote_id -string "$DEVICE_ID"
/usr/bin/defaults write "$BUNDLE_ID" setupProcess -bool true
/usr/bin/defaults write "$BUNDLE_ID" Remote_state -bool true
/usr/bin/defaults write "$BUNDLE_ID" remote_monitoring -bool true
/usr/bin/defaults write "$BUNDLE_ID" remote_control -bool "$ENABLE_CONTROL"
/usr/bin/defaults write "$BUNDLE_ID" remote_update -bool "$ENABLE_UPDATE"
echo "Configured the Remote module (device: $DEVICE_ID)"

PLIST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
/bin/mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$AGENT_LABEL</string>
	<key>ProgramArguments</key>
	<array/>
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
/usr/bin/plutil -insert ProgramArguments.0 -string "$BIN" "$PLIST"
/usr/bin/plutil -lint "$PLIST" >/dev/null
echo "Installed the launchd agent."

if [[ "$HAS_GUI" -eq 1 ]]; then
    if ! launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>/dev/null; then
        open "$APP" || echo "Failed to launch Stats"
    fi
    sleep 5
fi

VERSION_STR="$(json "$APP/Contents/Info.plist" CFBundleShortVersionString)"
FOUND=0
ONLINE=0
STATUS_CHECKED=0
DEADLINE=$(( $(date +%s) + 90 ))
while [[ "$HAS_GUI" -eq 1 && "$(date +%s)" -lt "$DEADLINE" ]]; do
    # Stats may refresh an expired access token after starting.
    CURRENT_TOKEN="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a access_token -w "$KEYCHAIN" 2>/dev/null || true)"
    if [[ -n "$CURRENT_TOKEN" ]]; then
        ACCESS_TOKEN="$CURRENT_TOKEN"
    fi
    HTTP_CODE="$(/usr/bin/curl -sS --connect-timeout 10 --max-time 15 -o "$TMP/machines.json" -w '%{http_code}' \
        -H "Authorization: Bearer $ACCESS_TOKEN" "$API_HOST/v1/machine" || true)"
    if [[ "$HTTP_CODE" == "200" ]]; then
        printf '{"machines":%s}' "$(cat "$TMP/machines.json")" > "$TMP/status.json"
        COUNT="$(json "$TMP/status.json" machines array)"
        if [[ -n "$COUNT" ]]; then
            STATUS_CHECKED=1
            for (( INDEX=0; INDEX<COUNT; INDEX++ )); do
                if [[ "$(json "$TMP/status.json" "machines.$INDEX.id")" == "$DEVICE_ID" ]]; then
                    FOUND=1
                    if [[ "$(json "$TMP/status.json" "machines.$INDEX.online" bool)" == "true" ]]; then
                        ONLINE=1
                    fi
                    break
                fi
            done
        fi
        if [[ "$ONLINE" -eq 1 ]]; then
            break
        fi
    elif [[ "$HTTP_CODE" == "403" ]]; then
        echo "Machine status check was denied (HTTP 403)."
        break
    fi
    sleep 3
done

echo ""
echo "Stats ${VERSION_STR:-unknown} installed at $APP"
echo "Machine ID: $DEVICE_ID"
if [[ "$HAS_GUI" -eq 0 ]]; then
    echo "Stats will start and register the machine at the next GUI login."
elif [[ "$ONLINE" -eq 1 ]]; then
    echo "Machine is online and streaming metrics."
elif [[ "$FOUND" -eq 1 ]]; then
    echo "Machine is registered and should come online shortly."
elif [[ "$STATUS_CHECKED" -eq 1 ]]; then
    echo "Machine is not visible in the account yet. If the GUI session is active, check with: pgrep -x Stats"
else
    echo "Could not verify machine status. Check the dashboard after Stats connects."
fi
echo "Dashboard: $APP_HOST/machine/$DEVICE_ID"
if [[ "$(uname -m)" == "x86_64" ]]; then
    echo "Optional: enable the SMC Helper in System Settings > General > Login Items for fan and sensor readings."
fi
