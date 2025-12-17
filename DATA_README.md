# DATA_README — Data Collection and Processing

## Overview

This project collects syscall telemetry from controlled experiments comparing traditional syscall behavior against io_uring-based operations. The goal is to measure EDR detection gaps when attackers use io_uring to bypass syscall monitoring.

**Workflow:** `run_experiment.sh` → `run_tests.sh` → `runs_<timestamp>.csv` → `analysis.ipynb`

## Data Sources

### Target VM (Rocky Linux 9)
- **auditd logs** (`/var/log/audit/audit.log`)
  - Queried via `ausearch` with time window and key filters
  - Keys: `file_baseline`, `net_baseline`, `exec_baseline`, `iouring_setup`

- **Ground-truth artifacts**
  - `/tmp/test_*.txt` — confirms file I/O executed
  - Network connections to `1.1.1.1:80` — confirms net_connect executed

### Wazuh Manager VM
- **Wazuh alerts** (`/var/ossec/logs/alerts/alerts.json`)
  - Queried via API or direct log search
  - Used to measure SIEM-level detection coverage

## CSV Schema

Output file: `data/processed/runs_<YYYYMMDD_HHMMSS>.csv`

| Column | Type | Description |
|--------|------|-------------|
| `ts_start` | int | Unix epoch when test case started |
| `ts_end` | int | Unix epoch when test case ended |
| `iteration` | int | Run number (1 to N) |
| `case` | str | Test case name (see below) |
| `file_hits` | int | Audit events matching `file_baseline` key |
| `net_hits` | int | Audit events matching `net_baseline` key |
| `exec_hits` | int | Audit events matching `exec_baseline` key |
| `iouring_hits` | int | Audit events matching `iouring_setup` key |
| `wazuh_alerts` | int | Wazuh alerts in time window |
| `time_to_detect` | float | Seconds from ts_start to first audit event (-1 if none) |

## Test Cases

| Case Name | Method | Operation | Expected Behavior |
|-----------|--------|-----------|-------------------|
| `file_io_traditional` | Traditional | File write | High file_hits |
| `file_io_uring` | io_uring | File write | Low/zero file_hits |
| `read_file_traditional` | Traditional | File read | High file_hits |
| `openat_uring` | io_uring | File read | Low/zero file_hits |
| `net_connect_traditional` | Traditional | TCP connect | High net_hits |
| `net_connect_uring` | io_uring | TCP connect | Low/zero net_hits |
| `exec_cmd_traditional` | Traditional | Process exec | High exec_hits |

Note: `exec_cmd_uring` is not possible — io_uring does not support execve.

## Running an Experiment

```bash
# On target VM, from project root
sudo ./run_experiment.sh 30    # 30 iterations
```

This executes `scripts/run_tests.sh` which:
1. Reloads audit rules from `environment/99-edr-baseline.rules`
2. Runs each test case sequentially
3. Queries auditd after each case
4. Appends results to CSV

## Analysis

```bash
cd analysis
jupyter notebook analysis.ipynb
```

Outputs:
- `results/figures/` — PNG visualizations
- `results/tables/` — CSV summary tables including:
  - `detection_rates.csv`
  - `false_negative_rates.csv`
  - `time_to_detection.csv`
  - `syscall_bypass_validation.csv`

## Key Metrics

1. **Detection Rate** — proportion of runs with ≥1 audit event
2. **False Negative Rate** — 1 - detection_rate
3. **Time-to-Detection** — seconds from execution to first alert

## Reproducibility Notes

- Audit event counts may vary slightly due to kernel scheduling
- Consistent trends (traditional >> io_uring) are the key finding
- All derived metrics are regenerated from raw CSV by the notebook
