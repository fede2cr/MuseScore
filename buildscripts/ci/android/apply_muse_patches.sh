#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-Studio-CLA-applies
#
# Applies the Android-specific source patches to the muse_framework submodule.
#
# The muse/ directory is a git submodule, so we keep our local modifications as
# unified-diff patches under buildscripts/ci/android/patches/ instead of editing
# the submodule working tree directly. This script applies every patch in that
# directory (in lexical order) to the muse/ checkout.
#
# It is idempotent: patches that are already applied are skipped, so it is safe
# to run more than once (e.g. locally and again in CI).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MUSE_DIR="$REPO_ROOT/muse"
PATCHES_DIR="$SCRIPT_DIR/patches"

if [ ! -d "$MUSE_DIR" ]; then
    echo "error: muse submodule not found at $MUSE_DIR" >&2
    echo "hint: run 'git submodule update --init --recursive'" >&2
    exit 1
fi

if [ ! -d "$PATCHES_DIR" ]; then
    echo "No patches directory at $PATCHES_DIR, nothing to apply."
    exit 0
fi

shopt -s nullglob
patches=("$PATCHES_DIR"/*.patch)
shopt -u nullglob

if [ "${#patches[@]}" -eq 0 ]; then
    echo "No patches found in $PATCHES_DIR, nothing to apply."
    exit 0
fi

for patch in "${patches[@]}"; do
    name="$(basename "$patch")"

    # Already applied? (the patch applies cleanly in reverse)
    if git -C "$MUSE_DIR" apply --reverse --check "$patch" >/dev/null 2>&1; then
        echo "skip (already applied): $name"
        continue
    fi

    # Applies cleanly forward?
    if git -C "$MUSE_DIR" apply --check "$patch" >/dev/null 2>&1; then
        git -C "$MUSE_DIR" apply "$patch"
        echo "applied: $name"
        continue
    fi

    echo "error: cannot apply $name to muse submodule" >&2
    echo "hint: the patch may be stale relative to the current muse revision" >&2
    exit 1
done

echo "All muse patches applied."
