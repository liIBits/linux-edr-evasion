# Makefile for EDR Evasion PoC - Traditional vs io_uring
#
# Usage:
#   make all        - Build everything
#   make traditional - Build only traditional syscall binaries
#   make iouring    - Build only io_uring binaries
#   make clean      - Remove all binaries

CC = gcc
CFLAGS = -Wall -Wextra -O2
URING_LIBS = -luring

# Output directories
TRAD_DIR = traditional
URING_DIR = io_uring
BIN_DIR = bin

# Traditional syscall binaries
TRAD_SRCS = $(TRAD_DIR)/file_io.c \
            $(TRAD_DIR)/net_connect.c \
            $(TRAD_DIR)/exec_cmd.c \
            $(TRAD_DIR)/read_file.c

TRAD_BINS = $(BIN_DIR)/file_io_trad \
            $(BIN_DIR)/net_connect_trad \
            $(BIN_DIR)/exec_cmd_trad \
            $(BIN_DIR)/read_file_trad

# io_uring binaries
URING_SRCS = $(URING_DIR)/file_io_uring.c \
             $(URING_DIR)/net_connect_uring.c \
             $(URING_DIR)/openat_uring.c

URING_BINS = $(BIN_DIR)/file_io_uring \
             $(BIN_DIR)/net_connect_uring \
             $(BIN_DIR)/openat_uring

.PHONY: all traditional iouring clean setup

all: setup traditional iouring
	@echo ""
	@echo "Build complete. Binaries in $(BIN_DIR)/"
	@echo ""
	@echo "Traditional syscall binaries:"
	@ls -la $(BIN_DIR)/*_trad 2>/dev/null || echo "  (none built)"
	@echo ""
	@echo "io_uring binaries:"
	@ls -la $(BIN_DIR)/*_uring 2>/dev/null || echo "  (none built)"

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

# Individual targets for debugging
$(BIN_DIR)/file_io_trad: $(TRAD_DIR)/file_io.c | setup
	$(CC) $(CFLAGS) -o $@ $<

$(BIN_DIR)/file_io_uring: $(URING_DIR)/file_io_uring.c | setup
	$(CC) $(CFLAGS) -o $@ $< $(URING_LIBS)
