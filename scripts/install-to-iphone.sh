#!/usr/bin/env bash
#
# Build Doodle Classic and install it on a connected iPhone.
#
#   ./scripts/install-to-iphone.sh
#
# Optional overrides:
#   TEAM_ID=ABCDE12345   your Apple Developer team ID (auto-detected if omitted)
#   BUNDLE_ID=com.you.DoodleClassic   if the default identifier is taken
#   DEVICE_ID=00008120-...            if more than one iPhone is attached
#
# Prerequisites this script cannot do for you (Apple requires the GUI):
#   1. Xcode installed.
#   2. Signed into Xcode with your Apple ID:
#      Xcode > Settings > Accounts > + > Apple ID.
#   3. iPhone plugged in, unlocked, and "Trust This Computer" accepted.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

PROJECT="DoodleClassic.xcodeproj"
SCHEME="DoodleClassic"
CONFIG="Debug"
DERIVED="$PROJECT_DIR/build"
BUNDLE_ID="${BUNDLE_ID:-com.fourcher.DoodleClassic}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
fail() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
# macOS still ships bash 3.2, so everything below stays 3.2-compatible:
# no mapfile, no associative arrays.
trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

# ---------------------------------------------------------------- prereqs ---

bold "==> Checking prerequisites"

[ "$(uname -s)" = "Darwin" ] || fail "This script must run on macOS."

command -v xcodebuild >/dev/null 2>&1 \
  || fail "xcodebuild not found. Install Xcode from the App Store, then run:
         sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"

XCODE_PATH="$(xcode-select -p 2>/dev/null || true)"
case "$XCODE_PATH" in
  *CommandLineTools*)
    fail "Only the Command Line Tools are selected, not full Xcode. Run:
         sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    ;;
esac
info "Xcode: $(xcodebuild -version | head -1) at $XCODE_PATH"

# ---------------------------------------------------------------- team id ---

detect_team_ids() {
  local pem_file cert_file line cert=""
  pem_file="$(mktemp)"
  cert_file="$(mktemp)"
  security find-certificate -a -c "Apple Development" -p >"$pem_file" 2>/dev/null || true
  if [ ! -s "$pem_file" ]; then
    rm -f "$pem_file" "$cert_file"
    return 0
  fi
  while IFS= read -r line; do
    cert+="$line"$'\n'
    if [[ "$line" == *"END CERTIFICATE"* ]]; then
      printf '%s' "$cert" >"$cert_file"
      openssl x509 -in "$cert_file" -noout -subject 2>/dev/null || true
      cert=""
    fi
  done <"$pem_file"
  rm -f "$pem_file" "$cert_file"
}

if [ -z "${TEAM_ID:-}" ]; then
  bold "==> Detecting your signing team"
  # The team ID lives in the certificate's Organizational Unit.
  TEAMS="$(detect_team_ids \
    | sed -n 's|.*OU *= *\([A-Z0-9][A-Z0-9]*\).*|\1|p' \
    | sort -u || true)"
  TEAM_COUNT=0
  [ -n "$TEAMS" ] && TEAM_COUNT="$(printf '%s\n' "$TEAMS" | wc -l | tr -d ' ')"

  if [ "$TEAM_COUNT" -eq 0 ]; then
    fail "No Apple Development signing certificate found in your keychain.

       Open Xcode > Settings > Accounts, add your Apple ID, then open
       $PROJECT, select the DoodleClassic target > Signing & Capabilities,
       and choose your team once. Xcode creates the certificate for you.
       Then re-run this script."
  elif [ "$TEAM_COUNT" -gt 1 ]; then
    printf 'Multiple signing teams found:\n'
    printf '%s\n' "$TEAMS" | sed 's/^/  /'
    fail "Pick one and re-run:  TEAM_ID=<id> $0"
  fi
  TEAM_ID="$TEAMS"
fi
info "Team ID: $TEAM_ID"
info "Bundle ID: $BUNDLE_ID"

# ----------------------------------------------------------------- device ---

bold "==> Looking for a connected iPhone"

DESTINATIONS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -showdestinations 2>/dev/null || true)"

DEVICE_LINES="$(printf '%s\n' "$DESTINATIONS" \
  | grep 'platform:iOS,' \
  | grep -v 'placeholder' || true)"

if [ -z "$DEVICE_LINES" ]; then
  fail "No physical iPhone detected.

       Check that it is plugged in, unlocked, and that you tapped
       \"Trust This Computer\". Then confirm macOS sees it:
         xcrun devicectl list devices"
fi

if [ -z "${DEVICE_ID:-}" ]; then
  DEVICE_COUNT="$(printf '%s\n' "$DEVICE_LINES" | wc -l | tr -d ' ')"
  if [ "$DEVICE_COUNT" -gt 1 ]; then
    printf 'More than one device is attached:\n'
    printf '%s\n' "$DEVICE_LINES"
    fail "Pick one and re-run:  DEVICE_ID=<id> $0"
  fi
  DEVICE_ID="$(printf '%s\n' "$DEVICE_LINES" \
    | sed -n 's/.*id:\([^,}]*\).*/\1/p' | head -1 | trim)"
fi

# Names like "Jeff's iPhone" contain apostrophes, so trim with sed, not xargs.
DEVICE_NAME="$(printf '%s\n' "$DEVICE_LINES" \
  | sed -n 's/.*name:\(.*\)}.*/\1/p' | head -1 | trim || true)"
info "Device: ${DEVICE_NAME:-unknown} ($DEVICE_ID)"

# ------------------------------------------------------------------ build ---

bold "==> Building (first build fetches a provisioning profile, be patient)"

set +e
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_STYLE=Automatic \
  build
BUILD_STATUS=$?
set -e

if [ "$BUILD_STATUS" -ne 0 ]; then
  fail "Build failed (exit $BUILD_STATUS). Scroll up for the first line
       beginning with 'error:' and send it over — that is the fix target.

       If it mentions the bundle identifier already being in use, retry with
       a unique one:  BUNDLE_ID=com.yourname.DoodleClassic $0"
fi

APP_PATH="$DERIVED/Build/Products/$CONFIG-iphoneos/DoodleClassic.app"
[ -d "$APP_PATH" ] || fail "Build reported success but $APP_PATH is missing."
info "Built: $APP_PATH"

# ---------------------------------------------------------------- install ---

bold "==> Installing to the iPhone"

if ! xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"; then
  fail "Install failed. The usual cause is the phone being locked — unlock it
       and re-run. If it says the developer app is untrusted, see the next
       step below."
fi

bold "==> Installed."
cat <<EOS

  First time only, on the iPhone:
    Settings > General > VPN & Device Management > your Apple ID > Trust

  Then launch "Doodle Classic" from the home screen, or from here:
    xcrun devicectl device process launch --device $DEVICE_ID $BUNDLE_ID

  With a free Apple ID the signature expires after 7 days. Re-run this
  script to refresh it. A paid developer account lasts a year.

EOS
