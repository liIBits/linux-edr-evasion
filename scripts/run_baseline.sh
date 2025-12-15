#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-/tmp/edr-run}"
mkdir -p "$OUT_DIR"

echo "[*] Baseline workload starting..."
echo "[*] Output dir: $OUT_DIR"

# 1) exec events
echo "[*] Exec events..."
/usr/bin/id >/dev/null
/usr/bin/uname -a >/dev/null
/bin/ls -la / >/dev/null

# 2) file open events
echo "[*] File open events..."
/bin/cat /etc/hosts >/dev/null
/bin/cat /etc/passwd >/dev/null
/bin/grep -i root /etc/passwd >/dev/null

# 3) network connect events (benign)
echo "[*] Network connect events..."
# Use curl (likely installed). If not installed, this will fail clearly.
curl -fsS http://example.com >/dev/null || true
curl -fsS https://example.com >/dev/null || true

echo "[*] Baseline workload complete."
date -Is > "$OUT_DIR/baseline_finished.timestamp"
