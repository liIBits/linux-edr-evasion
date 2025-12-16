/*
 * exec_cmd.c - Traditional syscall process execution
 * 
 * This program forks and executes a command using the execve syscall.
 * Process execution is heavily monitored by EDRs for detecting
 * malicious command execution (T1059).
 *
 * Compile: gcc -o exec_cmd exec_cmd.c
 * Usage:   ./exec_cmd [command]
 * Default: executes /usr/bin/id
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char *argv[]) {
    const char *cmd = (argc > 1) ? argv[1] : "/usr/bin/id";
    pid_t pid;
    int status;

    /* fork() syscall - should be logged by auditd */
    pid = fork();
    
    if (pid < 0) {
        perror("fork");
        return 1;
    }
    
    if (pid == 0) {
        /* Child process */
        char *args[] = {(char *)cmd, NULL};
        char *env[] = {NULL};
        
        /* execve() syscall - heavily monitored by EDRs */
        execve(cmd, args, env);
        
        /* Only reached if execve fails */
        perror("execve");
        _exit(1);
    }
    
    /* Parent waits for child */
    /* wait4/waitpid syscall */
    waitpid(pid, &status, 0);
    
    printf("[TRAD] Executed %s via fork+execve (pid=%d, status=%d)\n", 
           cmd, pid, WEXITSTATUS(status));
    
    return 0;
}
