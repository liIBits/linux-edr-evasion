# Scripts Overview

This directory contains scripts used to reproduce the experimental workflow.

## Scripts

- `run_baseline.sh`
  - Executes the baseline workload using traditional syscalls

- `run_io_uring.sh`
  - Executes the io_uring-based workload (alternative execution path)

- `collect_logs.sh`
  - Collects auditd logs, Wazuh alerts, and workload output for a given run

- `process_logs.py`
  - Processes raw logs into derived CSV and JSON metrics

## Notes
Some scripts are placeholders until the lab environment is fully deployed.
This is intentional to separate workflow design from implementation.
