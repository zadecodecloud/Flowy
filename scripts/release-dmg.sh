#!/bin/bash
# Build a Release Flowy.dmg for download (no Developer ID, no notarization).
#
#   scripts/release-dmg.sh                 # signs with the "Apple Development" identity (stable permissions)
#   SIGN_IDENTITY=- scripts/release-dmg.sh # ad-hoc signature instead
#
#   UPDATE_DOWNLOAD_BASE=… scripts/release-dmg.sh   (defaults to the zadeoncloud/flowy GitHub releases)
#       also adds the release to build/updates/appcast.xml, signed with the Sparkle key in your Keychain.
#
# Output: build/release/Flowy-<version>.dmg and a .sha256 file next to it.
# Users must allow the app once in System Settings › Privacy & Security › Open Anyway.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPDATE_DOWNLOAD_BASE="${UPDATE_DOWNLOAD_BASE:-https://github.com/zadeoncloud/flowy/releases/download}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Apple Development}"
TEAM_ID="${TEAM_ID:-WP4578MNNL}"
DERIVED="$ROOT/build/ReleaseDerivedData"
OUT="$ROOT/build/release"
PLIST="$ROOT/NotchFlow/Application/Info.plist"

fail() { echo "error: $*" >&2; exit 1; }

# 1. Pre-flight
SOURCE_URL="$(/usr/libexec/PlistBuddy -c 'Print :NotchFlowSourceURL' "$PLIST" 2>/dev/null || true)"
if [[ "$SOURCE_URL" != https://* ]]; then
    echo "warning: NotchFlowSourceURL is empty. GPL-3.0 requires offering the source to people who get the app;" >&2
    echo "         set it to the public source repo before publishing this .dmg." >&2
fi

# 2. Build
SIGN_ARGS=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$SIGN_IDENTITY")
[[ "$SIGN_IDENTITY" == "-" ]] || SIGN_ARGS+=("DEVELOPMENT_TEAM=$TEAM_ID")
xcodebuild -project "$ROOT/NotchFlow.xcodeproj" -scheme NotchFlow -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" "${SIGN_ARGS[@]}" \
    clean build | grep -E "error:|warning: .*sign|\*\* BUILD" || true
APP="$DERIVED/Build/Products/Release/Flowy.app"
[[ -d "$APP" ]] || fail "Release build failed (no $APP)."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"

# 3. Checks
codesign --verify --deep --strict "$APP" || fail "code signature is invalid."
LEAKS="$(find "$APP" \( -name '*.swift' -o -name '.env*' -o -name '*.p8' -o -name '*.p12' -o -name '*.pem' \
    -o -name '*.key' -o -name '*.xcconfig' -o -iname '*DevelopmentLicensing*' -o -name '*.log' \) -print)"
[[ -z "$LEAKS" ]] || fail "artifact contains files that must not ship:"$'\n'"$LEAKS"
if strings "$APP/Contents/MacOS/Flowy" | grep -q "003TiGsrxkZglyDLBVoTQpTU6iJNJy4u7F2go941fMs="; then
    fail "Release binary contains the Debug test license key."
fi

# 4. Package
mkdir -p "$OUT"
DMG="$OUT/Flowy-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Flowy.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Flowy $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
[[ "$SIGN_IDENTITY" == "-" ]] || codesign --sign "$SIGN_IDENTITY" --timestamp=none "$DMG"
(cd "$OUT" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")

# 5. Sparkle appcast (optional). build/updates keeps appcast.xml between releases; generate_appcast
#    preserves older entries and adds this version with an EdDSA signature.
if [[ -n "${UPDATE_DOWNLOAD_BASE:-}" ]]; then
    SPARKLE_BIN="$DERIVED/SourcePackages/artifacts/sparkle/Sparkle/bin"
    [[ -x "$SPARKLE_BIN/generate_appcast" ]] || fail "Sparkle tools not found in $SPARKLE_BIN."
    UPDATES="$ROOT/build/updates"
    mkdir -p "$UPDATES"
    find "$UPDATES" -name '*.dmg' -delete
    cp "$DMG" "$UPDATES/"
    # Signing key: Keychain by default, or the backup file (SPARKLE_KEY_FILE, or ~/Documents/NotchFlow Keys/…).
    KEY_ARGS=()
    KEY_FILE="${SPARKLE_KEY_FILE:-$HOME/Documents/NotchFlow Keys/notchflow-sparkle-private.key}"
    [[ -f "$KEY_FILE" ]] && KEY_ARGS=(--ed-key-file "$KEY_FILE")
    "$SPARKLE_BIN/generate_appcast" "${KEY_ARGS[@]}" --download-url-prefix "${UPDATE_DOWNLOAD_BASE%/}/v$VERSION/" "$UPDATES"
    grep -q "sparkle:edSignature" "$UPDATES/appcast.xml" || fail "appcast has no EdDSA signature."
    cp "$UPDATES/appcast.xml" "$ROOT/appcast.xml"
    echo "Appcast: $ROOT/appcast.xml (commit it; SUFeedURL reads it from the main branch)"
    echo "Appcast: $UPDATES/appcast.xml (upload the .dmg to release tag v$VERSION, then publish appcast.xml at SUFeedURL)"
fi

echo "Built $DMG (version $VERSION, build $BUILD, signed: $SIGN_IDENTITY)"
cat "$DMG.sha256"
