#!/usr/bin/env bash
# Computes and writes this build's Android versionName/versionCode into
# export_presets.cfg before either export preset (debug APK or release
# AAB) runs, so every artifact this pipeline produces is traceable back
# to the exact commit/tag that built it. Godot reads version/code and
# version/name directly from the preset file — there is no CLI override
# flag for them, so this patches the file in place.
#
# versionCode: Android requires a positive integer, unique and
# monotonically increasing across anything ever published to the same
# package. GITHUB_RUN_NUMBER increases by exactly 1 on every workflow run
# in this repository (push, tag, or manual dispatch alike) and never
# resets except if the workflow file itself is deleted and recreated — a
# zero-maintenance monotonic source requiring no state this repository
# would otherwise have to persist itself. Falls back to a Unix-timestamp
# outside CI (e.g. a local dry run), where GITHUB_RUN_NUMBER is unset —
# still monotonic for any single machine's clock, just not guaranteed
# unique across machines, which is fine for a value that only matters
# once an artifact is actually built and uploaded by CI.
#
# versionName: on a tag push matching v<version> (e.g. v1.2.3), the tag
# itself — stripped of its leading "v" — becomes the versionName, the
# human-facing release version a CTO actually tags. Every other trigger
# (push to main, workflow_dispatch, local) is a pre-release build and
# gets "0.0.0-dev+<short-sha>.<version-code>" instead, so a debug build
# is never mistaken for a tagged release by its version string alone.
set -euo pipefail

if [ -n "${GITHUB_RUN_NUMBER:-}" ]; then
  VERSION_CODE="$GITHUB_RUN_NUMBER"
else
  VERSION_CODE="$(date -u +%s)"
fi

# GITHUB_SHA is always set by Actions and needs no git call at all —
# preferred over `git rev-parse` specifically because actions/checkout's
# shallow (--depth=1) clone runs as a different filesystem owner than
# whatever user this script's shell runs as until actions/checkout's own
# post-job step adds a `safe.directory` allowance, which happens AFTER
# this script (confirmed by CI: `git rev-parse` silently fell back to
# "unknown" here on the first real run). `git rev-parse` stays as the
# fallback for a local dry run outside CI, where GITHUB_SHA is unset.
if [ -n "${GITHUB_SHA:-}" ]; then
  SHORT_SHA="${GITHUB_SHA:0:8}"
else
  SHORT_SHA="$(git rev-parse --short=8 HEAD 2>/dev/null || echo "unknown")"
fi

if [ -n "${GITHUB_REF:-}" ] && [[ "$GITHUB_REF" == refs/tags/v* ]]; then
  VERSION_NAME="${GITHUB_REF#refs/tags/v}"
  IS_RELEASE_TAG="true"
else
  VERSION_NAME="0.0.0-dev+${SHORT_SHA}.${VERSION_CODE}"
  IS_RELEASE_TAG="false"
fi

echo "versionCode=$VERSION_CODE"
echo "versionName=$VERSION_NAME"
echo "is_release_tag=$IS_RELEASE_TAG"

[ -f "export_presets.cfg" ] || { echo "::error::export_presets.cfg not found"; exit 1; }

# Applies to every [preset.N.options] section in the file — both the
# debug APK and release AAB presets get the same versionCode/versionName,
# which is what a single build of this repository should produce either
# way.
sed -i -E "s/^version\/code=.*/version\/code=${VERSION_CODE}/" export_presets.cfg
sed -i -E "s/^version\/name=\".*\"/version\/name=\"${VERSION_NAME}\"/" export_presets.cfg

if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "BUILD_VERSION_CODE=$VERSION_CODE"
    echo "BUILD_VERSION_NAME=$VERSION_NAME"
    echo "BUILD_IS_RELEASE_TAG=$IS_RELEASE_TAG"
  } >> "$GITHUB_ENV"
fi
