# io_uring/

C source code for io_uring-based PoC binaries.

## Files

| Source | Binary | io_uring Operations |
|--------|--------|---------------------|
| `file_io_uring.c` | `bin/file_io_uring` | WRITE SQE |
| `openat_uring.c` | `bin/openat_uring` | OPENAT, READ SQE |
| `net_connect_uring.c` | `bin/net_connect_uring` | SOCKET, CONNECT SQE |

**Note:** There is no `exec_cmd_uring` because io_uring does not support execve.

## Building

```bash
# From repo root
make all

# Or individually (requires liburing)
gcc -o bin/file_io_uring io_uring/file_io_uring.c -luring
```

## Dependencies

```bash
# Rocky/RHEL
sudo dnf install liburing-devel

# Ubuntu/Debian
sudo apt install liburing-dev
```

## How io_uring Works

io_uring uses shared memory queues between userspace and kernel:

1. App prepares a Submission Queue Entry (SQE)
2. App calls `io_uring_submit()` → triggers `io_uring_enter` syscall
3. Kernel processes the I/O operation internally
4. Result appears in Completion Queue (CQ)

**Key insight:** The actual I/O (read/write/connect) happens in kernel context *without* a corresponding syscall from userspace. This is why auditd, seccomp, and ptrace miss these operations.

## Expected Behavior

These binaries should produce **low or zero** audit events for file/network operations, demonstrating the detection gap. However, `io_uring_setup` and `io_uring_enter` syscalls are still visible — this is what the `iouring_hits` column captures.
