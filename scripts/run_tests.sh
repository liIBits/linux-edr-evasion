#!/bin/bash
#
# run_tests.sh - Automated test runner for EDR evasion experiments
#
# This script runs both traditional and io_uring variants of each test
# and logs timestamps for correlation with auditd/Wazuh logs.
#
# Usage: ./run_tests.sh [iterations]
# Default: 30 iterations (as per your experimental design)

set -e

ITERATIONS=${1:-10}
BIN_DIR="./bin"
LOG_DIR="./logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/test_run_${TIMESTAMP}.log"
DATA_DIR="./data"
PROCESSED_DIR="${DATA_DIR}/processed"
RAW_DIR="${DATA_DIR}/raw"
CSV_FILE="${PROCESSED_DIR}/runs_${TIMESTAMP}.csv"
ENV_FILE="${RAW_DIR}/ENV_${TIMESTAMP}.txt"

mkdir -p "$PROCESSED_DIR" "$RAW_DIR"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S.%3N')] $*" | tee -a "$LOG_FILE"
}

run_test() {
    local name=$1
    local binary=$2
    local args=${3:-}

    local ts_start_epoch ts_start_human ts_end_epoch rc
    ts_start_epoch=$(date +%s)
    ts_start_human=$(date -d "@$ts_start_epoch" "+%Y-%m-%d %H:%M:%S")

    log "START: $name"
    if [ -x "$binary" ]; then
        set +e
        "$binary" $args 2>&1 | tee -a "$LOG_FILE"
        rc=$?
        set -e
        log "END: $name (exit=$rc)"
    else
        rc=127
        log "SKIP: $name - binary not found: $binary"
    fi

    ts_end_epoch=$(date +%s)

    # Count hits for your *existing* syscall-based rules
    local file_hits net_hits exec_hits
    file_hits=$(audit_hits_since "file_baseline" "$ts_start_human")
    net_hits=$(audit_hits_since "net_baseline" "$ts_start_human")
    exec_hits=$(audit_hits_since "exec_baseline" "$ts_start_human")

    echo "${ts_start_epoch},${ts_end_epoch},${i},${name},${file_hits},${net_hits},${exec_hits}" >> "$CSV_FILE"

    echo "" >> "$LOG_FILE"
}

audit_hits_since() {
    local key="$1"
    local start_ts="$2"
    sudo ausearch -k "$key" -ts "$start_ts" 2>/dev/null | wc -l
}


echo "========================================"
echo "EDR Evasion PoC Test Runner"
echo "========================================"
echo "Iterations: $ITERATIONS"
echo "Log file: $LOG_FILE"
echo "Start time: $(date)"
echo "========================================"
echo ""

echo "ts_start,ts_end,iteration,case,file_hits,net_hits,exec_hits" > "$CSV_FILE"

log "=== TEST RUN STARTED ==="
log "Iterations: $ITERATIONS"
log "Kernel: $(uname -r)"
log "Host: $(hostname)"

{
  echo "TIMESTAMP=$TIMESTAMP"
  echo "HOST=$(hostname)"
  echo "KERNEL=$(uname -r)"
  echo
  echo "=== OS ==="
  cat /etc/os-release || true
  echo
  echo "=== AUDIT STATUS ==="
  auditctl -s || true
  echo
  echo "=== AUDIT RULES (filtered) ==="
  auditctl -l | egrep "openat|connect|execve" || true
  echo
  echo "=== WAZUH AGENT ==="
  systemctl status wazuh-agent --no-pager || true
} > "$ENV_FILE"


for i in $(seq 1 $ITERATIONS); do
    log "=== ITERATION $i of $ITERATIONS ==="
    
    # File I/O tests
    log "--- File I/O Tests ---"
    run_test "file_io_traditional" "${BIN_DIR}/file_io_trad"
    sleep 0.5
    run_test "file_io_uring" "${BIN_DIR}/file_io_uring"
    sleep 0.5
    
    # File read tests (openat comparison)
    log "--- File Read Tests ---"
    run_test "read_file_traditional" "${BIN_DIR}/read_file_trad"
    sleep 0.5
    run_test "openat_uring" "${BIN_DIR}/openat_uring"
    sleep 0.5
    
    # Network tests
    log "--- Network Tests ---"
    run_test "net_connect_traditional" "${BIN_DIR}/net_connect_trad"
    sleep 0.5
    run_test "net_connect_uring" "${BIN_DIR}/net_connect_uring"
    sleep 0.5
    
    # Process execution test (traditional only - no io_uring equivalent)
    log "--- Process Execution Tests ---"
    run_test "exec_cmd_traditional" "${BIN_DIR}/exec_cmd_trad"
    sleep 0.5
    
    log "=== ITERATION $i COMPLETE ==="
    echo ""
done

log "=== TEST RUN COMPLETE ==="
log "End time: $(date)"

echo ""
echo "========================================"
echo "Test run complete!"
echo "Log file: $LOG_FILE"
echo ""
echo "Next steps:"
echo "1. Export auditd logs:  ausearch -ts today > audit_${TIMESTAMP}.log"
echo "2. Export Wazuh alerts from the manager"
echo "3. Compare detection rates between *_trad and *_uring runs"
echo "========================================"
