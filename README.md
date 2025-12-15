# Linux EDR Telemetry Visibility Experiment  
**CSC 786 – Computer Science Problems**

## Overview
This project evaluates how standard Linux, syscall-focused monitoring mechanisms
(e.g., `auditd` rules for `openat`, `connect`, and `execve`) observe execution
performed via traditional system calls versus execution delegated through
`io_uring`.

The goal is **not to bypass detection**, but to **measure differences in observable
telemetry** under commonly deployed monitoring configurations. All experiments are
conducted using benign, functionally equivalent programs.

---

## Repository Structure

```
.
├── analysis/
│   ├── analysis.ipynb        # Data analysis & visualization notebook
│   └── README.md
├── data/
│   ├── processed/            # Processed datasets (tracked)
│   └── raw/                  # Raw logs (ignored; local only)
├── environment/
│   ├── 99-edr-baseline.rules # auditd rules used in the experiment
│   ├── README.md
│   └── setup.md
├── scripts/
│   └── run_tests.sh          # Automated execution & data collection harness
├── traditional/              # Traditional syscall-based programs (C)
├── io_uring/                 # io_uring-based programs (C)
├── Makefile
├── requirements.txt
├── ETHICS.md
├── RUNS.md
└── README.md                 # This file
```

---

## Experimental Methodology (High-Level)

1. Functionally equivalent programs are compiled:
   - Traditional syscall implementations
   - `io_uring`-based implementations
2. Programs are executed under identical system conditions.
3. Detection visibility is measured using **existing auditd rules** that monitor:
   - `openat` (file access)
   - `connect` (network activity)
   - `execve` (process execution)
4. Per-run audit key hit counts are recorded into a structured dataset.
5. Results are analyzed using descriptive statistics and visualizations.

---

## System Requirements

- Rocky Linux / RHEL-compatible system
- Kernel with `io_uring` support
- Root privileges (required for `auditd`)
- Packages:
  ```bash
  sudo dnf install -y \
    gcc make audit \
    liburing liburing-devel \
    python3 python3-pip
  ```

- Python dependencies:
  ```bash
  pip install -r requirements.txt
  ```

---

## Reproducible Workflow

### 1) Build all binaries
```bash
make clean
make all
```

---

### 2) Load audit rules
```bash
sudo auditctl -R environment/99-edr-baseline.rules
```

Verify:
```bash
sudo auditctl -l
```

---

### 3) Run the experiment
```bash
sudo ./scripts/run_tests.sh
```

Artifacts produced:
- `data/processed/runs_<timestamp>.csv`
- `logs/test_run_<timestamp>.log`
- `data/raw/ENV_<timestamp>.txt`

---

### 4) Analyze results
```bash
jupyter notebook
```

Open:
```
analysis/analysis.ipynb
```

---

## Output Artifacts

- `results/figures/`
- `results/means_by_case.csv`
- `results/detect_rates_by_case.csv`

---

## Ethics & Scope
This project uses only benign test programs and focuses on measurement and analysis
of telemetry visibility. No malware or persistence mechanisms are deployed.

See `ETHICS.md` for details.

---

## Author
Michael Mendoza  
CSC 786 – Dakota State University
