#!/usr/bin/env bash
set -euo pipefail

RUN_TAG="${1:-run}"
DEST_BASE="${2:-/tmp/edr-collect}"
mkdir -p "$DEST_BASE"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${DEST_BASE}/${RUN_TAG}_${TS}"
mkdir -p "$OUT_DIR"

echo "[*] Collecting logs into: $OUT_DIR"

# --- audit logs ---
AUDIT_LOG="/var/log/audit/audit.log"
if [[ -f "$AUDIT_LOG" ]]; then
  cp -a "$AUDIT_LOG" "$OUT_DIR/audit.log"
else
  echo "[!] audit.log not found at $AUDIT_LOG" | tee "$OUT_DIR/WARN_audit_missing.txt"
fi

# audit rule listing + a small summary query
command -v auditctl >/dev/null && auditctl -l > "$OUT_DIR/audit_rules_loaded.txt" || true

# pull the last ~200 matching records for keys to show visibility
command -v ausearch >/dev/null && {
  ausearch -k exec_baseline 2>/dev/null | tail -n 200 > "$OUT_DIR/ausearch_exec_baseline_tail.txt" || true
  ausearch -k file_baseline 2>/dev/null | tail -n 200 > "$OUT_DIR/ausearch_file_baseline_tail.txt" || true
  ausearch -k net_baseline  2>/dev/null | tail -n 200 > "$OUT_DIR/ausearch_net_baseline_tail.txt"  || true
} || true

# --- wazuh agent logs (Rocky endpoint) ---
WAZUH_AGENT_LOG="/var/ossec/logs/ossec.log"
if [[ -f "$WAZUH_AGENT_LOG" ]]; then
  cp -a "$WAZUH_AGENT_LOG" "$OUT_DIR/wazuh_agent_ossec.log"
else
  echo "[!] Wazuh agent log not found at $WAZUH_AGENT_LOG" | tee "$OUT_DIR/WARN_wazuh_agent_log_missing.txt"
fi

# system status snapshot
uname -a > "$OUT_DIR/uname.txt" || true
ip a > "$OUT_DIR/ip_a.txt" || true
date -Is > "$OUT_DIR/collected.timestamp"

echo "[*] Done."
echo "$OUT_DIR"
