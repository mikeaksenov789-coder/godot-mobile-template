#!/usr/bin/env bash
# Runs the full pre-build gate, in the required order: unit tests ->
# content validators -> scene-instantiation smoke test. Each stage is a
# separate, independently-invokable Godot --script entry point (see
# tests/run_tests.gd, tools/validation/run_validation.gd,
# tests/run_smoke_test.gd); this script chains all three so both CI and
# a local `bash ci/run_tests.sh` run the same complete gate in one call,
# and so a failure in any one stage is attributed to that stage's own
# clearly-labeled `==  ==` section in the combined log rather than
# swallowed into a single opaque pass/fail.
#
# Also checks the combined output for a "SCRIPT ERROR" line as a second,
# complementary safety net. GDScript has no try/catch or error-count API
# a test can query — a runtime type error mid-_ready() (like Phase 2's
# Array[String] bug) prints "SCRIPT ERROR" and aborts just that function,
# without nulling out instantiate()'s result or otherwise failing that
# stage's own exit code. Grepping the log is the only way to catch that
# class of bug here (confirmed against this engine build) — see
# docs/ARCHITECTURE.md.
set -o pipefail

run_stage() {
  local label="$1"
  local script_path="$2"
  echo "::group::${label}"
  godot --headless --script "$script_path" 2>&1 | tee -a test_output.log
  local exit_code=${PIPESTATUS[0]}
  echo "::endgroup::"
  if [ "$exit_code" -ne 0 ]; then
    echo "::error::${label} failed (exit ${exit_code}) — see the ${label} section above."
  fi
  return "$exit_code"
}

: > test_output.log

STAGE_FAILED=0
run_stage "Unit tests" "res://tests/run_tests.gd" || STAGE_FAILED=1
run_stage "Content validators" "res://tools/validation/run_validation.gd" || STAGE_FAILED=1
run_stage "Scene smoke test" "res://tests/run_smoke_test.gd" || STAGE_FAILED=1

if grep -q "SCRIPT ERROR" test_output.log; then
  echo "::error::A SCRIPT ERROR was printed during the run — a scene likely failed to fully initialize even though no stage caught it. See the log above."
  STAGE_FAILED=1
fi

exit "$STAGE_FAILED"
