# environment

Configuration files for the target VM and monitoring infrastructure.

## Files

| File | Purpose |
|------|---------|
| `99-edr-baseline.rules` | Linux audit rules for syscall monitoring |
| `setup.md` | VM setup instructions (if present) |

## Audit Rules

The `99-edr-baseline.rules` file defines what syscalls auditd captures:

| Key | Syscalls Monitored |
|-----|-------------------|
| `file_baseline` | open, openat, read, write, close (and vectored variants) |
| `net_baseline` | socket, connect, accept, send*, recv* |
| `exec_baseline` | execve, execveat |
| `iouring_setup` | io_uring_setup, io_uring_enter, io_uring_register |

## Installation

```bash
# Copy to audit rules directory
sudo cp 99-edr-baseline.rules /etc/audit/rules.d/

# Reload rules (temporary)
sudo auditctl -R 99-edr-baseline.rules

# Or restart auditd (persistent)
sudo systemctl restart auditd

# Verify rules loaded
sudo auditctl -l | grep baseline
```

## Why `iouring_setup`?

While io_uring operations bypass traditional syscall monitoring, the *setup* syscalls (`io_uring_setup`, `io_uring_enter`) are still visible. This provides a behavioral indicator that io_uring is being used, even if we can't see what operations it performs.

## Customization

Edit buffer size or failure mode at the top of the rules file:

```
-b 8192           # Audit buffer size
-f 1              # Failure mode: 0=silent, 1=printk, 2=panic
```
