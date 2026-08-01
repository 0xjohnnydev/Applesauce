#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if ! command -v cmake >/dev/null 2>&1; then
    echo "Missing required command: cmake" >&2
    exit 1
fi

case "${1:-}" in
    --build|--install|--open|--version|--help)
        exec cmake "$@"
        ;;
    *)
        exec cmake \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            "$@"
        ;;
esac
