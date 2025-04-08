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
- Optimized performance with minimal processing delays

## Requirements

- C compiler (gcc)
- Debian 12 or compatible Linux distribution
- Basic command-line utilities (bash, bc, time) for running tests

## Building

To compile the program, run:

```
make
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
5. The child processes will briefly sleep (1 second), then determine the larger number
6. The result will be written to the log file at `/tmp/daemon.log`

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
make clean
```

This will remove the executable, FIFOs, and log file.

## Signal Handling

The daemon responds to the following signals:
- SIGUSR1: Logs signal receipt
- SIGHUP: For reconfiguration (currently just logs receipt)
- SIGTERM: Graceful shutdown and cleanup of FIFOs
- SIGCHLD: Reaps child processes and increments counter

## Timeout Protection

The daemon implements a timeout mechanism to detect and terminate unresponsive child processes after 20 seconds.

## Test Suite

The project includes a comprehensive test suite to verify the daemon's functionality, error handling, and performance:

### Running All Tests

To run the complete test suite:

```
./run_all_tests.sh
```

This script will run both error handling and performance tests, providing a comprehensive summary of all test results.

### Individual Test Scripts

The following tests are available:

#### Basic Functionality Tests
```
./test_basic.sh
```
Tests core functionality with various input combinations, verifying FIFO creation and daemon exit behavior.

#### Error Handling Tests
```
./test_errors.sh
```
Verifies the daemon's ability to handle error conditions including:
- Invalid FIFO paths
- Malformed messages
- Buffer overflow attempts
- Multiple client connections

#### Performance Tests
```
./test_performance.sh
```
Measures performance metrics including:
- Message throughput (messages per second)
- Response latency (milliseconds)
- CPU usage under load
- Memory usage stability

### Test Requirements

The performance test suite requires the `bc` utility for calculations and benefits from the `time` command for CPU usage measurements.

## Performance Optimizations

The daemon has been optimized to minimize unnecessary delays:
- Reduced sleep times for faster operation
- Efficient error handling with minimal overhead
- Streamlined process synchronization
- Proper resource cleanup to prevent leaks

## Debugging

For troubleshooting, examine the following files:
- `/tmp/daemon.log`: Main daemon log
- `test_logs/`: Directory containing logs from test runs 