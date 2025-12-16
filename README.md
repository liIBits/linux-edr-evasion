# Linux EDR Evasion via io_uring
A Reproducible Comparison of Traditional Syscall Telemetry vs io_uring Execution

---

## Overview

This project demonstrates how Linux programs implemented using io_uring generate significantly less observable telemetry than equivalent programs implemented with traditional system calls when monitored by a host-based EDR stack.

The experiment compares:
- Traditional syscall-based binaries
- Functionally equivalent io_uring-based binaries

Telemetry is collected using:
- auditd syscall rules on the target host
- A FIPS-enabled, out-of-the-box Wazuh EDR deployment

The goal is defensive insight, not exploitation.

---

## Ethical Scope

- No malware, persistence, or C2 infrastructure is used
- Programs perform benign actions only
- Code is provided for educational and defensive research

---

## Environment

Target Host:
- Rocky Linux
- auditd enabled
- Wazuh agent installed

EDR:
- Wazuh Manager
- FIPS mode enabled

---

## FIPS and SSH Keys

The Wazuh manager runs in FIPS mode and does not allow ED25519 keys.

RSA (≥2048-bit) keys are required. This project uses RSA-4096 keys.

---

## Build Instructions

```
dnf install -y gcc liburing-devel audit
make all
```

---

## SSH Setup

```
ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa_fips
ssh-copy-id -i /root/.ssh/id_rsa_fips.pub wazuh-user@<WAZUH_MANAGER_IP>
```

Verify:
```
ssh -i /root/.ssh/id_rsa_fips -o PasswordAuthentication=no wazuh-user@<WAZUH_MANAGER_IP>
```

---

## Running Tests

```
auditctl -R environment/99-edr-baseline.rules
cd scripts
./run_tests.sh
```

Results are written to data/processed/.

---

## Analysis

```
cd analysis
jupyter notebook analysis.ipynb
```

---

## Results Summary

Traditional syscall binaries trigger auditd and Wazuh alerts.

io_uring binaries perform equivalent actions with significantly reduced observable telemetry.

---

## Reproducibility

All steps are scripted and documented for full reproducibility.
