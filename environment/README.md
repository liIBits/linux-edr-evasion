# environment/

Configuration files for the target VM and monitoring infrastructure.

## Files

| File | Purpose |
|------|---------|
| `99-edr-baseline.rules` | Linux audit rules for syscall monitoring |
| `setup.md` | VM setup and configuration guide |

## Audit Rules

The `99-edr-baseline.rules` file defines what syscalls auditd captures:

| Key | Syscalls Monitored | Purpose |
|-----|-------------------|---------|
| `file_baseline` | open, openat, openat2, read, readv, pread64, preadv, preadv2, write, writev, pwrite64, pwritev, pwritev2, close | File operation visibility |
| `net_baseline` | socket, connect, accept, accept4, sendto, sendmsg, sendmmsg, recvfrom, recvmsg, recvmmsg | Network operation visibility |
| `exec_baseline` | execve, execveat | Process execution visibility |
| `iouring_setup` | io_uring_setup, io_uring_enter, io_uring_register | io_uring behavioral detection |

### Architecture Note

Rules are configured for `arch=b64` only (64-bit syscalls). Rocky Linux 9 and RHEL 9 are 64-bit systems; 32-bit syscall variants use different names and are not required for this experiment.

Some syscalls (e.g., `pread64`, `pwrite64`) use numeric identifiers due to naming inconsistencies on RHEL 9:
- Syscall 17 = `pread64`
- Syscall 18 = `pwrite64`

## Installation

```bash
# Copy to audit rules directory
sudo cp 99-edr-baseline.rules /etc/audit/rules.d/

# Reload rules (temporary - resets on reboot)
sudo auditctl -R 99-edr-baseline.rules

# Or restart auditd (persistent)
sudo systemctl restart auditd

# Verify rules loaded
sudo auditctl -l | grep baseline
```

## Why `iouring_setup`?

While io_uring I/O operations bypass traditional syscall monitoring entirely, the management syscalls remain visible:

| Syscall | Visibility | Information Captured |
|---------|------------|---------------------|
| `io_uring_setup` | ✅ Detected | Ring buffer initialization |
| `io_uring_enter` | ✅ Detected | SQE submission / CQE polling |
| `io_uring_register` | ✅ Detected | File descriptor / buffer registration |
| `IORING_OP_READ` | ❌ Not detected | Actual read operation |
| `IORING_OP_WRITE` | ❌ Not detected | Actual write operation |
| `IORING_OP_CONNECT` | ❌ Not detected | Actual network connection |

This creates a **semantic gap**: defenders can detect *that* io_uring is being used but cannot determine *what* operations are being performed. The `iouring_setup` key provides behavioral detection—a process initializing io_uring may warrant additional scrutiny—but does not restore operational visibility.

## Customization

Edit buffer size or failure mode at the top of the rules file:

```
-b 8192           # Audit buffer size (increase if events are being dropped)
-f 1              # Failure mode: 0=silent, 1=printk, 2=panic
```

### Optional: Make Rules Immutable

Uncomment the following line in the rules file to prevent runtime modification (requires reboot to change):

```
-e 2
```

**Warning:** Only enable immutability after confirming rules work correctly.

## Troubleshooting

### "syscall name unknown" error

Rocky Linux 9 / RHEL 9 may not recognize certain syscall names. The provided rules use numeric syscall identifiers where necessary. If you encounter this error:

```bash
# Find the syscall number
ausyscall x86_64 <syscall_name>

# Use the number in the rule
-a always,exit -F arch=b64 -S <number> -k <key>
```

### Rules not capturing events

```bash
# Verify auditd is running
sudo systemctl status auditd

# Check for audit errors
sudo auditctl -s

# Test with a manual trigger
cat /etc/passwd
sudo ausearch -k file_baseline -ts recent
```

### High audit log volume

If audit logs grow too large, consider adding filters:

```bash
# Exclude specific users
-a always,exit -F arch=b64 -S openat -F auid!=1000 -k file_baseline

# Exclude specific paths
-a always,exit -F arch=b64 -S openat -F path!=/var/log -k file_baseline
```
