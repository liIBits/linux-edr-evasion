#!/usr/bin/env bash
set -euo pipefail

# =========================
# Configuration
# =========================
ITERATIONS=${1:-10}

BIN_DIR="./bin"
LOG_DIR="./logs"
DATA_DIR="./data"
RAW_DIR="${DATA_DIR}/raw"
PROCESSED_DIR="${DATA_DIR}/processed"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/test_run_${TIMESTAMP}.log"
CSV_FILE="${PROCESSED_DIR}/runs_${TIMESTAMP}.csv"
ENV_FILE="${RAW_DIR}/ENV_${TIMESTAMP}.txt"

# --- Wazuh manager config ---
WAZUH_MANAGER_HOST="${WAZUH_MANAGER_HOST:-10.0.0.7}"
WAZUH_MANAGER_USER="${WAZUH_MANAGER_USER:-wazuh-user}"
WAZUH_AGENT_NAME="${WAZUH_AGENT_NAME:-rocky-target-01}"
SSH_KEY="${SSH_KEY:-/root/.ssh/id_rsa_fips}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAZUH_REMOTE_SCRIPT="${REPO_ROOT}/scripts/wazuh_count_alerts_remote.sh"

mkdir -p "$LOG_DIR" "$RAW_DIR" "$PROCESSED_DIR"

log() {
  echo "[${TIMESTAMP}] $*" | tee -a "$LOG_FILE"
}

# =========================
# Helpers
# =========================
audit_hits_between() {
  local key="$1"
  local start_h="$2"
  local end_h="$3"
  sudo ausearch -k "$key" -ts "$start_h" -te "$end_h" 2>/dev/null | wc -l
}

wazuh_alerts_between() {
  local start_epoch="$1"
  local end_epoch="$2"

  if [[ ! -f "$WAZUH_REMOTE_SCRIPT" ]]; then
    echo "-1"
    return
  fi

  ssh -i "$SSH_KEY" \
  -o BatchMode=yes \
  -o ConnectTimeout=5 \
  -o PreferredAuthentications=publickey \
  -o PasswordAuthentication=no \
  "${WAZUH_MANAGER_USER}@${WAZUH_MANAGER_HOST}" \
  "bash -s -- ${start_epoch} ${end_epoch} ${WAZUH_AGENT_NAME}" < \
  "$WAZUH_REMOTE_SCRIPT" 2>/dev/null \
  || echo "-1"

}

run_case() {
  local case_name="$1"
  local binary="$2"

  local ts_start_epoch ts_end_epoch ts_start_h ts_end_h rc

  ts_start_epoch=$(date +%s)
  ts_start_h=$(date -d "@$ts_start_epoch" "+%Y-%m-%d %H:%M:%S")

  log "START: $case_name"
  if [[ -x "$binary" ]]; then
    set +e
    "$binary" 2>&1 | tee -a "$LOG_FILE"
    rc=$?
    set -e
  else
    rc=127
    log "SKIP: missing binary $binary"
  fi
  log "END: $case_name (exit=$rc)"

  ts_end_epoch=$(date +%s)
  ts_end_h=$(date -d "@$ts_end_epoch" "+%Y-%m-%d %H:%M:%S")

  local file_hits net_hits exec_hits wazuh_alerts
  file_hits=$(audit_hits_between "file_baseline" "$ts_start_h" "$ts_end_h")
  net_hits=$(audit_hits_between "net_baseline" "$ts_start_h" "$ts_end_h")
  exec_hits=$(audit_hits_between "exec_baseline" "$ts_start_h" "$ts_end_h")
  wazuh_alerts=$(wazuh_alerts_between "$ts_start_epoch" "$ts_end_epoch")

  echo "${ts_start_epoch},${ts_end_epoch},${i},${case_name},${file_hits},${net_hits},${exec_hits},${wazuh_alerts}" >> "$CSV_FILE"
}

# =========================
# CSV Header
# =========================
echo "ts_start,ts_end,iteration,case,file_hits,net_hits,exec_hits,wazuh_alerts" > "$CSV_FILE"

# =========================
# Environment snapshot
# =========================
{
  echo "TIMESTAMP=$TIMESTAMP"
  echo "HOST=$(hostname)"
  echo "KERNEL=$(uname -r)"
  echo
  echo "=== OS ==="
  cat /etc/os-release || true
  echo
  echo "=== AUDIT RULES ==="
  auditctl -l || true
  echo
  echo "=== WAZUH AGENT ==="
  systemctl status wazuh-agent --no-pager || true
} > "$ENV_FILE"

# =========================
# Main loop
# =========================
for i in $(seq 1 "$ITERATIONS"); do
  log "=== ITERATION $i / $ITERATIONS ==="

  run_case "file_io_traditional"     "${BIN_DIR}/file_io_trad"
  run_case "file_io_uring"           "${BIN_DIR}/file_io_uring"

  run_case "read_file_traditional"   "${BIN_DIR}/read_file_trad"
  run_case "openat_uring"            "${BIN_DIR}/openat_uring"

  run_case "net_connect_traditional" "${BIN_DIR}/net_connect_trad"
  run_case "net_connect_uring"       "${BIN_DIR}/net_connect_uring"

  run_case "exec_cmd_traditional"    "${BIN_DIR}/exec_cmd_trad"
done

log "DONE. CSV: $CSV_FILE"
