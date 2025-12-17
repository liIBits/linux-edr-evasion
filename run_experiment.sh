#!/usr/bin/env bash
#
# run_experiment.sh - EDR Evasion Experiment Runner
#
# This is a convenience wrapper that calls the main test script.
# Place this in the repository root for easy discoverability.
#
# Usage:
#   sudo ./run_experiment.sh [iterations]
#   sudo ./run_experiment.sh 30
#
# Default: 10 iterations
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SCRIPT="${SCRIPT_DIR}/scripts/run_tests.sh"

if [[ ! -x "$TEST_SCRIPT" ]]; then
    echo "ERROR: Test script not found or not executable: $TEST_SCRIPT"
    echo "       Make sure you're running from the repository root."
    exit 1
fi

# Check if running as root (required for auditd access)
if [[ $EUID -ne 0 ]]; then
    echo "WARNING: This script should be run as root for full auditd access."
    echo "         Run with: sudo $0 $*"
    echo ""
fi

exec "$TEST_SCRIPT" "$@"
