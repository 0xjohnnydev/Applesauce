#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO=$(CDPATH= cd -- "$ROOT/../.." && pwd)
SDK=${1:-iphonesimulator}
CONFIGURATION=${2:-Release}

case "$SDK" in
    iphonesimulator)
        DESTINATION='generic/platform=iOS Simulator'
        RUST_TARGET='aarch64-apple-ios-sim'
        ;;
    iphoneos)
        DESTINATION='generic/platform=iOS'
        RUST_TARGET='aarch64-apple-ios'
        ;;
    *)
        echo "Usage: $0 [iphonesimulator|iphoneos] [Debug|Release]" >&2
        exit 2
        ;;
esac

case "$CONFIGURATION" in
    Debug|Release)
        ;;
    *)
        echo "Usage: $0 [iphonesimulator|iphoneos] [Debug|Release]" >&2
        exit 2
        ;;
esac

DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
export DEVELOPER_DIR

sh "$ROOT/scripts/build-rust.sh" "$RUST_TARGET" "$CONFIGURATION"

xcodebuild \
    -project "$ROOT/TouchHLEHost.xcodeproj" \
    -scheme TouchHLEHost \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    -derivedDataPath "$REPO/build/host-$SDK" \
    CODE_SIGNING_ALLOWED=NO \
    build
