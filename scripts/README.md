# scripts

Automation scripts for running experiments and collecting data.

## Files

| Script | Purpose |
|--------|---------|
| `run_tests.sh` | Main test harness — runs all test cases and collects audit/Wazuh data |
| `wazuh_count_alerts_remote.sh` | Helper script executed on Wazuh manager via SSH |

## Usage

```bash
# Run from repo root (requires root for auditd access)
sudo ./scripts/run_tests.sh [iterations]

# Example: 30 iterations
sudo ./scripts/run_tests.sh 30
```

## What `run_tests.sh` Does

1. **Pre-flight checks** — verifies audit rules loaded, binaries exist, Wazuh connectivity
2. **Reloads audit rules** — ensures clean baseline from `environment/99-edr-baseline.rules`
3. **Runs test cases** — executes each binary and queries auditd afterward
4. **Outputs CSV** — writes results to `data/processed/runs_<timestamp>.csv`

## Environment Variables

Override defaults by exporting before running:

```bash
export WAZUH_MANAGER_HOST="10.0.0.7"
export WAZUH_MANAGER_USER="wazuh-user"
export WAZUH_AGENT_NAME="rocky-target-01"
export SSH_KEY="/root/.ssh/id_rsa_fips"
```

## Output Files

| File | Location |
|------|----------|
| Results CSV | `data/processed/runs_<timestamp>.csv` |
| Run log | `logs/test_run_<timestamp>.log` |
| Environment snapshot | `data/raw/ENV_<timestamp>.txt` |
