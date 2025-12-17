# Ethics & Responsible Disclosure

## Purpose

This research investigates a detection gap in Linux security tooling. The goal is to **improve defensive capabilities** by documenting how io_uring can bypass syscall-based monitoring, enabling security teams to develop better detection strategies.

## Intended Use

- Academic research (CSC 786 - Applied Security Research)
- Defensive security evaluation
- EDR/SIEM detection engineering
- Security awareness and training

## Lab Isolation

All experiments are conducted in an **isolated virtual environment**:

- No connection to production networks
- No real user data or credentials
- Target VM is purpose-built for testing
- Network traffic limited to local lab subnet

## Dual-Use Considerations

This research documents techniques that could theoretically be misused. To minimize risk:

| Risk | Mitigation |
|------|------------|
| Weaponization | No weaponized payloads published; PoCs perform benign operations only |
| Exploitation guidance | Focus on detection methodology, not attack refinement |
| Script kiddie enablement | Techniques require kernel knowledge beyond typical attacker capability |
| Sensitive data exposure | Only derived metrics tracked; raw system logs kept local |

## What This Project Does NOT Include

- Privilege escalation exploits
- Rootkit or persistence mechanisms
- Data exfiltration capabilities
- Evasion of specific commercial EDR products
- Obfuscation or anti-forensics techniques

## Privacy

- No personally identifiable information (PII) is collected
- Test files contain only placeholder data (`test content`)
- Network connections target public infrastructure (1.1.1.1)
- Any system identifiers in logs are from isolated lab VMs

## Responsible Disclosure

The io_uring detection gap is **already publicly known** and documented by security researchers (e.g., ARMO's "Curing the Blindness" research). This project contributes to the existing body of defensive research rather than disclosing new vulnerabilities.

## References

- [ARMO: io_uring Rootkit Bypasses Linux Security](https://www.armosec.io/blog/io_uring-rootkit-bypasses-linux-security/)
- [LWN: The rapid growth of io_uring](https://lwn.net/Articles/810414/)
- [Kernel documentation: io_uring](https://kernel.dk/io_uring.pdf)

## Contact

For questions about this research, contact the author through Dakota State University.
