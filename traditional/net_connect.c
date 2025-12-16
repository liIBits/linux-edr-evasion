/*
 * net_connect.c - Traditional syscall network connection
 * 
 * This program creates a TCP socket and attempts a connection
 * using standard syscalls (socket, connect, send, recv, close).
 * These are typically monitored by EDR for C2 detection.
 *
 * Compile: gcc -o net_connect net_connect.c
 * Usage:   ./net_connect [ip] [port]
 * Default: connects to 127.0.0.1:8080
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

#define DEFAULT_IP   "127.0.0.1"
#define DEFAULT_PORT 8080
#define BUFFER_SIZE  128

int main(int argc, char *argv[]) {
    const char *ip = (argc > 1) ? argv[1] : DEFAULT_IP;
    int port = (argc > 2) ? atoi(argv[2]) : DEFAULT_PORT;
    
    struct sockaddr_in server_addr;
    char send_buf[] = "GET / HTTP/1.0\r\n\r\n";
    char recv_buf[BUFFER_SIZE] = {0};
    int sockfd, ret;

    /* socket() syscall - should be logged by auditd */
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        perror("socket");
        return 1;
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port);
    
    if (inet_pton(AF_INET, ip, &server_addr.sin_addr) <= 0) {
        perror("inet_pton");
        close(sockfd);
        return 1;
    }

    /* connect() syscall - should be logged by auditd */
    ret = connect(sockfd, (struct sockaddr *)&server_addr, sizeof(server_addr));
    if (ret < 0) {
        /* Connection refused is expected if no server is running */
        printf("[TRAD] connect() to %s:%d - %s (syscall was traced)\n", 
               ip, port, strerror(errno));
        close(sockfd);
        return 0; /* Still success for EDR testing purposes */
    }

    /* send() syscall - should be logged */
    send(sockfd, send_buf, strlen(send_buf), 0);

    /* recv() syscall - should be logged */
    recv(sockfd, recv_buf, BUFFER_SIZE - 1, 0);

    /* close() syscall */
    close(sockfd);

    printf("[TRAD] Network I/O complete to %s:%d\n", ip, port);
    return 0;
}
