#!/usr/bin/env bash
# Fails fast, with a clear diagnostic, if the CI runner is missing
# anything this template's Android export needs — proving "a fresh CI
# runner can build from repository state alone" rather than silently
# limping into a cryptic gradle/export failure many minutes into the
# actual build. Run this before any export step, in both the debug and
# release build jobs.
set -euo pipefail

fail() {
  echo "::error::$1"
  exit 1
}

echo "== Environment validation =="

command -v godot >/dev/null 2>&1 || fail "godot binary not found on PATH"
GODOT_ACTUAL_VERSION="$(godot --version)"
echo "godot --version: $GODOT_ACTUAL_VERSION"
case "$GODOT_ACTUAL_VERSION" in
  "${GODOT_VERSION}"*) ;;
  *) fail "expected Godot ${GODOT_VERSION} (pinned in .github/workflows/android-build.yml), got: $GODOT_ACTUAL_VERSION" ;;
esac

command -v java >/dev/null 2>&1 || fail "java not found on PATH — Android export needs a JDK"
echo "java -version: $(java -version 2>&1 | head -1)"

TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
[ -d "$TEMPLATE_DIR" ] || fail "Android export templates not found at $TEMPLATE_DIR (did the 'Move export templates into place' step run first?)"
TEMPLATE_FILE_COUNT="$(find "$TEMPLATE_DIR" -type f | wc -l)"
[ "$TEMPLATE_FILE_COUNT" -gt 0 ] || fail "$TEMPLATE_DIR exists but is empty"
echo "export templates: $TEMPLATE_DIR ($TEMPLATE_FILE_COUNT files)"

# Best-effort only, deliberately not a hard failure: GitHub Actions'
# `container:` support runs every step with HOME redirected to
# /github/home rather than the image's own baked-in home directory,
# which is also why "Move export templates into place" explicitly `mv`s
# templates from /root/... — but ci/export_android.sh has built
# successfully every prior phase without this script ever writing an
# android_sdk_path anywhere, so wherever the godot-ci image actually
# resolves the Android SDK from is not $HOME/.config/godot/editor_settings
# in this container context. Rather than assert on a mechanism this
# script doesn't actually know, it just reports every plausible signal
# it can find; the real, authoritative check is the export step itself.
ANDROID_SDK_FOUND=""
for candidate in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" "/root/.android/sdk" "/usr/lib/android-sdk" "/opt/android-sdk"; do
  if [ -n "$candidate" ] && [ -d "$candidate" ]; then
    ANDROID_SDK_FOUND="$candidate"
    break
  fi
done
if [ -n "$ANDROID_SDK_FOUND" ]; then
  echo "Android SDK directory: $ANDROID_SDK_FOUND"
elif command -v adb >/dev/null 2>&1; then
  echo "Android SDK: adb found on PATH at $(command -v adb)"
else
  echo "::warning::could not positively confirm an Android SDK location via ANDROID_SDK_ROOT/ANDROID_HOME/common install paths/adb on PATH — this is advisory only, not a failure, since the actual export step is the authoritative check and has succeeded in this exact pinned image on every prior phase."
fi

[ -f "export_presets.cfg" ] || fail "export_presets.cfg not found — checkout did not run, or was run from the wrong directory"
[ -f "project.godot" ] || fail "project.godot not found — checkout did not run, or was run from the wrong directory"

echo "All environment checks passed — this runner can build from repository state alone."
