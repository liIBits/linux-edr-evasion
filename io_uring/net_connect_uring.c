/*
 * net_connect_uring.c - io_uring network connection (EDR evasion PoC)
 * 
 * This program performs equivalent network operations using io_uring.
 * The connect, send, and recv operations bypass traditional syscall
 * tracing as they go through the io_uring ring buffer.
 *
 * Compile: gcc -o net_connect_uring net_connect_uring.c -luring
 * Usage:   ./net_connect_uring [ip] [port]
 * Default: connects to 127.0.0.1:8080
 * 
 * Requires: liburing-dev, kernel >= 5.5 (for IORING_OP_CONNECT)
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <liburing.h>

#define DEFAULT_IP   "127.0.0.1"
#define DEFAULT_PORT 8080
#define BUFFER_SIZE  128
#define QUEUE_DEPTH  8

int main(int argc, char *argv[]) {
    const char *ip = (argc > 1) ? argv[1] : DEFAULT_IP;
    int port = (argc > 2) ? atoi(argv[2]) : DEFAULT_PORT;
    
    struct io_uring ring;
    struct io_uring_sqe *sqe;
    struct io_uring_cqe *cqe;
    struct sockaddr_in server_addr;
    char send_buf[] = "GET / HTTP/1.0\r\n\r\n";
    char recv_buf[BUFFER_SIZE] = {0};
    int sockfd, ret;

    /* Initialize io_uring */
    ret = io_uring_queue_init(QUEUE_DEPTH, &ring, 0);
    if (ret < 0) {
        fprintf(stderr, "io_uring_queue_init: %s\n", strerror(-ret));
        return 1;
    }

    /* socket() still needs traditional syscall to get fd */
    sockfd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
    if (sockfd < 0) {
        perror("socket");
        io_uring_queue_exit(&ring);
        return 1;
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port);
    inet_pton(AF_INET, ip, &server_addr.sin_addr);

    /* === CONNECT via io_uring === */
    /* NO connect() syscall will be traced */
    sqe = io_uring_get_sqe(&ring);
    if (!sqe) {
        fprintf(stderr, "Could not get SQE\n");
        close(sockfd);
        io_uring_queue_exit(&ring);
        return 1;
    }

    io_uring_prep_connect(sqe, sockfd, 
                          (struct sockaddr *)&server_addr, 
                          sizeof(server_addr));
    sqe->user_data = 1;

    ret = io_uring_submit(&ring);
    if (ret < 0) {
        fprintf(stderr, "io_uring_submit: %s\n", strerror(-ret));
        close(sockfd);
        io_uring_queue_exit(&ring);
        return 1;
    }

    ret = io_uring_wait_cqe(&ring, &cqe);
    if (ret < 0) {
        fprintf(stderr, "io_uring_wait_cqe: %s\n", strerror(-ret));
        close(sockfd);
        io_uring_queue_exit(&ring);
        return 1;
    }

    if (cqe->res < 0) {
        /* Connection failed - expected if no server running */
        printf("[URING] connect() to %s:%d - %s (via io_uring, NOT traced as syscall)\n",
               ip, port, strerror(-cqe->res));
        io_uring_cqe_seen(&ring, cqe);
        close(sockfd);
        io_uring_queue_exit(&ring);
        return 0; /* Success for EDR testing */
    }
    io_uring_cqe_seen(&ring, cqe);

    /* === SEND via io_uring === */
    sqe = io_uring_get_sqe(&ring);
    io_uring_prep_send(sqe, sockfd, send_buf, strlen(send_buf), 0);
    sqe->user_data = 2;
    io_uring_submit(&ring);
    io_uring_wait_cqe(&ring, &cqe);
    io_uring_cqe_seen(&ring, cqe);

    /* === RECV via io_uring === */
    sqe = io_uring_get_sqe(&ring);
    io_uring_prep_recv(sqe, sockfd, recv_buf, BUFFER_SIZE - 1, 0);
    sqe->user_data = 3;
    io_uring_submit(&ring);
    io_uring_wait_cqe(&ring, &cqe);
    io_uring_cqe_seen(&ring, cqe);

    /* Cleanup */
    close(sockfd);
    io_uring_queue_exit(&ring);

    printf("[URING] Network I/O complete to %s:%d\n", ip, port);
    return 0;
}
