# Linux EDR Telemetry Visibility Experiment (io_uring vs Syscalls)
CSC 786 – Computer Science Problems

---

## Purpose

This project evaluates visibility gaps in syscall-focused EDR monitoring by comparing traditional Linux binaries with functionally equivalent io_uring-based binaries.

Detection visibility is measured using:
- auditd syscall rules on the target host
- a FIPS-enabled, out-of-the-box Wazuh EDR deployment

The goal is defensive research, not exploitation.

---

## Reproducible Workflow Overview

1. Prepare the Wazuh manager
2. Prepare the Rocky Linux target
3. Build binaries
4. Load audit rules
5. Run automated experiments
6. Analyze results

Following this README end-to-end should allow reproduction of the experiment.

---

## Environment

### Rocky Linux Target
- Rocky Linux / RHEL-compatible
- auditd enabled
- Wazuh agent installed
- Root access available

### Wazuh Manager
- Default Wazuh installation
- FIPS mode enabled
- IP: 10.0.0.7
- User: wazuh-user

---

## Step 1: Prepare the Wazuh Manager

Log in:
```bash
ssh wazuh-user@10.0.0.7
```

Verify sudo:
```bash
sudo whoami
```

---

## Step 2: Prepare the Rocky Target

Clone the repository:
```bash
git clone <REPO_URL>
cd <REPO_NAME>
```

Install dependencies:
```bash
sudo dnf install -y gcc make audit liburing liburing-devel python3 python3-pip
```

---

## Step 3: Configure SSH (FIPS-Compatible)

Generate RSA key on Rocky:
```bash
sudo ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa_fips
```

Copy key to Wazuh manager:
```bash
sudo ssh-copy-id -i /root/.ssh/id_rsa_fips.pub wazuh-user@10.0.0.7
```

Verify key-only access:
```bash
sudo ssh -i /root/.ssh/id_rsa_fips -o PasswordAuthentication=no wazuh-user@10.0.0.7
```

---

## Step 4: Copy Wazuh Helper Script

From Rocky:
```bash
scp scripts/wazuh_count_alerts_remote.sh wazuh-user@10.0.0.7:/home/wazuh-user/
```

On Wazuh manager:
```bash
chmod 700 /home/wazuh-user/wazuh_count_alerts_remote.sh
```

---

## Step 5: Build Binaries

```bash
make clean
make all
```

---

## Step 6: Load Audit Rules

```bash
sudo auditctl -R environment/99-edr-baseline.rules
sudo auditctl -l
```

---

## Step 7: Run Experiment

```bash
sudo ./scripts/run_tests.sh 10
```

Outputs:
- data/processed/runs_<timestamp>.csv
- logs/test_run_<timestamp>.log
- data/raw/ENV_<timestamp>.txt

---

## Step 8: Analysis

```bash
cd analysis
jupyter notebook analysis.ipynb
```

The notebook loads the CSV and generates plots and tables.

---

## Expected Outcome

Traditional syscall binaries generate higher audit and Wazuh alert counts than io_uring equivalents.

---

## Ethics

No malware, persistence, or exploitation is performed. All programs are benign.

---

## Author

Michael Mendoza  
CSC 786 – Dakota State University
