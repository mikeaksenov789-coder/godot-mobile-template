#!/usr/bin/env bash
# Builds the Android debug APK headlessly using the "Android" preset in
# export_presets.cfg (output path comes from that preset). Release export is
# deliberately not wired up yet: it needs a signing keystore, which is a
# human-owned secret (see docs/ARCHITECTURE.md, section 5) not available in
# this Phase 0 skeleton.
set -euo pipefail

mkdir -p build/android
godot --headless --verbose --export-debug "Android"
