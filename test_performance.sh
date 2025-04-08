#!/bin/bash
#==============================================================================
# Performance Test Script for IPC Daemon
# Tests throughput, response time, and resource usage
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

# Test parameters
NUM_MESSAGES=1000
MESSAGE_SIZE=1024  # bytes
TIMEOUT=60  # seconds

# Performance thresholds
MIN_THROUGHPUT=100  # messages per second
MAX_LATENCY=20      # milliseconds
MAX_CPU_USAGE=50    # percentage

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
    rm -f /tmp/perf_test_*
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

# Check if performance measurement tools are available
if ! command -v bc &> /dev/null; then
    echo -e "${RED}Error: 'bc' command not found. Please install bc for math calculations.${NC}"
    exit 1
fi

if ! command -v time &> /dev/null; then
    echo -e "${YELLOW}Warning: 'time' command not found. CPU usage test will be skipped.${NC}"
fi

echo "==============================================="
echo "      IPC DAEMON PERFORMANCE TESTS           "
echo "==============================================="

# Test 1: Throughput test
echo -e "\n${YELLOW}Test 1: Message throughput${NC}"
total_tests=$((total_tests + 1))

# Start daemon in background
$DAEMON $SERVER_FIFO &
daemon_pid=$!
sleep 0.5

# Create client FIFO if it doesn't exist
if [ ! -e "$CLIENT_FIFO" ]; then
    mkfifo $CLIENT_FIFO
fi

# Create test message
dd if=/dev/zero bs=$MESSAGE_SIZE count=1 2>/dev/null | tr '\0' 'X' > /tmp/perf_test_message

# Start timer
start_time=$(date +%s.%N)

# Send messages in a loop
for ((i=1; i<=$NUM_MESSAGES; i++)); do
    cat /tmp/perf_test_message > $SERVER_FIFO &
    
    # Read response (to avoid blocking)
    timeout 1 cat $CLIENT_FIFO > /dev/null
    
    # Show progress every 100 messages
    if [ $((i % 100)) -eq 0 ]; then
        echo -e "  Sent $i messages..."
    fi
done

# End timer
end_time=$(date +%s.%N)

# Calculate throughput
duration=$(echo "$end_time - $start_time" | bc)
throughput=$(echo "$NUM_MESSAGES / $duration" | bc)

echo -e "  Total time: ${duration} seconds"
echo -e "  Throughput: ${throughput} messages/second"

if (( $(echo "$throughput > $MIN_THROUGHPUT" | bc -l) )); then
    echo -e "${GREEN}Passed: Throughput exceeds minimum threshold of $MIN_THROUGHPUT msg/sec${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}Failed: Throughput below minimum threshold of $MIN_THROUGHPUT msg/sec${NC}"
fi

# Kill daemon
kill $daemon_pid
sleep 0.5

# Test 2: Response latency
echo -e "\n${YELLOW}Test 2: Message response latency${NC}"
total_tests=$((total_tests + 1))

# Start daemon in background
$DAEMON $SERVER_FIFO &
daemon_pid=$!
sleep 0.5

# Create client FIFO if it doesn't exist
if [ ! -e "$CLIENT_FIFO" ]; then
    mkfifo $CLIENT_FIFO
fi

# Measure latency for 100 messages
echo -e "  Measuring latency across 100 messages..."
total_latency=0

for ((i=1; i<=100; i++)); do
    # Start timer
    start_time=$(date +%s.%N)
    
    # Send message
    echo "PING" > $SERVER_FIFO &
    
    # Read response
    timeout 1 cat $CLIENT_FIFO > /dev/null
    
    # End timer
    end_time=$(date +%s.%N)
    
    # Calculate latency in milliseconds
    latency=$(echo "($end_time - $start_time) * 1000" | bc)
    total_latency=$(echo "$total_latency + $latency" | bc)
done

# Calculate average latency
avg_latency=$(echo "scale=2; $total_latency / 100" | bc)
echo -e "  Average response latency: ${avg_latency} ms"

if (( $(echo "$avg_latency < $MAX_LATENCY" | bc -l) )); then
    echo -e "${GREEN}Passed: Average latency below maximum threshold of $MAX_LATENCY ms${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}Failed: Average latency exceeds maximum threshold of $MAX_LATENCY ms${NC}"
fi

# Kill daemon
kill $daemon_pid
sleep 0.5

# Test 3: CPU usage
echo -e "\n${YELLOW}Test 3: CPU usage under load${NC}"
total_tests=$((total_tests + 1))

# Check if we can measure CPU usage
if command -v time &> /dev/null; then
    # Start daemon with time measurement
    /usr/bin/time -f "%P" -o /tmp/perf_test_cpu $DAEMON $SERVER_FIFO &
    daemon_pid=$!
    sleep 0.5
    
    # Create client FIFO if it doesn't exist
    if [ ! -e "$CLIENT_FIFO" ]; then
        mkfifo $CLIENT_FIFO
    fi
    
    # Generate load
    echo -e "  Generating load for CPU measurement..."
    for ((i=1; i<=500; i++)); do
        echo "TEST$i" > $SERVER_FIFO &
        timeout 0.1 cat $CLIENT_FIFO > /dev/null
    done
    
    # Give it time to process
    sleep 1
    
    # Kill daemon
    kill $daemon_pid
    
    # Get CPU usage
    cpu_usage=$(cat /tmp/perf_test_cpu | sed 's/%//')
    echo -e "  CPU usage: ${cpu_usage}%"
    
    if (( $(echo "$cpu_usage < $MAX_CPU_USAGE" | bc -l) )); then
        echo -e "${GREEN}Passed: CPU usage below maximum threshold of $MAX_CPU_USAGE%${NC}"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}Failed: CPU usage exceeds maximum threshold of $MAX_CPU_USAGE%${NC}"
    fi
else
    echo -e "${YELLOW}Skipped: Cannot measure CPU usage without 'time' command${NC}"
    # Adjust total tests
    total_tests=$((total_tests - 1))
fi

# Test 4: Memory usage
echo -e "\n${YELLOW}Test 4: Memory leak check${NC}"
total_tests=$((total_tests + 1))

# Start daemon in background
$DAEMON $SERVER_FIFO &
daemon_pid=$!
sleep 0.5

# Create client FIFO if it doesn't exist
if [ ! -e "$CLIENT_FIFO" ]; then
    mkfifo $CLIENT_FIFO
fi

# Get initial memory usage
if [ -e "/proc/$daemon_pid/status" ]; then
    initial_mem=$(grep VmRSS /proc/$daemon_pid/status | awk '{print $2}')
    echo -e "  Initial memory usage: ${initial_mem} kB"
    
    # Generate load
    echo -e "  Generating load for memory measurement..."
    for ((i=1; i<=1000; i++)); do
        echo "MEMTEST$i" > $SERVER_FIFO &
        timeout 0.1 cat $CLIENT_FIFO > /dev/null
    done
    
    # Wait a moment
    sleep 1
    
    # Get final memory usage
    final_mem=$(grep VmRSS /proc/$daemon_pid/status | awk '{print $2}')
    echo -e "  Final memory usage: ${final_mem} kB"
    
    # Calculate increase percentage
    mem_increase=$(echo "scale=2; (($final_mem - $initial_mem) / $initial_mem) * 100" | bc)
    echo -e "  Memory increase: ${mem_increase}%"
    
    if (( $(echo "$mem_increase < 10" | bc -l) )); then
        echo -e "${GREEN}Passed: Memory usage stable (less than 10% increase)${NC}"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}Failed: Possible memory leak detected (more than 10% increase)${NC}"
    fi
else
    echo -e "${YELLOW}Skipped: Cannot access process memory information${NC}"
    # Adjust total tests
    total_tests=$((total_tests - 1))
fi

# Kill daemon
kill $daemon_pid 2>/dev/null

# Print test results
echo -e "\n==============================================="
echo "         PERFORMANCE TEST RESULTS             "
echo "==============================================="
echo -e "Tests passed: ${tests_passed}/${total_tests}"

if [ $tests_passed -eq $total_tests ]; then
    echo -e "\n${GREEN}ALL PERFORMANCE TESTS PASSED!${NC}"
    exit 0
else
    echo -e "\n${RED}SOME PERFORMANCE TESTS FAILED!${NC}"
    exit 1
fi 