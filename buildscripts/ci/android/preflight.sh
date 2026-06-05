#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-Studio-CLA-applies

set -euo pipefail

EXPECTED_NDK_VERSION="28.0.12916984"

status=0

have_command() {
    command -v "$1" >/dev/null 2>&1
}

check_command() {
    local cmd="$1"
    if have_command "$cmd"; then
        echo "ok: command '$cmd' -> $(command -v "$cmd")"
    else
        echo "missing: command '$cmd'"
        status=1
    fi
}

check_dir() {
    local name="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo "missing: env '$name' is not set"
        status=1
        return
    fi

    if [[ -d "$value" ]]; then
        echo "ok: env '$name' -> $value"
    else
        echo "missing: env '$name' points to non-directory '$value'"
        status=1
    fi
}

echo "Android local preflight"
echo "======================="

check_command java
check_command javac
check_command cmake
check_command ninja
check_command adb
check_command sdkmanager

check_dir QT_ROOT_DIR "${QT_ROOT_DIR:-}"
check_dir ANDROID_SDK_ROOT "${ANDROID_SDK_ROOT:-}"
check_dir ANDROID_NDK_ROOT "${ANDROID_NDK_ROOT:-}"

if [[ -n "${QT_ROOT_DIR:-}" && -f "${QT_ROOT_DIR}/lib/cmake/Qt6/qt.toolchain.cmake" ]]; then
    echo "ok: Qt Android toolchain found"
else
    echo "missing: Qt Android toolchain not found under QT_ROOT_DIR/lib/cmake/Qt6/qt.toolchain.cmake"
    status=1
fi

if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    if [[ -x "${ANDROID_SDK_ROOT}/platform-tools/adb" ]]; then
        echo "ok: Android platform-tools present"
    else
        echo "missing: Android platform-tools not found under ANDROID_SDK_ROOT/platform-tools"
        status=1
    fi

    if [[ -d "${ANDROID_SDK_ROOT}/build-tools/35.0.0" ]]; then
        echo "ok: Android build-tools 35.0.0 present"
    else
        echo "missing: Android build-tools 35.0.0 not found"
        status=1
    fi

    if [[ -d "${ANDROID_SDK_ROOT}/platforms/android-35" ]]; then
        echo "ok: Android platform android-35 present"
    else
        echo "missing: Android platform android-35 not found"
        status=1
    fi
fi

if [[ -n "${ANDROID_NDK_ROOT:-}" ]]; then
    ndk_base="$(basename "${ANDROID_NDK_ROOT}")"
    if [[ "$ndk_base" == "$EXPECTED_NDK_VERSION" ]]; then
        echo "ok: expected NDK version $EXPECTED_NDK_VERSION selected"
    else
        echo "warning: expected NDK version $EXPECTED_NDK_VERSION, got $ndk_base"
    fi
fi

echo
if [[ "$status" -eq 0 ]]; then
    echo "Preflight passed. You can run:"
    echo "  bash ./buildscripts/ci/android/build.sh -n 9999 --build_mode devel"
else
    echo "Preflight failed. Fix the missing items above before running the Android build."
fi

exit "$status"