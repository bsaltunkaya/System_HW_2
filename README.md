# IPC Daemon Communication Protocol

This program demonstrates inter-process communication (IPC) using named pipes (FIFOs) and implements a daemon process to handle background operations.

## Features

- Parent process that creates two child processes and converts to a daemon
- Two child processes that communicate via FIFOs
- Signal handling for SIGCHLD, SIGUSR1, SIGHUP, and SIGTERM
- Zombie process protection
- Timeout mechanism for inactive processes
- Structured error handling with error control block
- Comprehensive logging to a file
- FIFO existence verification

## Requirements

- C compiler (gcc)
- Debian 12 or compatible Linux distribution

## Building

To compile the program, run:

```
gcc -Wall -Wextra -pedantic -std=c99 -D_POSIX_C_SOURCE=200809L -o ipc_daemon ipc_daemon.c
```

This will create the executable `ipc_daemon`.

## Usage

Run the program with two integer arguments:

```
./ipc_daemon <number1> <number2>
```

Example:
```
./ipc_daemon 42 17
```

The program will:
1. Start in the foreground
2. Create two FIFOs (or verify they exist)
3. Fork two child processes
4. Daemonize itself (becoming a background process)
5. The child processes will briefly sleep, then determine the larger number
6. The result will be written to the log file at `/tmp/daemon.log`

## Testing

The project includes several test scripts to verify different aspects of the daemon's functionality:

- `test_basic.sh`: Tests basic functionality and valid inputs
- `test_errors.sh`: Tests error handling in various failure scenarios
- `test_performance.sh`: Tests throughput, latency, CPU and memory usage
- `test_suite.sh`: Runs all tests in sequence

To run all tests:

```
./run_all_tests.sh
```

## Monitoring

You can monitor the daemon's execution by viewing the log file:

```
tail -f /tmp/daemon.log
```

## Error Handling

The program uses a structured error control block for error handling. All errors are:
- Logged to the log file with timestamps
- Include file name and line number information
- Provide detailed error messages
- Include appropriate error codes

## Cleanup

To clean up all generated files, run:

```
rm -f ipc_daemon /tmp/fifo* /tmp/daemon.log
```

## Signal Handling

The daemon responds to the following signals:
- SIGUSR1: Logs signal receipt
- SIGHUP: For reconfiguration (currently just logs receipt)
- SIGTERM: Graceful shutdown and cleanup of FIFOs
- SIGCHLD: Reaps child processes and increments counter

## Timeout Protection

The daemon implements a timeout mechanism to detect and terminate unresponsive child processes after 20 seconds.

## Performance Considerations

The program has been optimized for performance with reduced sleep times and efficient IPC handling. The test scripts can measure:
- Message throughput (messages per second)
- Response latency (milliseconds)
- CPU usage under load
- Memory stability during operation 