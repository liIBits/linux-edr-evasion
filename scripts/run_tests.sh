#!/usr/bin/env bash
#
# run_tests.sh - Automated EDR Evasion Test Harness
#
# Runs traditional syscall binaries and io_uring equivalents,
# collecting auditd hits and Wazuh alerts for each run.
#
# Usage: sudo ./scripts/run_tests.sh [iterations]
# Default: 10 iterations
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

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/test_run_${TIMESTAMP}.log"
CSV_FILE="${PROCESSED_DIR}/runs_${TIMESTAMP}.csv"
ENV_FILE="${RAW_DIR}/ENV_${TIMESTAMP}.txt"

# --- Wazuh manager config (override via environment) ---
WAZUH_MANAGER_HOST="${WAZUH_MANAGER_HOST:-10.0.0.7}"
WAZUH_MANAGER_USER="${WAZUH_MANAGER_USER:-wazuh-user}"
WAZUH_AGENT_NAME="${WAZUH_AGENT_NAME:-rocky-target-01}"
SSH_KEY="${SSH_KEY:-/root/.ssh/id_rsa_fips}"

WAZUH_REMOTE_SCRIPT="${SCRIPT_DIR}/wazuh_count_alerts_remote.sh"

# Create output directories
mkdir -p "$LOG_DIR" "$RAW_DIR" "$PROCESSED_DIR"

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
audit_hits_between() {
    local key="$1"
    local start_h="$2"
    local end_h="$3"
    local count

    # ausearch returns exit code 1 when no records found - that's expected
    count=$(sudo ausearch -k "$key" -ts "$start_h" -te "$end_h" 2>/dev/null | wc -l) || true

    # Ensure we return a valid number
    if [[ -z "$count" || ! "$count" =~ ^[0-9]+$ ]]; then
        echo "0"
    else
        echo "$count"
    fi
}

wazuh_alerts_between() {
    local start_epoch="$1"
    local end_epoch="$2"
    local count

    if [[ ! -f "$WAZUH_REMOTE_SCRIPT" ]]; then
        # Silent skip if script doesn't exist - user may not have Wazuh configured
        echo "0"
        return 0
    fi

    if [[ ! -f "$SSH_KEY" ]]; then
        # No SSH key configured
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

    # Ensure we return a valid number
    if [[ -z "$count" || ! "$count" =~ ^[0-9]+$ ]]; then
        echo "0"
    else
        echo "$count"
    fi
}

run_case() {
    local case_name="$1"
    local binary="$2"
    local iteration="$3"

    local ts_start_epoch ts_end_epoch ts_start_h ts_end_h rc

    ts_start_epoch=$(date +%s)
    ts_start_h=$(date -d "@$ts_start_epoch" "+%Y-%m-%d %H:%M:%S")

    log "START: $case_name"

    if [[ -x "$binary" ]]; then
        # Run binary and capture exit code without failing script
        "$binary" 2>&1 | tee -a "$LOG_FILE" || true
        rc=${PIPESTATUS[0]}
    else
        rc=127
        log "SKIP: missing binary $binary"
    fi

    log "END: $case_name (exit=$rc)"

    # Small delay to ensure audit logs are flushed
    sleep 0.2

    ts_end_epoch=$(date +%s)
    ts_end_h=$(date -d "@$ts_end_epoch" "+%Y-%m-%d %H:%M:%S")

    local file_hits net_hits exec_hits wazuh_alerts
    file_hits=$(audit_hits_between "file_baseline" "$ts_start_h" "$ts_end_h")
    net_hits=$(audit_hits_between "net_baseline" "$ts_start_h" "$ts_end_h")
    exec_hits=$(audit_hits_between "exec_baseline" "$ts_start_h" "$ts_end_h")
    wazuh_alerts=$(wazuh_alerts_between "$ts_start_epoch" "$ts_end_epoch")

    # Debug output
    log "  -> file=$file_hits net=$net_hits exec=$exec_hits wazuh=$wazuh_alerts"

    # Write to CSV
    echo "${ts_start_epoch},${ts_end_epoch},${iteration},${case_name},${file_hits},${net_hits},${exec_hits},${wazuh_alerts}" >> "$CSV_FILE"
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
log "Iterations:  $ITERATIONS"
log "CSV output:  $CSV_FILE"
log "Log file:    $LOG_FILE"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log "WARNING: Not running as root - auditd queries may fail"
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
        log "Wazuh: Connected successfully"
    else
        log "Wazuh: Connection failed - alerts will be recorded as 0"
    fi
else
    log "Wazuh: Not configured (SSH key or remote script missing)"
fi

# =========================
# CSV Header
# =========================
echo "ts_start,ts_end,iteration,case,file_hits,net_hits,exec_hits,wazuh_alerts" > "$CSV_FILE"

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
    echo ""
    echo "=== OS ==="
    cat /etc/os-release 2>/dev/null || echo "N/A"
    echo ""
    echo "=== AUDIT RULES ==="
    sudo auditctl -l 2>/dev/null || echo "N/A (not root or auditd not running)"
    echo ""
    echo "=== WAZUH AGENT ==="
    systemctl status wazuh-agent --no-pager 2>/dev/null || echo "N/A"
    echo ""
    echo "=== BINARIES ==="
    ls -la "$BIN_DIR"/ 2>/dev/null || echo "N/A"
} > "$ENV_FILE" 2>&1

log "Environment snapshot: $ENV_FILE"

# =========================
# Main loop
# =========================
echo ""
log "=== STARTING TEST RUN ($ITERATIONS iterations) ==="
echo ""

for i in $(seq 1 "$ITERATIONS"); do
    log "=== ITERATION $i / $ITERATIONS ==="

    # File I/O tests
    run_case "file_io_traditional"     "${BIN_DIR}/file_io_trad"       "$i"
    run_case "file_io_uring"           "${BIN_DIR}/file_io_uring"      "$i"

    # File read/open tests
    run_case "read_file_traditional"   "${BIN_DIR}/read_file_trad"     "$i"
    run_case "openat_uring"            "${BIN_DIR}/openat_uring"       "$i"

    # Network tests
    run_case "net_connect_traditional" "${BIN_DIR}/net_connect_trad"   "$i"
    run_case "net_connect_uring"       "${BIN_DIR}/net_connect_uring"  "$i"

    # Process execution (traditional only - no io_uring equivalent)
    run_case "exec_cmd_traditional"    "${BIN_DIR}/exec_cmd_trad"      "$i"

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
log "CSV data rows:    $data_rows"
log ""
log "Output files:"
log "  CSV:  $CSV_FILE"
log "  Log:  $LOG_FILE"
log "  Env:  $ENV_FILE"

if [[ $data_rows -eq 0 ]]; then
    log ""
    log "WARNING: No data rows written! Check the log for errors."
else
    echo ""
    echo "=== CSV Preview (first 5 rows) ==="
    head -6 "$CSV_FILE" | column -t -s,
    echo ""
fi

echo ""
echo "Next steps:"
echo "  1. Review:   cat $CSV_FILE | column -t -s,"
echo "  2. Analyze:  cd analysis && jupyter notebook analysis.ipynb"
echo "  3. Audit:    sudo ausearch -ts today -k file_baseline"
echo ""
