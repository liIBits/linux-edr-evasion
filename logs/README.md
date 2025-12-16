# Logs

Runtime logs from experiment runs.

## Files

| Pattern | Description |
|---------|-------------|
| `test_run_*.log` | Detailed output from `run_tests.sh` |

## Contents

Each log file includes:
- Timestamps for each test case start/end
- Binary execution output
- Audit query results
- Wazuh connectivity status
- Any errors or warnings

## Example

```
[2025-03-15 14:30:01.234] === CONFIGURATION ===
[2025-03-15 14:30:01.235] Repo root:   /home/user/linux-edr-evasion
[2025-03-15 14:30:01.236] Iterations:  30
[2025-03-15 14:30:01.500] === ITERATION 1 / 30 ===
[2025-03-15 14:30:01.501] START: file_io_traditional (iter=1)
[2025-03-15 14:30:01.850]   END: exit=0, duration=0s
[2025-03-15 14:30:01.900]   -> file=12 net=0 exec=0 iouring=0 wazuh=0 ttd=0s
```

## Git Tracking

Logs are typically **not tracked** in git (large, not needed for reproducibility).

Add to `.gitignore`:
```
logs/*.log
```

## Debugging

If experiments produce unexpected results, check the log for:
- Missing binaries (`SKIP: missing binary`)
- Audit rule issues (`WARNING: Audit rules may not be loaded`)
- Wazuh connection failures
