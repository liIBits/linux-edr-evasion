/*
 * file_io.c - Traditional syscall file I/O
 * 
 * This program performs file read/write operations using standard
 * syscalls (open, read, write, close) that are typically monitored
 * by EDR solutions via auditd/syscall tracing.
 *
 * Compile: gcc -o file_io file_io.c
 * Usage:   ./file_io [filepath]
 * Default: /tmp/edr_test_traditional.txt
 */

#define _GNU_SOURCE
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>

#define DEFAULT_FILE "/tmp/edr_test_traditional.txt"
#define BUFFER_SIZE 64

int main(int argc, char *argv[]) {
    /* Accept filepath as argument for unique file tagging */
    const char *filepath = (argc > 1) ? argv[1] : DEFAULT_FILE;
    const char *data = "EDR test payload - traditional syscall\n";
    char buf[BUFFER_SIZE] = {0};
    int fd;

    /* open() syscall - should be logged by auditd */
    fd = open(filepath, O_CREAT | O_RDWR | O_TRUNC, 0644);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    /* write() syscall - should be logged by auditd */
    if (write(fd, data, strlen(data)) < 0) {
        perror("write");
        close(fd);
        return 1;
    }

    /* lseek() to beginning */
    lseek(fd, 0, SEEK_SET);

    /* read() syscall - should be logged by auditd */
    if (read(fd, buf, BUFFER_SIZE - 1) < 0) {
        perror("read");
        close(fd);
        return 1;
    }

    /* close() syscall */
    close(fd);

    /* unlink() syscall - cleanup */
    unlink(filepath);

    printf("[TRAD] File I/O complete on %s: %s", filepath, buf);
    return 0;
}
