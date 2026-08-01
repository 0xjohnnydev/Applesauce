#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO=$(CDPATH= cd -- "$ROOT/../.." && pwd)
IPA=${1:-"$REPO/dist/touchHLE-iOS-unsigned.ipa"}

case "$IPA" in
    /*) ;;
    *) IPA="$PWD/$IPA" ;;
esac

if [ ! -f "$IPA" ]; then
    echo "IPA not found: $IPA" >&2
    exit 1
fi

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/touchhle-verify.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT HUP INT TERM

unzip -tq "$IPA" >/dev/null
unzip -q "$IPA" -d "$STAGE"

APP="$STAGE/Payload/touchHLE.app"
if [ ! -d "$APP" ]; then
    echo "Payload/touchHLE.app is missing." >&2
    exit 1
fi

if codesign -dv "$APP" >/dev/null 2>&1; then
    echo "The IPA contains a signed app. Refusing release validation." >&2
    exit 1
fi

if [ -e "$APP/embedded.mobileprovision" ] || [ -d "$APP/_CodeSignature" ]; then
    echo "Signing material was found inside the app." >&2
    exit 1
fi

if grep -R -a -l '/Users/' "$APP" >/dev/null 2>&1; then
    echo "A local macOS user path was found inside the app." >&2
    exit 1
fi

if find "$APP" -type f \( \
    -name '*.ipa' -o \
    -name '*.mobileprovision' -o \
    -name '*.mobiledevicepairing' -o \
    -name '*.p12' -o \
    -name '*.cer' \
\) -print | grep -q .; then
    echo "Private or nested package material was found inside the app." >&2
    exit 1
fi

INFO="$APP/Info.plist"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO")

if [ "$BUNDLE_ID" != "org.touchhle.ios.unofficial" ]; then
    echo "Unexpected bundle identifier: $BUNDLE_ID" >&2
    exit 1
fi

file "$APP/touchHLE" | grep -q 'arm64'

echo "Verified unsigned IPA"
echo "Bundle: $BUNDLE_ID"
echo "Version: $VERSION ($BUILD)"
echo "Size: $(stat -f '%z' "$IPA") bytes"
shasum -a 256 "$IPA"
