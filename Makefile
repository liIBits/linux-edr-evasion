# Makefile for Linux EDR Evasion Experiment
#
# Usage:
#   make all          - Build all binaries
#   make traditional  - Build only traditional syscall binaries
#   make iouring      - Build only io_uring binaries
#   make experiment   - Run the experiment (default 10 iterations)
#   make experiment N=30  - Run with custom iteration count
#   make clean        - Remove all binaries
#   make help         - Show this help
#

CC = gcc
CFLAGS = -Wall -Wextra -O2
URING_LIBS = -luring

# Directories
TRAD_DIR = traditional
URING_DIR = io_uring
BIN_DIR = bin

# Traditional syscall sources
TRAD_SRCS = $(TRAD_DIR)/file_io.c \
            $(TRAD_DIR)/net_connect.c \
            $(TRAD_DIR)/exec_cmd.c \
            $(TRAD_DIR)/read_file.c

# io_uring sources
URING_SRCS = $(URING_DIR)/file_io_uring.c \
             $(URING_DIR)/net_connect_uring.c \
             $(URING_DIR)/openat_uring.c

# Default iteration count for experiments
N ?= 10

.PHONY: all traditional iouring clean setup experiment test help

# =========================
# Build targets
# =========================

all: setup traditional iouring
	@echo ""
	@echo "Build complete!"
	@echo ""
	@echo "Traditional binaries:"
	@ls -1 $(BIN_DIR)/*_trad 2>/dev/null || echo "  (none)"
	@echo ""
	@echo "io_uring binaries:"
	@ls -1 $(BIN_DIR)/*_uring 2>/dev/null || echo "  (none)"
	@echo ""
	@echo "Next: sudo make experiment N=10"

setup:
	@mkdir -p $(BIN_DIR)

traditional: setup
	$(CC) $(CFLAGS) -o $(BIN_DIR)/file_io_trad $(TRAD_DIR)/file_io.c
	$(CC) $(CFLAGS) -o $(BIN_DIR)/net_connect_trad $(TRAD_DIR)/net_connect.c
	$(CC) $(CFLAGS) -o $(BIN_DIR)/exec_cmd_trad $(TRAD_DIR)/exec_cmd.c
	$(CC) $(CFLAGS) -o $(BIN_DIR)/read_file_trad $(TRAD_DIR)/read_file.c

iouring: setup
	$(CC) $(CFLAGS) -o $(BIN_DIR)/file_io_uring $(URING_DIR)/file_io_uring.c $(URING_LIBS)
	$(CC) $(CFLAGS) -o $(BIN_DIR)/net_connect_uring $(URING_DIR)/net_connect_uring.c $(URING_LIBS)
	$(CC) $(CFLAGS) -o $(BIN_DIR)/openat_uring $(URING_DIR)/openat_uring.c $(URING_LIBS)

clean:
	rm -rf $(BIN_DIR)
	@echo "Cleaned build artifacts"

# =========================
# Experiment targets
# =========================

experiment: all
	@echo ""
	@echo "Running experiment with $(N) iterations..."
	@echo "NOTE: Run with sudo for full auditd access"
	@echo ""
	./scripts/run_tests.sh $(N)

# Alias for experiment
test: experiment

# =========================
# Help
# =========================

help:
	@echo "Linux EDR Evasion Experiment - Makefile"
	@echo ""
	@echo "Build targets:"
	@echo "  make all          - Build all binaries (traditional + io_uring)"
	@echo "  make traditional  - Build only traditional syscall binaries"
	@echo "  make iouring      - Build only io_uring binaries"
	@echo "  make clean        - Remove all compiled binaries"
	@echo ""
	@echo "Experiment targets:"
	@echo "  make experiment      - Run experiment (10 iterations)"
	@echo "  make experiment N=30 - Run experiment (30 iterations)"
	@echo "  make test            - Alias for 'make experiment'"
	@echo ""
	@echo "Examples:"
	@echo "  make all"
	@echo "  sudo make experiment N=30"
	@echo ""
	@echo "Direct script usage:"
	@echo "  sudo ./run_experiment.sh 30"
	@echo "  sudo ./scripts/run_tests.sh 30"
