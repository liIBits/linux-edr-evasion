# Scripts – Experiment Automation

This directory contains the automation harness used to execute all experimental
tests in a **controlled, repeatable manner**.

The scripts here are responsible for **data collection only**. They do not perform
analysis or modify detection rules beyond loading pre-defined configurations.

---

## Contents

### `run_tests.sh`
Primary experiment driver script.

This script:
- Executes traditional and `io_uring`-based binaries in a fixed order
- Repeats executions for a configurable number of iterations
- Records precise start/end timestamps for each run
- Queries existing `auditd` rules to measure syscall-level visibility
- Produces **structured, processed datasets** for downstream analysis

---

## Usage

Run the script as root (required for `auditd` access):

```bash
sudo ./run_tests.sh
```

By default, the script runs **10 iterations** of each test case.

To override the iteration count:

```bash
sudo ./run_tests.sh 20
```

---

## Output Artifacts

Running `run_tests.sh` produces the following artifacts:

### Processed Data (Tracked)
- `data/processed/runs_<timestamp>.csv`

This CSV contains one row per execution with the following fields:
- `ts_start` – epoch timestamp at start of execution
- `ts_end` – epoch timestamp at end of execution
- `iteration` – iteration number
- `case` – test case identifier
- `file_hits` – audit hits for file-related syscalls
- `net_hits` – audit hits for network-related syscalls
- `exec_hits` – audit hits for process execution syscalls

This file is intended to be consumed directly by the analysis notebook.

---

### Raw / Diagnostic Artifacts (Local Only)
- `logs/test_run_<timestamp>.log` – execution log
- `data/raw/ENV_<timestamp>.txt` – environment metadata snapshot

These artifacts are intentionally excluded from version control.

---

## Assumptions

- Audit rules have already been loaded (see `environment/99-edr-baseline.rules`)
- Binaries have been built using `make all`
- The system is otherwise idle to minimize unrelated audit noise

---

## Design Notes

- The script uses **existing syscall-focused audit rules** only.
- No custom rules are added to detect `io_uring` directly.
- Differences in audit hit counts reflect **observable telemetry**, not kernel behavior.

This design aligns with the experimental goals described in Assignment 3 and
supports reproducible evaluation for Assignments 4 and 5.

---

## Safety & Ethics

The script executes only benign test programs and performs read-only inspection
of audit logs. No persistence, exploitation, or adversarial activity is performed.
