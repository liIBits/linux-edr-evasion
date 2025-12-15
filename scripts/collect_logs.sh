#!/usr/bin/env bash
set -euo pipefail

RUN_ID="${1:-$(date -u +%Y%m%dT%H%M%SZ)}"
OUT="data/raw/${RUN_ID}"
mkdir -p "$OUT"

echo "[collect] RUN_ID=$RUN_ID"
echo "[collect] Place raw auditd + Wazuh alert exports in: $OUT"
echo "Example:"
echo "  - auditd_export.log"
echo "  - wazuh_alerts.json"
echo "  - workload_stdout.log"

echo "$RUN_ID"

