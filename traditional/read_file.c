/*
 * read_file.c - Traditional syscall file read
 * 
 * This program opens and reads a file using standard syscalls
 * (openat, read, close) that are monitored by EDRs via auditd.
 *
 * Compile: gcc -o read_file read_file.c
 * Usage:   ./read_file [file]
 * Default: reads /etc/passwd
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#define DEFAULT_FILE "/etc/passwd"
#define BUFFER_SIZE  256

int main(int argc, char *argv[]) {
    const char *filepath = (argc > 1) ? argv[1] : DEFAULT_FILE;
    char buf[BUFFER_SIZE] = {0};
    int fd;
    ssize_t n;

    /* openat() syscall - should be logged by auditd */
    fd = openat(AT_FDCWD, filepath, O_RDONLY);
    if (fd < 0) {
        perror("openat");
        return 1;
    }
    printf("[TRAD] Opened %s via openat syscall (fd=%d)\n", filepath, fd);

    /* read() syscall - should be logged by auditd */
    n = read(fd, buf, BUFFER_SIZE - 1);
    if (n > 0) {
        printf("[TRAD] Read %zd bytes (first line): %.64s...\n", n, buf);
    }

    /* close() syscall */
    close(fd);

    printf("[TRAD] File operation complete - all syscalls traced\n");
    return 0;
}
