#!/bin/bash
#==============================================================================
# Error Handling Test Script for IPC Daemon
# Tests the daemon's ability to handle various error conditions
#==============================================================================

# Set colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Daemon executable name
DAEMON="./ipc_daemon"

# Client executable name
CLIENT="./ipc_client"

# FIFOs for testing
SERVER_FIFO="/tmp/ipc_server_fifo"
CLIENT_FIFO="/tmp/ipc_client_fifo"

# Test result tracking
tests_passed=0
total_tests=0

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    # Kill any running daemon instances
    pkill -f ipc_daemon || true
    # Remove FIFOs
    rm -f $SERVER_FIFO $CLIENT_FIFO
    rm -f /tmp/test_*
}

# Run this on script exit
trap cleanup EXIT

# Check if executable exists
if [ ! -f "$DAEMON" ]; then
    echo -e "${RED}Error: $DAEMON not found. Please compile the daemon first.${NC}"
    exit 1
fi

if [ ! -f "$CLIENT" ]; then
    echo -e "${RED}Error: $CLIENT not found. Please compile the client first.${NC}"
    exit 1
fi

echo "==============================================="
echo "      IPC DAEMON ERROR HANDLING TESTS         "
echo "==============================================="

# Test 1: Invalid FIFO path
echo -e "\n${YELLOW}Test 1: Invalid FIFO path${NC}"
total_tests=$((total_tests + 1))
output=$($DAEMON "/nonexistent/path/fifo" 2>&1)
if echo "$output" | grep -q "Error"; then
    echo -e "${GREEN}Passed: Daemon correctly detected invalid FIFO path${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}Failed: Daemon did not properly handle invalid FIFO path${NC}"
fi

# Test 2: Sending malformed messages
echo -e "\n${YELLOW}Test 2: Handling malformed messages${NC}"
total_tests=$((total_tests + 1))

# Start daemon in background
$DAEMON $SERVER_FIFO &
daemon_pid=$!
sleep 0.5

# Create client FIFO
mkfifo $CLIENT_FIFO 2>/dev/null

# Send malformed message (binary data)
echo -e "\x01\x02\x03\x04" > $SERVER_FIFO &

# Wait for response
timeout 3 cat $CLIENT_FIFO > /tmp/test_malformed_response

# Check if daemon is still running
if ps -p $daemon_pid > /dev/null; then
    echo -e "${GREEN}Passed: Daemon survived malformed message${NC}"
    tests_passed=$((tests_passed + 1))
    kill $daemon_pid
else
    echo -e "${RED}Failed: Daemon crashed on malformed message${NC}"
fi

# Test 3: Buffer overflow protection
echo -e "\n${YELLOW}Test 3: Buffer overflow protection${NC}"
total_tests=$((total_tests + 1))

# Start daemon in background
$DAEMON $SERVER_FIFO &
daemon_pid=$!
sleep 0.5

# Create very large message (100KB)
dd if=/dev/urandom bs=1024 count=100 2>/dev/null | base64 > /tmp/test_large_msg

# Send large message
cat /tmp/test_large_msg > $SERVER_FIFO &

# Wait a moment
sleep 2

# Check if daemon is still running
if ps -p $daemon_pid > /dev/null; then
    echo -e "${GREEN}Passed: Daemon handled large message without crashing${NC}"
    tests_passed=$((tests_passed + 1))
    kill $daemon_pid
else
    echo -e "${RED}Failed: Daemon crashed when handling large message${NC}"
fi

# Test 4: Multiple client handling
echo -e "\n${YELLOW}Test 4: Error with multiple clients${NC}"
total_tests=$((total_tests + 1))

# Start daemon in background
$DAEMON $SERVER_FIFO &
daemon_pid=$!
sleep 0.5

# Try to start another daemon instance on same FIFO
second_output=$($DAEMON $SERVER_FIFO 2>&1)
if echo "$second_output" | grep -q "Error"; then
    echo -e "${GREEN}Passed: Second daemon instance correctly failed to start${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}Failed: Second daemon instance should not start successfully${NC}"
fi

# Clean up
kill $daemon_pid
sleep 0.5

# Print test results
echo -e "\n==============================================="
echo "           ERROR TEST RESULTS                  "
echo "==============================================="
echo -e "Tests passed: ${tests_passed}/${total_tests}"

if [ $tests_passed -eq $total_tests ]; then
    echo -e "\n${GREEN}ALL ERROR TESTS PASSED!${NC}"
    exit 0
else
    echo -e "\n${RED}SOME ERROR TESTS FAILED!${NC}"
    exit 1
fi 