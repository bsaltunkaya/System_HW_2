#!/bin/bash
#==============================================================================
# Master Test Suite for IPC Daemon
# This script runs all tests for the IPC daemon program.
# Author: Claude AI Assistant
# Usage: ./test_suite.sh
#==============================================================================

# Text colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create a log directory
mkdir -p test_logs

echo -e "${BLUE}===== IPC DAEMON COMPREHENSIVE TEST SUITE =====${NC}"
echo "Starting tests at $(date)"
echo "System: $(uname -a)"
echo

#==============================================================================
# Helper Functions
#==============================================================================

# Function to run a test and record its results
run_test() {
    local test_name="$1"
    local test_script="$2"
    
    echo -e "\n${YELLOW}===== TEST: $test_name =====${NC}"
    echo "Running: $test_script"
    
    # Execute the test and capture its output and return code
    local log_file="test_logs/$(echo $test_name | tr ' ' '_').log"
    bash -c "$test_script" &> "$log_file"
    local status=$?
    
    # Print a summary of the results
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓ PASS:${NC} $test_name"
    else
        echo -e "${RED}✗ FAIL:${NC} $test_name (exit code: $status)"
        echo -e "  See log: $log_file"
    fi
    
    return $status
}

# Function to cleanup before/after tests
cleanup() {
    echo "Cleaning up test environment..."
    
    # Kill any remaining ipc_daemon processes
    pkill -f ipc_daemon || true
    
    # Remove FIFOs and log files
    rm -f /tmp/fifo1 /tmp/fifo2
    rm -f /tmp/daemon.log
    
    # Give system time to release resources
    sleep 1
}

#==============================================================================
# Prepare Test Environment
#==============================================================================

# Initial cleanup
cleanup

# Ensure program is compiled with correct flags for Debian
echo "Compiling program with POSIX compatibility..."
gcc -Wall -Wextra -pedantic -std=c99 -D_POSIX_C_SOURCE=200809L -o ipc_daemon ipc_daemon.c
if [ $? -ne 0 ]; then
    echo -e "${RED}Compilation failed. Cannot proceed with tests.${NC}"
    exit 1
fi

# Make all individual test scripts executable
chmod +x test_*.sh

#==============================================================================
# Run All Tests
#==============================================================================

# Track test results
passed=0
failed=0
total=0

# Basic Functionality Tests
run_test "Basic Execution" "./test_basic.sh"
if [ $? -eq 0 ]; then passed=$((passed+1)); else failed=$((failed+1)); fi
total=$((total+1))

# Error Handling Tests
run_test "Error Handling" "./test_errors.sh"
if [ $? -eq 0 ]; then passed=$((passed+1)); else failed=$((failed+1)); fi
total=$((total+1))

# Process & IPC Monitoring Tests
run_test "Process Monitoring" "./test_processes.sh"
if [ $? -eq 0 ]; then passed=$((passed+1)); else failed=$((failed+1)); fi
total=$((total+1))

# Signal Handling Tests
run_test "Signal Handling" "./test_signals.sh"
if [ $? -eq 0 ]; then passed=$((passed+1)); else failed=$((failed+1)); fi
total=$((total+1))

# Memory Leak Tests
run_test "Memory Leak Detection" "./test_memory.sh"
if [ $? -eq 0 ]; then passed=$((passed+1)); else failed=$((failed+1)); fi
total=$((total+1))

# Final cleanup
cleanup

#==============================================================================
# Print Test Summary
#==============================================================================

echo -e "\n${BLUE}===== TEST RESULTS =====${NC}"
echo "Tests passed: $passed / $total"
echo "Tests failed: $failed / $total"

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Check logs for details.${NC}"
    exit 1
fi 