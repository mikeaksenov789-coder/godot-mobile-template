#!/usr/bin/env bash
# Captures QA screenshots at the defined checkpoints
# (tools/qa/screenshot_capture.gd) under a virtual X display and Mesa's
# software OpenGL renderer — no real GPU, no local machine, just this
# cloud CI runner. Installs Xvfb/Mesa if the pinned godot-ci image
# doesn't already have them: that image is built for headless export,
# not visual rendering, so neither is guaranteed to be present.
set -euo pipefail

if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "xvfb-run not found — installing Xvfb and a software OpenGL renderer..."
  apt-get update -qq
  apt-get install -y --no-install-recommends xvfb libgl1-mesa-dri libglx-mesa0
fi

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
