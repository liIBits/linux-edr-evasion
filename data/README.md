# Data

Experiment data storage.

## Structure

```
data/
├── raw/           # Environment snapshots, unprocessed logs
│   └── ENV_*.txt  # System state at experiment start
└── processed/     # Analysis-ready CSV files
    └── runs_*.csv # Main experiment results
```

## CSV Schema

See [DATA_README.md](../DATA_README.md) in the repo root for full schema documentation.

Quick reference:

| Column | Type | Description |
|--------|------|-------------|
| `ts_start` | int | Unix epoch start time |
| `ts_end` | int | Unix epoch end time |
| `iteration` | int | Run number |
| `case` | str | Test case name |
| `file_hits` | int | File-related audit events |
| `net_hits` | int | Network-related audit events |
| `exec_hits` | int | Exec-related audit events |
| `iouring_hits` | int | io_uring setup events |
| `wazuh_alerts` | int | Wazuh SIEM alerts |
| `time_to_detect` | float | Seconds to first detection (-1 if none) |

## File Naming

- `runs_YYYYMMDD_HHMMSS.csv` — results from experiment run
- `ENV_YYYYMMDD_HHMMSS.txt` — environment snapshot from same run

## Usage

The analysis notebook automatically loads the most recent CSV:

```python
csvs = sorted(Path('data/processed').glob('runs_*.csv'))
df = pd.read_csv(csvs[-1])
```

## Git Tracking

- `data/processed/*.csv` — **tracked** (derived metrics, reproducible)
- `data/raw/*.txt` — **tracked** (environment snapshots)
- Large binary logs — **not tracked** (add to .gitignore)
