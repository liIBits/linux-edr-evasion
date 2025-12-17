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
| `file_baseline` | open, openat, openat2, read, readv, pread64 (17), preadv (295), preadv2 (327), write, writev, pwrite64 (18), pwritev (296), pwritev2 (328), close | File operation visibility |
| `file_test_path` | Watch on `/tmp/edr_test` (rwxa) | Path-specific file monitoring |
| `net_baseline` | socket, connect, accept, accept4, sendto, sendmsg, recvfrom, recvmsg | Network operation visibility |
| `exec_baseline` | execve, execveat | Process execution visibility |
| `iouring_setup` | io_uring_setup (425), io_uring_enter (426), io_uring_register (427) | io_uring behavioral detection |

### Architecture Note

Rules are configured for `arch=b64` only (64-bit syscalls). Rocky Linux 9 and RHEL 9 are 64-bit systems; 32-bit syscall variants use different names and are not required for this experiment.

### Syscall Number Reference (x86_64)

Some syscalls use numeric identifiers due to naming inconsistencies on RHEL 9:

| Syscall | Number | Notes |
|---------|--------|-------|
| pread64 | 17 | Name not recognized on RHEL 9 |
| pwrite64 | 18 | Name not recognized on RHEL 9 |
| preadv | 295 | Vectored positioned read |
| pwritev | 296 | Vectored positioned write |
| preadv2 | 327 | Extended vectored read |
| pwritev2 | 328 | Extended vectored write |
| io_uring_setup | 425 | io_uring initialization |
| io_uring_enter | 426 | SQE submission |
| io_uring_register | 427 | Resource registration |

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

### Create Test Directory

The rules include a path watch on `/tmp/edr_test`. Create this directory before running experiments:

```bash
mkdir -p /tmp/edr_test
```

## Why `iouring_setup`?

While io_uring I/O operations bypass traditional syscall monitoring entirely, the management syscalls remain visible:

| Syscall | Number | Visibility | Information Captured |
|---------|--------|------------|---------------------|
| `io_uring_setup` | 425 | ✅ Detected | Ring buffer initialization |
| `io_uring_enter` | 426 | ✅ Detected | SQE submission / CQE polling |
| `io_uring_register` | 427 | ✅ Detected | File descriptor / buffer registration |
| `IORING_OP_READ` | — | ❌ Not detected | Actual read operation |
| `IORING_OP_WRITE` | — | ❌ Not detected | Actual write operation |
| `IORING_OP_CONNECT` | — | ❌ Not detected | Actual network connection |

This creates a **semantic gap**: defenders can detect *that* io_uring is being used but cannot determine *what* operations are being performed. The `iouring_setup` key provides behavioral detection—a process initializing io_uring may warrant additional scrutiny—but does not restore operational visibility.

## Why `file_test_path`?

The `-w /tmp/edr_test -p rwxa` rule provides **path-specific monitoring** as a secondary detection mechanism. This watch rule:

- Monitors a specific directory rather than all file syscalls system-wide
- Captures read (r), write (w), execute (x), and attribute changes (a)
- Provides file path visibility regardless of which syscall variant is used

However, this rule still **does not detect io_uring operations** because io_uring bypasses the audit hooks entirely, not just the syscall-specific rules.

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

Rocky Linux 9 / RHEL 9 may not recognize certain syscall names. The provided rules use numeric syscall identifiers where necessary. If you encounter this error for a new syscall:

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

### Verify io_uring rules specifically

```bash
# Check io_uring rules are loaded
sudo auditctl -l | grep iouring

# Test io_uring detection
./bin/file_io_uring
sudo ausearch -k iouring_setup -ts recent
```

### High audit log volume

If audit logs grow too large, consider adding filters:

```bash
# Exclude specific users
-a always,exit -F arch=b64 -S openat -F auid!=1000 -k file_baseline

# Exclude specific paths
-a always,exit -F arch=b64 -S openat -F path!=/var/log -k file_baseline
```

## Removing Rules

To clear all audit rules (useful for debugging):

```bash
sudo auditctl -D
```

To reload after clearing:

```bash
sudo auditctl -R environment/99-edr-baseline.rules
```
