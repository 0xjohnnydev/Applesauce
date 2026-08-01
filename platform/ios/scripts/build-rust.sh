#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO=$(CDPATH= cd -- "$ROOT/../.." && pwd)
TARGET=${1:-aarch64-apple-ios-sim}
CONFIGURATION=${2:-Debug}

case "$TARGET" in
    aarch64-apple-ios-sim|aarch64-apple-ios)
        ;;
    *)
        echo "Usage: $0 [aarch64-apple-ios-sim|aarch64-apple-ios]" >&2
        exit 2
        ;;
esac

case "$CONFIGURATION" in
    Debug|Release)
        ;;
    *)
        echo "Usage: $0 [aarch64-apple-ios-sim|aarch64-apple-ios] [Debug|Release]" >&2
        exit 2
        ;;
esac

CARGO_TARGET_DIR="$REPO/build/rust-ios-native"
TOUCHHLE_BOOST_ROOT=${TOUCHHLE_BOOST_ROOT:-"$REPO/vendor/boost"}
CMAKE_TOOLCHAIN_FILE="$ROOT/cmake/TouchHLEiOS.cmake"
CMAKE_GENERATOR=Ninja
CMAKE="$ROOT/scripts/cmake-ios.sh"
DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
IPHONEOS_DEPLOYMENT_TARGET=17.4
CFLAGS="${CFLAGS:-} -ffile-prefix-map=$HOME=/build -fdebug-prefix-map=$HOME=/build"
CXXFLAGS="${CXXFLAGS:-} -DFMT_CONSTEVAL= -ffile-prefix-map=$HOME=/build -fdebug-prefix-map=$HOME=/build"
IOS_LINK_ARGS="--remap-path-prefix=$HOME=/build -C link-arg=-framework -C link-arg=AVFoundation -C link-arg=-framework -C link-arg=AudioToolbox -C link-arg=-framework -C link-arg=CoreBluetooth -C link-arg=-framework -C link-arg=CoreGraphics -C link-arg=-framework -C link-arg=CoreHaptics -C link-arg=-framework -C link-arg=CoreMotion -C link-arg=-framework -C link-arg=Foundation -C link-arg=-framework -C link-arg=GameController -C link-arg=-framework -C link-arg=Metal -C link-arg=-framework -C link-arg=OpenGLES -C link-arg=-framework -C link-arg=QuartzCore -C link-arg=-framework -C link-arg=UIKit"

for command in cargo cmake ninja xcrun; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Missing required command: $command" >&2
        exit 1
    fi
done

if [ ! -d "$TOUCHHLE_BOOST_ROOT/boost" ]; then
    echo "Boost headers were not found at $TOUCHHLE_BOOST_ROOT" >&2
    echo "Extract Boost into vendor/boost or set TOUCHHLE_BOOST_ROOT." >&2
    exit 1
fi

case "$TARGET" in
    aarch64-apple-ios-sim)
        SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
        CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS="$IOS_LINK_ARGS"
        export SDKROOT CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS
        ;;
    aarch64-apple-ios)
        SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
        CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS="$IOS_LINK_ARGS"
        export SDKROOT CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS
        ;;
esac

export CARGO_TARGET_DIR TOUCHHLE_BOOST_ROOT
export CMAKE_TOOLCHAIN_FILE CMAKE_GENERATOR CMAKE DEVELOPER_DIR IPHONEOS_DEPLOYMENT_TARGET
export CFLAGS CXXFLAGS

set -- build \
    --manifest-path "$ROOT/rust-entry/Cargo.toml" \
    --target "$TARGET"

if [ "$CONFIGURATION" = Release ]; then
    set -- "$@" --release
fi

cargo "$@"
