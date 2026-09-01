#!/usr/bin/env bash
# Runs the headless test suite, then checks its own output for a
# "SCRIPT ERROR" line as a second, complementary safety net.
#
# tests/run_tests.gd's own scene-instantiation smoke test catches a scene
# that fails to load/instantiate outright, but GDScript has no try/catch
# or error-count API a test can query — a runtime type error mid-_ready()
# (like Phase 2's Array[String] bug) prints "SCRIPT ERROR" and aborts
# just that function, without nulling out instantiate()'s result or
# otherwise failing the test suite's own exit code. Grepping the log is
# the only way to catch that class of bug here (confirmed against this
# engine build) — see docs/ARCHITECTURE.md.
set -o pipefail

godot --headless --script res://tests/run_tests.gd 2>&1 | tee test_output.log
GODOT_EXIT=$?

if grep -q "SCRIPT ERROR" test_output.log; then
  echo "::error::A SCRIPT ERROR was printed during the test run — a scene likely failed to fully initialize even though no test caught it. See the log above."
  exit 1
fi

exit "$GODOT_EXIT"
