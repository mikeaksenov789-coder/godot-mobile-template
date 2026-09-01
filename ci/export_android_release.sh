#!/usr/bin/env bash
# Builds the Android release App Bundle (.aab), signed with a CTO-owned
# keystore injected via CI secrets. This script is only ever invoked by
# the export-android-release job in .github/workflows/android-build.yml,
# and that job's build/upload steps are gated on
# secrets.ANDROID_KEYSTORE_BASE64 being present — every step here is
# skipped entirely, not failed, when that secret is absent. No keystore,
# password, or other credential is fabricated or committed by this
# script or anywhere else in this repository; see
# docs/ARCHITECTURE.md section 5 for how a human provisions the real
# secrets once the CTO is ready to sign a real release.
set -euo pipefail

: "${ANDROID_KEYSTORE_BASE64:?ANDROID_KEYSTORE_BASE64 must be set (this script must only run when that secret is configured)}"
: "${ANDROID_KEYSTORE_ALIAS:?ANDROID_KEYSTORE_ALIAS must be set}"
: "${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD must be set}"

mkdir -p build/android

JAVA_BIN="$(command -v java)"
JAVA_HOME_DETECTED="$(dirname "$(dirname "$(readlink -f "$JAVA_BIN")")")"
SETTINGS_FILE="$HOME/.config/godot/editor_settings-${GODOT_VERSION%.*}.tres"
mkdir -p "$(dirname "$SETTINGS_FILE")"
if [ ! -f "$SETTINGS_FILE" ]; then
  printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$SETTINGS_FILE"
fi
echo "export/android/java_sdk_path = \"$JAVA_HOME_DETECTED\"" >> "$SETTINGS_FILE"

KEYSTORE_PATH="${RUNNER_TEMP:-/tmp}/release.keystore"
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$KEYSTORE_PATH"
trap 'rm -f "$KEYSTORE_PATH"' EXIT

sed -i -E "s#^keystore/release=.*#keystore/release=\"${KEYSTORE_PATH}\"#" export_presets.cfg
sed -i -E "s#^keystore/release_user=.*#keystore/release_user=\"${ANDROID_KEYSTORE_ALIAS}\"#" export_presets.cfg
sed -i -E "s#^keystore/release_password=.*#keystore/release_password=\"${ANDROID_KEYSTORE_PASSWORD}\"#" export_presets.cfg

godot --headless --verbose --install-android-build-template --export-release "Android (Release)"
