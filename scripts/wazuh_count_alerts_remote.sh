#!/usr/bin/env bash
set -euo pipefail

# Counts Wazuh manager alerts between START_EPOCH and END_EPOCH (inclusive)
# Optionally filters by agent name.

START_EPOCH="${1:?start epoch required}"
END_EPOCH="${2:?end epoch required}"
AGENT_NAME="${3:-}"   # optional; empty means no agent filter
ALERTS_FILE="/var/ossec/logs/alerts/alerts.json"

# Convert epoch to ISO8601 UTC (alerts.json typically uses ISO timestamps)
START_ISO="$(date -u -d "@$START_EPOCH" +"%Y-%m-%dT%H:%M:%S")"
END_ISO="$(date -u -d "@$END_EPOCH" +"%Y-%m-%dT%H:%M:%S")"

# JSONL scan (fast enough for class-scale runs). Counts alerts in window, optionally by agent.
sudo awk -v start="$START_ISO" -v end="$END_ISO" -v agent="$AGENT_NAME" '
  {
    # timestamp
    if (match($0, /"timestamp":"([^"]+)"/, t)) {
      ts = t[1]
    } else {
      next
    }

    if (ts < start || ts > end) next

    if (agent != "") {
      if (match($0, /"agent":\{"id":"[^"]+","name":"([^"]+)"/, a)) {
        if (a[1] != agent) next
      } else {
        next
      }
    }

    c++
  }
  END { print c+0 }
' "$ALERTS_FILE"
