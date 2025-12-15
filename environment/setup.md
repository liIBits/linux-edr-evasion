# Environment Setup (Lab)

## VMs
- Attacker VM: Ubuntu (automation + analysis)
- Target VM: RHEL (Wazuh agent + auditd)
- Manager VM: Wazuh Manager (OVA)

## Target VM Setup Checklist
- [ ] Install build tools: gcc, make
- [ ] Install/enable auditd
- [ ] Install/enable Wazuh agent and enroll with manager
- [ ] Confirm auditd log path (record here)
- [ ] Confirm Wazuh alerts source on manager (record here)

## Paths (fill in when verified)
- auditd log: /var/log/audit/audit.log
- Wazuh manager alerts: /var/ossec/logs/alerts/alerts.json

## Version Pinning (fill in during execution)
- Target OS:
- Kernel (uname -r):
- Wazuh manager version:
- Wazuh agent version:
- auditd version:

