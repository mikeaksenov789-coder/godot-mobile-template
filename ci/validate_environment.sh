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

# The godot-ci image pre-bakes the Android SDK path into this exact
# Editor Settings file (confirmed in Phase 0 — see docs/ARCHITECTURE.md);
# ci/export_android.sh/ci/export_android_release.sh append java_sdk_path
# to the same file later, but the SDK path itself must already be there
# before either script runs.
SETTINGS_FILE="$HOME/.config/godot/editor_settings-${GODOT_VERSION%.*}.tres"
[ -f "$SETTINGS_FILE" ] || fail "expected the godot-ci image to pre-bake $SETTINGS_FILE with the Android SDK path, but it does not exist"
grep -q "android_sdk_path" "$SETTINGS_FILE" || fail "$SETTINGS_FILE exists but has no android_sdk_path set — Android SDK not configured"
echo "Android SDK path: $(grep "android_sdk_path" "$SETTINGS_FILE")"

[ -f "export_presets.cfg" ] || fail "export_presets.cfg not found — checkout did not run, or was run from the wrong directory"
[ -f "project.godot" ] || fail "project.godot not found — checkout did not run, or was run from the wrong directory"

echo "All environment checks passed — this runner can build from repository state alone."
