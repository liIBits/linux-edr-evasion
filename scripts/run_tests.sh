#!/usr/bin/env bash
#
# run_tests.sh - Automated EDR Evasion Test Harness
#
# Runs traditional syscall binaries and io_uring equivalents,
# collecting auditd hits and Wazuh alerts for each run.
#
# UPDATED: Uses unique file paths per test case for cleaner measurement
#
# Usage: sudo ./scripts/run_tests.sh [iterations]
# Default: 10 iterations
#
# Output:
#   - data/processed/runs_TIMESTAMP.csv  (main results)
#   - data/raw/ENV_TIMESTAMP.txt         (environment snapshot)
#   - logs/test_run_TIMESTAMP.log        (detailed log)
#

set -uo pipefail  # No -e; we handle errors manually

# =========================
# Configuration
# =========================
ITERATIONS=${1:-10}

# Resolve paths relative to repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BIN_DIR="${REPO_ROOT}/bin"
LOG_DIR="${REPO_ROOT}/logs"
DATA_DIR="${REPO_ROOT}/data"
RAW_DIR="${DATA_DIR}/raw"
PROCESSED_DIR="${DATA_DIR}/processed"

# Test file directory - unique per run
TEST_DIR="/tmp/edr_test_$$"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/test_run_${TIMESTAMP}.log"
CSV_FILE="${PROCESSED_DIR}/runs_${TIMESTAMP}.csv"
ENV_FILE="${RAW_DIR}/ENV_${TIMESTAMP}.txt"

# --- Audit rule keys (must match 99-edr-baseline.rules) ---
AUDIT_KEY_FILE="file_baseline"
AUDIT_KEY_NET="net_baseline"
AUDIT_KEY_EXEC="exec_baseline"
AUDIT_KEY_IOURING="iouring_setup"
AUDIT_KEY_PATH="file_test_path"

# --- Wazuh manager config (override via environment) ---
WAZUH_MANAGER_HOST="${WAZUH_MANAGER_HOST:-10.0.0.7}"
WAZUH_MANAGER_USER="${WAZUH_MANAGER_USER:-wazuh-user}"
WAZUH_AGENT_NAME="${WAZUH_AGENT_NAME:-rocky-target-01}"
SSH_KEY="${SSH_KEY:-/root/.ssh/id_rsa_fips}"

WAZUH_REMOTE_SCRIPT="${SCRIPT_DIR}/wazuh_count_alerts_remote.sh"

# Create output directories
mkdir -p "$LOG_DIR" "$RAW_DIR" "$PROCESSED_DIR" "$TEST_DIR"

# =========================
# Logging
# =========================
log() {
    local now
    now=$(date "+%Y-%m-%d %H:%M:%S.%3N")
    echo "[${now}] $*" | tee -a "$LOG_FILE"
}

# =========================
# Helpers
# =========================

# Count audit EVENTS for a given key and time range
audit_event_count() {
    local key="$1"
    local start_ts="$2"
    local end_ts="$3"
    local count

    count=$(sudo ausearch -k "$key" -ts "$start_ts" -te "$end_ts" 2>/dev/null | grep -c "^type=" ) || true

    if [[ -z "$count" || ! "$count" =~ ^[0-9]+$ ]]; then
        echo "0"
    else
        echo "$count"
    fi
}

# Search audit log for a SPECIFIC file path
# This is key for proving io_uring evasion - the path won't appear for io_uring ops
audit_path_search() {
    local filepath="$1"
    local start_ts="$2"
    local end_ts="$3"
    local count

    # Search for the specific filepath in audit logs
    count=$(sudo ausearch -k "$AUDIT_KEY_FILE" -ts "$start_ts" -te "$end_ts" 2>/dev/null | grep -c "$filepath" ) || true

    if [[ -z "$count" || ! "$count" =~ ^[0-9]+$ ]]; then
        echo "0"
    else
        echo "$count"
    fi
}

# Get timestamp of first audit event for a key
audit_first_event_time() {
    local key="$1"
    local start_ts="$2"
    local end_ts="$3"
    local first_time

    first_time=$(sudo ausearch -k "$key" -ts "$start_ts" -te "$end_ts" 2>/dev/null | \
                 grep -m1 "^time->" | \
                 sed 's/time->//' | \
                 xargs -I{} date -d "{}" +%s 2>/dev/null) || true

    if [[ -z "$first_time" || ! "$first_time" =~ ^[0-9]+$ ]]; then
        echo "0"
    else
        echo "$first_time"
    fi
}

wazuh_alerts_between() {
    local start_epoch="$1"
    local end_epoch="$2"
    local count

    if [[ ! -f "$WAZUH_REMOTE_SCRIPT" ]]; then
        echo "0"
        return 0
    fi

    if [[ ! -f "$SSH_KEY" ]]; then
        echo "0"
        return 0
    fi

    count=$(ssh -i "$SSH_KEY" \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o PreferredAuthentications=publickey \
        -o PasswordAuthentication=no \
        "${WAZUH_MANAGER_USER}@${WAZUH_MANAGER_HOST}" \
        "bash -s -- ${start_epoch} ${end_epoch} ${WAZUH_AGENT_NAME}" < \
        "$WAZUH_REMOTE_SCRIPT" 2>/dev/null) || true

    if [[ -z "$count" || ! "$count" =~ ^[0-9]+$ ]]; then
        echo "0"
    else
        echo "$count"
    fi
}

# Run a file-based test case with unique filepath
run_file_case() {
    local case_name="$1"
    local binary="$2"
    local iteration="$3"
    local use_unique_path="$4"  # "yes" or "no"

    local ts_start_epoch ts_end_epoch ts_start_h ts_end_h rc
    local file_events net_events exec_events iouring_events wazuh_alerts
    local path_events first_alert_time time_to_detect
    local test_filepath=""

    # Create unique filepath for this test
    if [[ "$use_unique_path" == "yes" ]]; then
        test_filepath="${TEST_DIR}/${case_name}_iter${iteration}.txt"
    fi

    # Record start time
    ts_start_epoch=$(date +%s)
    ts_start_h=$(date -d "@$ts_start_epoch" "+%H:%M:%S")

    log "START: $case_name (iter=$iteration) ${test_filepath:+file=$test_filepath}"

    # Flush audit log before running
    sync
    
    if [[ -x "$binary" ]]; then
        # Run binary with filepath argument if applicable
        if [[ -n "$test_filepath" ]]; then
            "$binary" "$test_filepath" >> "$LOG_FILE" 2>&1 || true
        else
            "$binary" >> "$LOG_FILE" 2>&1 || true
        fi
        rc=${PIPESTATUS[0]:-$?}
    else
        rc=127
        log "  SKIP: missing binary $binary"
    fi

    # Small delay to ensure audit logs are flushed
    sleep 0.5
    sync

    # Record end time
    ts_end_epoch=$(date +%s)
    ts_end_h=$(date -d "@$ts_end_epoch" "+%H:%M:%S")

    log "  END: exit=$rc, duration=$((ts_end_epoch - ts_start_epoch))s"

    # Query audit events (general counts)
    file_events=$(audit_event_count "$AUDIT_KEY_FILE" "$ts_start_h" "$ts_end_h")
    net_events=$(audit_event_count "$AUDIT_KEY_NET" "$ts_start_h" "$ts_end_h")
    exec_events=$(audit_event_count "$AUDIT_KEY_EXEC" "$ts_start_h" "$ts_end_h")
    iouring_events=$(audit_event_count "$AUDIT_KEY_IOURING" "$ts_start_h" "$ts_end_h")

    # Path-specific search (KEY METRIC for proving evasion)
    if [[ -n "$test_filepath" ]]; then
        path_events=$(audit_path_search "$test_filepath" "$ts_start_h" "$ts_end_h")
    else
        path_events="-1"  # Not applicable
    fi

    # Query Wazuh alerts
    wazuh_alerts=$(wazuh_alerts_between "$ts_start_epoch" "$ts_end_epoch")

    # Calculate time-to-detection
    first_alert_time=$(audit_first_event_time "$AUDIT_KEY_FILE" "$ts_start_h" "$ts_end_h")
    if [[ "$first_alert_time" -gt 0 ]]; then
        time_to_detect=$((first_alert_time - ts_start_epoch))
    else
        time_to_detect="-1"
    fi

    # Log results
    log "  -> file=$file_events net=$net_events exec=$exec_events iouring=$iouring_events path_hits=$path_events wazuh=$wazuh_alerts ttd=${time_to_detect}s"

    # Write to CSV
    echo "${ts_start_epoch},${ts_end_epoch},${iteration},${case_name},${file_events},${net_events},${exec_events},${iouring_events},${wazuh_alerts},${time_to_detect},${path_events}" >> "$CSV_FILE"
}

# Run a network test case (no unique filepath needed)
run_net_case() {
    local case_name="$1"
    local binary="$2"
    local iteration="$3"

    local ts_start_epoch ts_end_epoch ts_start_h ts_end_h rc
    local file_events net_events exec_events iouring_events wazuh_alerts
    local first_alert_time time_to_detect

    ts_start_epoch=$(date +%s)
    ts_start_h=$(date -d "@$ts_start_epoch" "+%H:%M:%S")

    log "START: $case_name (iter=$iteration)"

    sync
    
    if [[ -x "$binary" ]]; then
        "$binary" >> "$LOG_FILE" 2>&1 || true
        rc=${PIPESTATUS[0]:-$?}
    else
        rc=127
        log "  SKIP: missing binary $binary"
    fi

    sleep 0.5
    sync

    ts_end_epoch=$(date +%s)
    ts_end_h=$(date -d "@$ts_end_epoch" "+%H:%M:%S")

    log "  END: exit=$rc, duration=$((ts_end_epoch - ts_start_epoch))s"

    file_events=$(audit_event_count "$AUDIT_KEY_FILE" "$ts_start_h" "$ts_end_h")
    net_events=$(audit_event_count "$AUDIT_KEY_NET" "$ts_start_h" "$ts_end_h")
    exec_events=$(audit_event_count "$AUDIT_KEY_EXEC" "$ts_start_h" "$ts_end_h")
    iouring_events=$(audit_event_count "$AUDIT_KEY_IOURING" "$ts_start_h" "$ts_end_h")

    wazuh_alerts=$(wazuh_alerts_between "$ts_start_epoch" "$ts_end_epoch")

    first_alert_time=$(audit_first_event_time "$AUDIT_KEY_NET" "$ts_start_h" "$ts_end_h")
    if [[ "$first_alert_time" -gt 0 ]]; then
        time_to_detect=$((first_alert_time - ts_start_epoch))
    else
        time_to_detect="-1"
    fi

    log "  -> file=$file_events net=$net_events exec=$exec_events iouring=$iouring_events wazuh=$wazuh_alerts ttd=${time_to_detect}s"

    # path_events = -1 for network tests (not applicable)
    echo "${ts_start_epoch},${ts_end_epoch},${iteration},${case_name},${file_events},${net_events},${exec_events},${iouring_events},${wazuh_alerts},${time_to_detect},-1" >> "$CSV_FILE"
}

# =========================
# Pre-flight checks
# =========================
echo ""
echo "=============================================="
echo "  Linux EDR Evasion - Test Harness"
echo "=============================================="
echo ""

log "=== CONFIGURATION ==="
log "Repo root:   $REPO_ROOT"
log "Binary dir:  $BIN_DIR"
log "Test dir:    $TEST_DIR"
log "Iterations:  $ITERATIONS"
log "CSV output:  $CSV_FILE"
log "Log file:    $LOG_FILE"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log "ERROR: This script must be run as root (for auditd access)"
    echo "Usage: sudo $0 [iterations]"
    exit 1
fi

# Check audit rules are loaded
log "Checking audit rules..."
audit_rules=$(auditctl -l 2>/dev/null | grep -c "_baseline\|iouring_setup" || true)
if [[ "$audit_rules" -lt 3 ]]; then
    log "WARNING: Audit rules may not be loaded properly (found $audit_rules matching rules)"
    log "         Run: sudo auditctl -R environment/99-edr-baseline.rules"
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    log "  Found $audit_rules audit rules matching baseline/iouring keys"
fi

# Check binaries exist
missing=0
for bin in file_io_trad file_io_uring read_file_trad openat_uring net_connect_trad net_connect_uring exec_cmd_trad; do
    if [[ ! -x "${BIN_DIR}/${bin}" ]]; then
        log "WARN: Binary missing: ${BIN_DIR}/${bin}"
        ((missing++)) || true
    fi
done

if [[ $missing -gt 0 ]]; then
    log "WARN: $missing binaries missing. Run 'make all' first."
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check Wazuh connectivity (optional)
if [[ -f "$SSH_KEY" ]] && [[ -f "$WAZUH_REMOTE_SCRIPT" ]]; then
    log "Wazuh: Checking connectivity to ${WAZUH_MANAGER_HOST}..."
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=3 "${WAZUH_MANAGER_USER}@${WAZUH_MANAGER_HOST}" "echo ok" &>/dev/null; then
        log "  Wazuh: Connected successfully"
    else
        log "  Wazuh: Connection failed - alerts will be recorded as 0"
    fi
else
    log "Wazuh: Not configured (SSH key or remote script missing)"
    log "       Wazuh alerts will be recorded as 0"
fi

# =========================
# CSV Header
# =========================
echo "ts_start,ts_end,iteration,case,file_hits,net_hits,exec_hits,iouring_hits,wazuh_alerts,time_to_detect,path_hits" > "$CSV_FILE"

if [[ ! -f "$CSV_FILE" ]]; then
    log "FATAL: Could not create CSV file: $CSV_FILE"
    exit 1
fi

log "CSV initialized: $CSV_FILE"

# =========================
# Environment snapshot
# =========================
{
    echo "=============================================="
    echo "Environment Snapshot"
    echo "=============================================="
    echo "TIMESTAMP=$TIMESTAMP"
    echo "HOST=$(hostname)"
    echo "KERNEL=$(uname -r)"
    echo "USER=$(whoami)"
    echo "EUID=$EUID"
    echo "REPO_ROOT=$REPO_ROOT"
    echo "TEST_DIR=$TEST_DIR"
    echo "ITERATIONS=$ITERATIONS"
    echo ""
    echo "=== OS ==="
    cat /etc/os-release 2>/dev/null || echo "N/A"
    echo ""
    echo "=== KERNEL IO_URING SUPPORT ==="
    echo "io_uring_disabled: $(cat /proc/sys/kernel/io_uring_disabled 2>/dev/null || echo 'N/A')"
    echo ""
    echo "=== AUDIT RULES ==="
    auditctl -l 2>/dev/null || echo "N/A (not root or auditd not running)"
    echo ""
    echo "=== AUDITD STATUS ==="
    systemctl status auditd --no-pager 2>/dev/null || echo "N/A"
    echo ""
    echo "=== WAZUH AGENT ==="
    systemctl status wazuh-agent --no-pager 2>/dev/null || echo "N/A"
    echo ""
    echo "=== BINARIES ==="
    ls -la "$BIN_DIR"/ 2>/dev/null || echo "N/A"
    echo ""
    echo "=== BINARY CHECKSUMS ==="
    sha256sum "$BIN_DIR"/* 2>/dev/null || echo "N/A"
} > "$ENV_FILE" 2>&1

log "Environment snapshot: $ENV_FILE"

# =========================
# Clear audit log before starting (fresh baseline)
# =========================
log "Clearing old audit events and reloading rules..."
sudo auditctl -D &>/dev/null || true
sleep 0.5
sudo auditctl -R "${REPO_ROOT}/environment/99-edr-baseline.rules" &>/dev/null || {
    log "WARNING: Could not reload audit rules"
}
sleep 0.5

# =========================
# Main loop
# =========================
echo ""
log "=== STARTING TEST RUN ($ITERATIONS iterations) ==="
echo ""

for i in $(seq 1 "$ITERATIONS"); do
    log "=== ITERATION $i / $ITERATIONS ==="

    # File I/O tests (write) - with unique file paths
    run_file_case "file_io_traditional"     "${BIN_DIR}/file_io_trad"       "$i" "yes"
    run_file_case "file_io_uring"           "${BIN_DIR}/file_io_uring"      "$i" "yes"

    # File I/O tests (read/open) - with unique file paths
    run_file_case "read_file_traditional"   "${BIN_DIR}/read_file_trad"     "$i" "yes"
    run_file_case "openat_uring"            "${BIN_DIR}/openat_uring"       "$i" "yes"

    # Network tests - no unique filepath needed
    run_net_case "net_connect_traditional" "${BIN_DIR}/net_connect_trad"   "$i"
    run_net_case "net_connect_uring"       "${BIN_DIR}/net_connect_uring"  "$i"

    # Process execution (traditional only - no io_uring equivalent)
    run_file_case "exec_cmd_traditional"    "${BIN_DIR}/exec_cmd_trad"      "$i" "no"

    log "=== ITERATION $i COMPLETE ==="
    echo ""
done

# =========================
# Summary
# =========================
echo ""
log "=============================================="
log "  TEST RUN COMPLETE"
log "=============================================="

csv_rows=$(wc -l < "$CSV_FILE")
data_rows=$((csv_rows - 1))

log "Total iterations: $ITERATIONS"
log "CSV data rows:    $data_rows (expected: $((ITERATIONS * 7)))"
log ""
log "Output files:"
log "  CSV:  $CSV_FILE"
log "  Log:  $LOG_FILE"
log "  Env:  $ENV_FILE"

if [[ $data_rows -eq 0 ]]; then
    log ""
    log "WARNING: No data rows written! Check the log for errors."
    exit 1
fi

echo ""
echo "=== CSV Preview ==="
head -10 "$CSV_FILE" | column -t -s,
echo ""

# Quick summary statistics
echo "=== Quick Stats ==="
echo ""
echo "Traditional cases (file_hits + net_hits + exec_hits):"
grep "traditional" "$CSV_FILE" | awk -F, '{sum+=$5+$6+$7} END {print "  Total audit events: " sum}'

echo ""
echo "io_uring cases:"
grep "uring" "$CSV_FILE" | awk -F, '{sum+=$5+$6} END {print "  Total file+net audit events: " sum}'
grep "uring" "$CSV_FILE" | awk -F, '{sum+=$8} END {print "  Total iouring_setup events: " sum}'

echo ""
echo "=== PATH-SPECIFIC DETECTION (KEY EVASION METRIC) ==="
echo "This shows whether the SPECIFIC test file appeared in audit logs:"
echo ""
echo "Traditional file operations (path_hits column):"
grep "file_io_traditional\|read_file_traditional" "$CSV_FILE" | awk -F, '{sum+=$11} END {print "  Total path hits: " sum " (should be > 0)"}'

echo ""
echo "io_uring file operations (path_hits column):"
grep "file_io_uring\|openat_uring" "$CSV_FILE" | awk -F, '{sum+=$11} END {print "  Total path hits: " sum " (should be 0 or very low = EVASION CONFIRMED)"}'

echo ""
echo "=== CLEANUP ==="
log "Test files were in: $TEST_DIR"
rm -rf "$TEST_DIR" 2>/dev/null || true
log "Test directory cleaned up"

echo ""
echo "Next steps:"
echo "  1. Review CSV:   column -t -s, $CSV_FILE"
echo "  2. Run analysis: cd analysis && jupyter notebook analysis.ipynb"
echo "  3. Full audit:   sudo ausearch -k file_baseline -ts today"
echo ""
