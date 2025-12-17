/*
 * file_io_uring.c - io_uring file I/O (EDR evasion PoC)
 * 
 * This program performs equivalent file read/write operations using
 * io_uring's shared ring buffer mechanism. These operations bypass
 * traditional syscall tracing as they are submitted via the ring
 * buffer rather than individual syscalls.
 *
 * Compile: gcc -o file_io_uring file_io_uring.c -luring
 * Usage:   ./file_io_uring [filepath]
 * Default: /tmp/edr_test_uring.txt
 * 
 * Requires: liburing-dev, kernel >= 5.1
 */

#define _GNU_SOURCE
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <liburing.h>

#define DEFAULT_FILE "/tmp/edr_test_uring.txt"
#define BUFFER_SIZE 64
#define QUEUE_DEPTH 4

int main(int argc, char *argv[]) {
    /* Accept filepath as argument for unique file tagging */
    const char *filepath = (argc > 1) ? argv[1] : DEFAULT_FILE;
    
    struct io_uring ring;
    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;
    const char *data = "EDR test payload - io_uring bypass\n";
    char buf[BUFFER_SIZE] = {0};
    int fd, ret;

    /* Initialize io_uring - this is the only "visible" syscall */
    ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "io_uring_queue_init: %s\n", strerror(-ret));
        return 1;
    }

    /* Open file using traditional syscall (required for fd) */
    fd = open(filepath, O_CREAT | O_RDWR | O_TRUNC | O_DIRECT, 0644);
    if (fd < 0) {
        /* Fallback without O_DIRECT for filesystems that don't support it */
        fd = open(filepath, O_CREAT | O_RDWR | O_TRUNC, 0644);
        if (fd < 0) {
            perror("open");
            io_uring_queue_exit(&ring);
            return 1;
        }
    }

    /* === WRITE via io_uring === */
    /* Get submission queue entry */
    sqe = io_uring_get_sqe(&ring);
    if (!sqe) {
        fprintf(stderr, "Could not get SQE\n");
        close(fd);
        io_uring_queue_exit(&ring);
        return 1;
    }

    /* Prepare write operation - NO write() syscall traced here */
    io_uring_prep_write(sqe, fd, data, strlen(data), 0);
    sqe->user_data = 1; /* Tag for identification */

    /* Submit to kernel via ring buffer */
    ret = io_uring_submit(&ring);
    if (ret < 0) {
        fprintf(stderr, "io_uring_submit (write): %s\n", strerror(-ret));
        close(fd);
        io_uring_queue_exit(&ring);
        return 1;
    }

    /* Wait for completion */
    ret = io_uring_wait_cqe(&ring, &cqe);
    if (ret < 0) {
        fprintf(stderr, "io_uring_wait_cqe: %s\n", strerror(-ret));
        close(fd);
        io_uring_queue_exit(&ring);
        return 1;
    }
    io_uring_cqe_seen(&ring, cqe);

    /* === READ via io_uring === */
    sqe = io_uring_get_sqe(&ring);
    if (!sqe) {
        fprintf(stderr, "Could not get SQE\n");
        close(fd);
        io_uring_queue_exit(&ring);
        return 1;
    }

    /* Prepare read operation - NO read() syscall traced here */
    io_uring_prep_read(sqe, fd, buf, BUFFER_SIZE - 1, 0);
    sqe->user_data = 2;

    ret = io_uring_submit(&ring);
    if (ret < 0) {
        fprintf(stderr, "io_uring_submit (read): %s\n", strerror(-ret));
        close(fd);
        io_uring_queue_exit(&ring);
        return 1;
    }

    ret = io_uring_wait_cqe(&ring, &cqe);
    if (ret < 0) {
        fprintf(stderr, "io_uring_wait_cqe: %s\n", strerror(-ret));
        close(fd);
        io_uring_queue_exit(&ring);
        return 1;
    }
    io_uring_cqe_seen(&ring, cqe);

    /* Cleanup */
    close(fd);
    unlink(filepath);
    io_uring_queue_exit(&ring);

    printf("[URING] File I/O complete on %s: %s", filepath, buf);
    return 0;
}
