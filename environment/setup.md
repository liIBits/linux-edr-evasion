# Environment Setup

## Architecture

```
┌─────────────────────┐      ┌─────────────────────┐
│  Target VM          │      │  Wazuh Manager VM   │
│  (Rocky Linux 9)    │─────▶│  (OVA)              │
│                     │      │                     │
│  - PoC binaries     │      │  - Wazuh Manager    │
│  - auditd           │      │  - alerts.json      │
│  - Wazuh agent      │      │  - API              │
└─────────────────────┘      └─────────────────────┘
```

## Target VM (Rocky Linux 9)

### Requirements
- Rocky Linux 9.x (or RHEL 9)
- Kernel 5.14+ (io_uring support)
- Root access for auditd

### Install Dependencies

```bash
# Build tools
sudo dnf groupinstall "Development Tools"
sudo dnf install liburing-devel

# Auditd (usually pre-installed)
sudo dnf install audit
sudo systemctl enable --now auditd

# Wazuh agent (see Wazuh docs for current install)
# https://documentation.wazuh.com/current/installation-guide/wazuh-agent/
```

### Setup Checklist

- [ ] Build tools installed (gcc, make)
- [ ] liburing-devel installed
- [ ] auditd running (`systemctl status auditd`)
- [ ] Audit rules loaded (`sudo auditctl -l | grep baseline`)
- [ ] Wazuh agent installed and enrolled
- [ ] Wazuh agent running (`systemctl status wazuh-agent`)
- [ ] SSH key configured for Wazuh manager access (optional)

### Verify io_uring Support

```bash
# Should return 0 (enabled) or 1 (unprivileged disabled) or 2 (fully disabled)
cat /proc/sys/kernel/io_uring_disabled

# If 2, io_uring is disabled system-wide — tests won't work
```

## Wazuh Manager VM

### Requirements
- Wazuh OVA (4.x) or manual installation
- Network connectivity to target VM

### Setup Checklist

- [ ] Wazuh manager running
- [ ] Target VM agent enrolled and active
- [ ] API accessible (for alert queries)

### Key Paths

| Path | Description |
|------|-------------|
| `/var/ossec/logs/alerts/alerts.json` | Real-time alerts |
| `/var/ossec/logs/archives/` | Archived logs |

## Network Configuration

| VM | IP (example) | Role |
|----|--------------|------|
| Target | 10.0.0.10 | Runs PoC binaries |
| Wazuh Manager | 10.0.0.7 | Collects alerts |

Update `scripts/run_tests.sh` environment variables:
```bash
export WAZUH_MANAGER_HOST="10.0.0.7"
export WAZUH_MANAGER_USER="wazuh-user"
export WAZUH_AGENT_NAME="rocky-target-01"
export SSH_KEY="/root/.ssh/id_rsa_fips"
```

## Version Pinning

Fill in during experiment execution:

| Component | Version |
|-----------|---------|
| Target OS | Rocky Linux 9.x |
| Kernel | `uname -r` |
| liburing | `rpm -q liburing` |
| auditd | `rpm -q audit` |
| Wazuh agent | `rpm -q wazuh-agent` |
| Wazuh manager | (from OVA or `/var/ossec/bin/wazuh-control info`) |

## Troubleshooting

### auditd not capturing events
```bash
# Check rules are loaded
sudo auditctl -l

# Reload rules
sudo auditctl -R environment/99-edr-baseline.rules

# Check audit log
sudo tail -f /var/log/audit/audit.log
```

### Wazuh agent not connecting
```bash
# Check agent status
sudo /var/ossec/bin/wazuh-control status

# Restart agent
sudo systemctl restart wazuh-agent

# Check manager connectivity
sudo /var/ossec/bin/agent-auth -m <manager_ip>
```

### io_uring binaries fail
```bash
# Check liburing linked
ldd bin/file_io_uring | grep uring

# Check kernel support
cat /proc/sys/kernel/io_uring_disabled
```
