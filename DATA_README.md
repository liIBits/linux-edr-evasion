# DATA_README — Data Collection and Processing

## Overview

This project collects syscall telemetry from controlled experiments comparing traditional syscall-based operations against io_uring-based operations. The goal is to measure EDR detection gaps when attackers use io_uring to bypass syscall monitoring.

**Workflow:** `run_experiment.sh` → `run_tests.sh` → `runs_<timestamp>.csv` → `analysis.ipynb`

## Data Sources

### Target VM (Rocky Linux 9)

| Source | Path | Description |
|--------|------|-------------|
| auditd logs | `/var/log/audit/audit.log` | Primary syscall telemetry |
| Ground-truth artifacts | `/tmp/test_*.txt` | Confirms file I/O operations executed |

Audit logs are queried via `ausearch` with time window and key filters:
- `file_baseline` — file operations (open, read, write, close)
- `net_baseline` — network operations (socket, connect, send, recv)
- `exec_baseline` — process execution (execve)
- `iouring_setup` — io_uring management syscalls

### Wazuh Manager VM (Optional)

| Source | Path | Description |
|--------|------|-------------|
| Wazuh alerts | `/var/ossec/logs/alerts/alerts.json` | SIEM-level detection |

## Directory Structure

```
data/
├── raw/                    # Environment snapshots (not tracked in git)
│   └── ENV_<timestamp>.txt # System state at experiment start
└── processed/              # Analysis-ready CSV files (tracked in git)
    └── runs_<timestamp>.csv # Main experiment results
```

## CSV Schema

**Output file:** `data/processed/runs_<YYYYMMDD_HHMMSS>.csv`

| Column | Type | Description |
|--------|------|-------------|
| `ts_start` | int | Unix epoch when test case started |
| `ts_end` | int | Unix epoch when test case ended |
| `iteration` | int | Run number (1 to N) |
| `case` | string | Test case name (see below) |
| `file_hits` | int | Audit events matching `file_baseline` key |
| `net_hits` | int | Audit events matching `net_baseline` key |
| `exec_hits` | int | Audit events matching `exec_baseline` key |
| `iouring_hits` | int | Audit events matching `iouring_setup` key |
| `wazuh_alerts` | int | Wazuh alerts in time window (0 if not configured) |
| `time_to_detect` | float | Seconds from ts_start to first audit event (-1 if none) |

### Example Row

```csv
ts_start,ts_end,iteration,case,file_hits,net_hits,exec_hits,iouring_hits,wazuh_alerts,time_to_detect
1710523801,1710523802,1,file_io_traditional,12,0,0,0,0,0.1
1710523803,1710523804,1,file_io_uring,0,0,0,3,0,-1
```

## Test Cases

| Case Name | Method | Operation | Expected Audit Behavior |
|-----------|--------|-----------|------------------------|
| `file_io_traditional` | Traditional | File write | High `file_hits` |
| `file_io_uring` | io_uring | File write | Low/zero `file_hits`, non-zero `iouring_hits` |
| `read_file_traditional` | Traditional | File read | High `file_hits` |
| `openat_uring` | io_uring | File read | Low/zero `file_hits`, non-zero `iouring_hits` |
| `net_connect_traditional` | Traditional | TCP connect | High `net_hits` |
| `net_connect_uring` | io_uring | TCP connect | Low/zero `net_hits`, non-zero `iouring_hits` |
| `exec_cmd_traditional` | Traditional | Process exec | High `exec_hits` |

**Note:** There is no `exec_cmd_uring` because io_uring does not support the execve syscall.

## Running an Experiment

```bash
# On target VM, from project root
sudo ./run_experiment.sh 30    # 30 iterations
```

This executes `scripts/run_tests.sh` which:
1. Reloads audit rules from `environment/99-edr-baseline.rules`
2. Captures environment snapshot to `data/raw/ENV_<timestamp>.txt`
3. Runs each test case sequentially
4. Queries auditd after each case using time window and key filters
5. Appends results to `data/processed/runs_<timestamp>.csv`
6. Logs detailed output to `logs/test_run_<timestamp>.log`

## Analysis

```bash
cd analysis
jupyter notebook analysis.ipynb
```

### Outputs

**Figures** (`analysis/results/figures/`):
- `fig1_detection_rates.png` — Detection rate by test case
- `fig2_paired_comparison.png` — Traditional vs io_uring comparison
- `fig3_boxplots.png` — Audit event distributions
- `fig4_heatmap.png` — Detection heatmap
- `fig5_evasion.png` — Evasion effectiveness

**Tables** (`analysis/results/tables/`):
- `detection_rates.csv` — Detection rates by case
- `false_negative_rates.csv` — False negative rates
- `time_to_detection.csv` — TTD statistics
- `syscall_bypass_validation.csv` — Statistical validation of bypass
- `mitre_mapping.csv` — ATT&CK technique mapping

## Metrics

### Primary Metrics (per A3 requirements)

| Metric | Definition | Calculation |
|--------|------------|-------------|
| **Detection Rate** | Proportion of runs with ≥1 audit event | `audit_detected.mean()` |
| **False Negative Rate** | Proportion of runs with no detection | `1 - detection_rate` |
| **Time-to-Detection** | Latency from execution to first alert | `median(time_to_detect)` where > 0 |

### Revised Metrics (post-methodology refinement)

| Metric | Definition | Purpose |
|--------|------------|---------|
| **Path Visibility Rate** | Proportion of operations with file path in audit log | Forensic reconstruction capability |
| **Behavioral Completeness** | Whether full operation sequence is reconstructible | Incident response utility |
| **io_uring Setup Detection** | Whether io_uring initialization is visible | Behavioral indicator detection |

## Interpreting Results

### Expected Patterns

| Pattern | Interpretation |
|---------|----------------|
| High `file_hits` for traditional, zero for io_uring | ✅ Confirms syscall bypass |
| Non-zero `iouring_hits` for io_uring cases | ✅ Confirms behavioral detection works |
| Zero `iouring_hits` for io_uring cases | ❌ io_uring may be disabled or binary failed |
| Similar hits for both traditional and io_uring | ❌ Possible experimental error |

### Common Issues

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| All zeros for io_uring cases | `io_uring_disabled=2` | Enable io_uring (see setup.md) |
| All zeros for traditional cases | Audit rules not loaded | Reload rules with `auditctl -R` |
| Missing `iouring_hits` column | Old CSV format | Re-run experiment with updated script |

## Reproducibility Notes

- Exact audit event counts may vary slightly due to kernel scheduling and log buffering
- Consistent **trends** (traditional >> io_uring for file/net hits) are the key finding
- All derived metrics are regenerated from raw CSV by the analysis notebook
- Environment snapshots in `data/raw/` capture system state for reproducibility verification

## Git Tracking

| Directory | Tracked | Reason |
|-----------|---------|--------|
| `data/processed/*.csv` | ✅ Yes | Primary experiment results |
| `data/raw/*.txt` | ❌ No | Machine-specific, regenerated each run |
| `logs/*.log` | ✅ Yes | Required for audit trail per course requirements |
