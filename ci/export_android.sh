#!/usr/bin/env bash
# Builds the Android debug APK headlessly using the "Android" preset in
# export_presets.cfg (output path comes from that preset). Release export is
# deliberately not wired up yet: it needs a signing keystore, which is a
# human-owned secret (see docs/ARCHITECTURE.md, section 5) not available in
# this Phase 0 skeleton.
set -euo pipefail

mkdir -p build/android

# The godot-ci image pre-bakes Editor Settings with the Android SDK path,
# but not the Java SDK path Godot 4.7's Android export also requires
# (export/android/java_sdk_path) — without it, export fails validation
# before it ever touches gradle. Detect the JDK actually installed in this
# container and add just that one key, rather than hardcoding a path that
# could drift if the base image changes.
JAVA_BIN="$(command -v java)"
JAVA_HOME_DETECTED="$(dirname "$(dirname "$(readlink -f "$JAVA_BIN")")")"
SETTINGS_FILE="$HOME/.config/godot/editor_settings-${GODOT_VERSION%.*}.tres"
mkdir -p "$(dirname "$SETTINGS_FILE")"
if [ ! -f "$SETTINGS_FILE" ]; then
  printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$SETTINGS_FILE"
fi
echo "export/android/java_sdk_path = \"$JAVA_HOME_DETECTED\"" >> "$SETTINGS_FILE"

# --install-android-build-template unpacks the gradle build skeleton from
# the export templates into res://android/ on first use; required whenever
# gradle_build/use_gradle_build is on (it is, for the reasons above).
godot --headless --verbose --install-android-build-template --export-debug "Android"
