#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO=$(CDPATH= cd -- "$ROOT/../.." && pwd)
APP="$REPO/build/host-iphoneos/Build/Products/Release-iphoneos/touchHLE.app"
OUTPUT=${1:-"$REPO/dist/touchHLE-iOS-unsigned.ipa"}

case "$OUTPUT" in
    /*) ;;
    *) OUTPUT="$PWD/$OUTPUT" ;;
esac

if [ ! -d "$APP" ]; then
    echo "Unsigned app not found at $APP" >&2
    echo "Run platform/ios/scripts/build-host.sh iphoneos Release first." >&2
    exit 1
fi

if codesign -dv "$APP" >/dev/null 2>&1; then
    echo "Refusing to package a signed app: $APP" >&2
    echo "Rebuild with platform/ios/scripts/build-host.sh iphoneos Release." >&2
    exit 1
fi

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/touchhle-ipa.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT HUP INT TERM

mkdir -p "$STAGE/Payload" "$(dirname -- "$OUTPUT")"
ditto "$APP" "$STAGE/Payload/touchHLE.app"
STRIP_TOOL=$(xcrun --find strip)
"$STRIP_TOOL" -S -x "$STAGE/Payload/touchHLE.app/touchHLE"
(
    cd "$STAGE"
    /usr/bin/zip -qry "$STAGE/touchHLE.ipa" Payload
)
mv -f "$STAGE/touchHLE.ipa" "$OUTPUT"

echo "Created unsigned IPA: $OUTPUT"
CHECKSUM="$OUTPUT.sha256"
(
    cd "$(dirname -- "$OUTPUT")"
    shasum -a 256 "$(basename -- "$OUTPUT")" >"$(basename -- "$CHECKSUM")"
)
cat "$CHECKSUM"
echo "Created checksum: $CHECKSUM"
