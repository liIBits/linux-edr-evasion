# traditional/

C source code for traditional syscall-based PoC binaries.

## Files

| Source | Binary | Syscalls Used |
|--------|--------|---------------|
| `file_io_trad.c` | `bin/file_io_trad` | open, write, close |
| `read_file_trad.c` | `bin/read_file_trad` | open, read, close |
| `net_connect_trad.c` | `bin/net_connect_trad` | socket, connect |
| `exec_cmd_trad.c` | `bin/exec_cmd_trad` | execve |

## Building

```bash
# From repo root
make all

# Or individually
gcc -o bin/file_io_trad traditional/file_io_trad.c
```

## What They Do

Each binary performs a minimal operation to trigger audit events:

- **file_io_trad**: Creates `/tmp/test_trad.txt` with test content
- **read_file_trad**: Opens and reads `/etc/passwd`
- **net_connect_trad**: Connects to `1.1.1.1:80` (Cloudflare DNS)
- **exec_cmd_trad**: Runs `/bin/true`

## Expected Behavior

These binaries use standard syscalls that **should be detected** by auditd when the appropriate rules are loaded. They serve as the baseline for comparison against io_uring variants.
