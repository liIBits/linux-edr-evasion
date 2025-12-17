# Linux EDR Telemetry Visibility Experiment (io_uring vs Syscalls)

**CSC 786 – Computer Science Problems**  
**Author:** Michael Mendoza – Dakota State University

---

## Purpose

This project evaluates visibility gaps in syscall-focused EDR monitoring by comparing traditional Linux binaries with functionally equivalent io_uring-based binaries.

Detection visibility is measured using:

- **auditd** syscall rules on the target host
- **Wazuh EDR** (FIPS-enabled, out-of-the-box deployment)

The goal is **defensive research**, not exploitation.

---

## Quick Start

```bash
# 1. Clone and enter repo
git clone https://github.com/liIBits/linux-edr-evasion.git
cd linux-edr-evasion

# 2. Install dependencies (RHEL/Rocky)
sudo dnf install -y gcc make audit liburing liburing-devel

# 3. Build all binaries
make all

# 4. Load audit rules
sudo auditctl -R environment/99-edr-baseline.rules

# 5. Run experiment (30 iterations)
sudo ./run_experiment.sh 30
# OR
sudo make experiment N=30
```

---

## VM Downloads

| VM | Source | Notes |
|----|--------|-------|
| **Rocky Linux 9** | https://rockylinux.org/download | Use DVD ISO for full install |
| **Wazuh OVA** | https://documentation.wazuh.com/current/deployment-options/virtual-machine/virtual-machine.html | Pre-configured manager + indexer |

---

## Repository Structure

```
linux-edr-evasion/
├── run_experiment.sh          # <-- START HERE (wrapper script)
├── Makefile                   # Build and run targets
├── README.md
│
├── traditional/               # Traditional syscall C programs
│   ├── file_io.c
│   ├── read_file.c
│   ├── net_connect.c
│   └── exec_cmd.c
│
├── io_uring/                  # io_uring C programs (EDR evasion)
│   ├── file_io_uring.c
│   ├── openat_uring.c
│   └── net_connect_uring.c
│
├── scripts/
│   ├── run_tests.sh           # Main test harness
│   └── wazuh_count_alerts_remote.sh
│
├── environment/
│   ├── 99-edr-baseline.rules  # auditd rules
│   └── setup.md               # VM setup guide
│
├── bin/                       # Compiled binaries (after make)
├── data/                      # Experiment output
│   ├── raw/                   # Environment snapshots
│   └── processed/             # CSV results
├── logs/                      # Test run logs
│
├── analysis/
│   └── analysis.ipynb         # Jupyter notebook for analysis
│
├── DATA_README.md             # Data schema documentation
├── ETHICS.md                  # Ethics and responsible disclosure
└── requirements.txt
```

---

## Detailed Setup

### Environment Requirements

#### Rocky Linux Target VM

| Component | Details |
|-----------|---------|
| OS | Rocky Linux 9.x |
| Download | https://rockylinux.org/download |
| ISO Used | Rocky-9.5-x86_64-dvd.iso (or latest 9.x) |
| Kernel | 5.14+ (supports io_uring) |
| Requirements | auditd enabled, root access |

#### Wazuh Manager VM

| Component | Details |
|-----------|---------|
| OS | Wazuh preconfigured OVA |
| Download | https://documentation.wazuh.com/current/deployment-options/virtual-machine/virtual-machine.html |
| Version Used | Wazuh 4.14.1 |
| Default Credentials | User: `wazuh-user` / Password: `wazuh` |
| Configuration | FIPS mode enabled, SSH key auth |

#### Hypervisor

Any hypervisor that supports OVA import:
- VMware Workstation / Fusion
- VirtualBox
- Proxmox (convert OVA to qcow2)

#### Network Setup

Both VMs should be on the same network (NAT or bridged) so the Rocky target can communicate with the Wazuh manager.

### Step 1: Install Dependencies

**On Rocky Linux target:**

```bash
# Build tools and libraries
sudo dnf install -y gcc make audit liburing liburing-devel

# Python for analysis (optional, can run on separate machine)
sudo dnf install -y python3 python3-pip
```

**Install Wazuh Agent on Rocky Linux target:**

```bash
# Import Wazuh GPG key
sudo rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH

# Add Wazuh repository
sudo cat > /etc/yum.repos.d/wazuh.repo << 'EOF'
[wazuh]
name=Wazuh repository
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
EOF

# Install agent (replace WAZUH_MANAGER with your manager IP)
sudo WAZUH_MANAGER="10.0.0.7" dnf install -y wazuh-agent

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent

# Verify
sudo systemctl status wazuh-agent
```

### Step 2: Build Binaries

```bash
make all
```

This creates:
- `bin/file_io_trad`, `bin/read_file_trad`, `bin/net_connect_trad`, `bin/exec_cmd_trad`
- `bin/file_io_uring`, `bin/openat_uring`, `bin/net_connect_uring`

### Step 3: Load Audit Rules

```bash
sudo auditctl -R environment/99-edr-baseline.rules
sudo auditctl -l   # Verify rules loaded
```

### Step 4: Configure Wazuh (Optional)

If using Wazuh for alert collection:

```bash
# Generate SSH key on Rocky target
sudo ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa_fips

# Copy to Wazuh manager
sudo ssh-copy-id -i /root/.ssh/id_rsa_fips.pub wazuh-user@<WAZUH_IP>

# Copy helper script to Wazuh manager
scp scripts/wazuh_count_alerts_remote.sh wazuh-user@<WAZUH_IP>:/home/wazuh-user/
```

Set environment variables before running:
```bash
export WAZUH_MANAGER_HOST="10.0.0.7"
export WAZUH_MANAGER_USER="wazuh-user"
export WAZUH_AGENT_NAME="rocky-target-01"
```

### Step 5: Run Experiment

```bash
# Option A: Use wrapper script
sudo ./run_experiment.sh 30

# Option B: Use make
sudo make experiment N=30

# Option C: Direct script
sudo ./scripts/run_tests.sh 30
```

### Step 6: Analyze Results

```bash
# View CSV directly
column -t -s, data/processed/runs_*.csv

# Or use Python/Jupyter for full analysis
cd analysis
pip install -r ../requirements.txt
jupyter notebook analysis.ipynb
```

The `requirements.txt` includes pandas, matplotlib, seaborn, and scipy for data analysis and visualization.

---

## Metrics Collected

The experiment collects the following metrics per test case per iteration:

| Metric | Column | Description |
|--------|--------|-------------|
| **File Events** | `file_hits` | Audit events matching `file_baseline` key |
| **Network Events** | `net_hits` | Audit events matching `net_baseline` key |
| **Exec Events** | `exec_hits` | Audit events matching `exec_baseline` key |
| **io_uring Events** | `iouring_hits` | io_uring setup/enter syscalls detected |
| **Wazuh Alerts** | `wazuh_alerts` | SIEM alerts generated |
| **Time-to-Detection** | `time_to_detect` | Seconds from execution to first audit event |

### Primary Analysis Metrics

1. **Detection Rate** — proportion of runs producing ≥1 audit event
2. **False Negative Rate** — 1 - detection rate (runs with no alerts)
3. **Time-to-Detection** — median latency from execution to first alert

---

## Expected Results

| Operation | Traditional | io_uring | auditd Detection |
|-----------|-------------|----------|------------------|
| File write | write() | IORING_OP_WRITE | Trad: ✅ Uring: ❌ |
| File read | read() | IORING_OP_READ | Trad: ✅ Uring: ❌ |
| File open | openat() | IORING_OP_OPENAT | Trad: ✅ Uring: ❌ |
| Network connect | connect() | IORING_OP_CONNECT | Trad: ✅ Uring: ❌ |
| Process exec | execve() | N/A | Always ✅ |

Traditional syscall binaries generate higher audit and Wazuh alert counts than io_uring equivalents.

---

## Analysis Outputs

Running `analysis.ipynb` generates:

### Figures (`analysis/results/figures/`)

| Figure | Description |
|--------|-------------|
| `fig1_detection_rates.png` | Detection rate by test case (bar chart) |
| `fig2_paired_comparison.png` | Traditional vs io_uring mean events |
| `fig3_boxplots.png` | Distribution of audit events |
| `fig4_heatmap.png` | Detection heatmap by case and metric |
| `fig5_evasion.png` | Evasion effectiveness (% reduction) |

### Tables (`analysis/results/tables/`)

| Table | Description |
|-------|-------------|
| `detection_rates.csv` | Detection rates by case |
| `false_negative_rates.csv` | False negative rates |
| `time_to_detection.csv` | TTD statistics |
| `syscall_bypass_validation.csv` | Statistical proof of bypass |
| `mitre_mapping.csv` | ATT&CK technique mapping |

---

## MITRE ATT&CK Mapping

| Technique | Name | Test Case |
|-----------|------|-----------|
| T1059 | Command and Scripting Interpreter | exec_cmd |
| T1071 | Application Layer Protocol | net_connect |
| T1005 | Data from Local System | file_io, read_file |
| T1562.001 | Impair Defenses: Disable or Modify Tools | io_uring evasion |

---

## Make Targets

```bash
make help         # Show all available targets
make all          # Build everything
make traditional  # Build only traditional binaries
make iouring      # Build only io_uring binaries
make experiment   # Run with 10 iterations
make experiment N=30  # Run with custom iterations
make clean        # Remove compiled binaries
```

---

## Troubleshooting

### io_uring binaries fail with "Function not implemented"

- Kernel doesn't support io_uring or it's disabled
- Check: `cat /proc/sys/kernel/io_uring_disabled` (should be 0)
- Requires kernel 5.1+ (5.6+ for OPENAT, 5.19+ for SOCKET)

### No audit events captured

```bash
# Verify auditd is running
sudo systemctl status auditd

# Verify rules are loaded
sudo auditctl -l | grep baseline

# Check audit log directly
sudo ausearch -k file_baseline -ts recent
```

### CSV file is empty

- Make sure you're running with `sudo`
- Check that audit rules are loaded: `sudo auditctl -l`
- Check logs: `cat logs/test_run_*.log`

### Wazuh alerts always show 0

- Verify SSH connectivity: `sudo ssh -i /root/.ssh/id_rsa_fips wazuh-user@<IP>`
- Check the remote script exists on Wazuh manager
- This is optional — auditd metrics work independently

### Analysis notebook errors

```bash
# Ensure dependencies installed
pip install pandas numpy matplotlib seaborn scipy jupyter

# Check CSV exists
ls -la data/processed/runs_*.csv
```

---

## Reproducing This Research

To fully reproduce this experiment:

1. **Environment**: Rocky Linux 9.x VM with kernel 5.14+
2. **Dependencies**: `gcc`, `make`, `audit`, `liburing-devel`
3. **Audit Rules**: Load `environment/99-edr-baseline.rules`
4. **Build**: `make all`
5. **Run**: `sudo ./run_experiment.sh 30` (or more iterations)
6. **Analyze**: `jupyter notebook analysis/analysis.ipynb`

All experiment parameters are captured in:
- `data/raw/ENV_*.txt` — system state at runtime
- `logs/test_run_*.log` — detailed execution log
- `data/processed/runs_*.csv` — raw results

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-03-XX | Initial release |

---

## Ethics

This is **defensive research**. No malware, persistence mechanisms, or exploitation techniques are included. All test programs perform benign operations (read /etc/passwd, connect to 1.1.1.1, execute /bin/true).

See [ETHICS.md](ETHICS.md) for full disclosure.

---

## License

MIT — See [LICENSE](LICENSE) for details.

---

## References

- [io_uring documentation (Jens Axboe)](https://kernel.dk/io_uring.pdf)
- [liburing API](https://github.com/axboe/liburing)
- [ARMO: io_uring Rootkit Research](https://www.armosec.io/blog/io_uring-rootkit-bypasses-linux-security/)
- [MITRE ATT&CK T1562.001](https://attack.mitre.org/techniques/T1562/001/)
- [Wazuh Documentation](https://documentation.wazuh.com/)
- [Linux Audit System](https://github.com/linux-audit/audit-documentation)

---

## Acknowledgments

- Dakota State University — CSC 786 Course
- Wazuh Project — Open source SIEM
- Jens Axboe — io_uring creator and maintainer
