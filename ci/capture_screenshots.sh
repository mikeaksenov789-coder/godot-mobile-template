#!/usr/bin/env bash
# Captures QA screenshots at the defined checkpoints
# (tools/qa/screenshot_capture.gd) under a virtual X display and Mesa's
# software OpenGL renderer — no real GPU, no local machine, just this
# cloud CI runner. Installs Xvfb/Mesa if the pinned godot-ci image
# doesn't already have them: that image is built for headless export,
# not visual rendering, so neither is guaranteed to be present.
set -euo pipefail

# Always installed, not just when xvfb-run is missing: the first real CI
# run had xvfb-run absent (triggering this branch) but still failed —
# Godot's X11 backend also needs libfontconfig1/libxcursor1, which
# aren't pulled in as dependencies of xvfb/mesa alone, and their absence
# silently fell through to a Wayland fallback that isn't installed
# either ("Unable to create DisplayServer, all display drivers failed").
# apt no-ops on anything already present, so this is cheap to always run.
echo "Installing Xvfb and X11/Mesa runtime libraries for screenshot capture..."
apt-get update -qq
apt-get install -y --no-install-recommends \
  xvfb libgl1-mesa-dri libglx-mesa0 libfontconfig1 libxcursor1 libxi6 libxinerama1 libxrandr2

rm -rf screenshots
mkdir -p screenshots

xvfb-run --auto-servernum --server-args="-screen 0 1080x2340x24" \
  godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script res://tools/qa/screenshot_capture.gd

SHOT_COUNT="$(find screenshots -name '*.png' | wc -l)"
echo "Screenshot files on disk: $SHOT_COUNT"
if [ "$SHOT_COUNT" -eq 0 ]; then
  echo "::error::No screenshot PNGs were produced."
  exit 1
fi
