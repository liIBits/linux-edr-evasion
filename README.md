# CSC 786 Project — Evaluating Linux EDR Syscall Visibility (baseline vs io_uring)

## Project Context
This project evaluates whether a Linux EDR that relies on syscall-level telemetry (Wazuh + auditd) maintains visibility when equivalent activity is performed via an alternative execution pathway (io_uring). The goal is to measure detection coverage and highlight potential telemetry gaps, then provide defensive recommendations.

## Architecture (Lab Setup)
This work is performed in an isolated lab environment using three VMs:

- **Attacker VM (Ubuntu):** launches the test workloads and automation scripts.
- **Target VM (RHEL):** runs Wazuh agent and auditd to collect telemetry during each run.
- **Wazuh Manager VM:** centralizes alerts/logs from the target.

High-level flow:
1) Workload runs on **Target VM**
2) **auditd** + **Wazuh agent** collect events
3) Events/alerts are sent to the **Wazuh Manager**
4) Logs are collected and processed into **derived CSV metrics** for analysis

## What This Repository Contains
- `scripts/` — run, collect, and process scripts to reproduce experiments
- `data/processed/` — derived CSV metrics (tracked in Git)
- `data/raw/` — optional raw logs (NOT tracked; kept local)
- `analysis/` — notebook used to analyze CSV metrics
- `environment/` — setup notes and version pinning
- `DATA_README.md` — documents data sources, parameters, and output schema
- `ETHICS.md` — ethical + safety considerations

## Dependencies
Target VM (RHEL):
- gcc, make (for compiling workloads)
- auditd
- Wazuh agent

Manager VM:
- Wazuh manager (OVA or installed)

Analysis machine (Attacker VM or your local machine):
- Python 3.10+
- pandas
- matplotlib

Install Python dependencies:
```bash
pip install -r requirements.txt
