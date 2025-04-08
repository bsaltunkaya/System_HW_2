#!/bin/bash
#==============================================================================
# Basic Functionality Tests for IPC Daemon
# Tests the core features of the program with valid inputs.
#==============================================================================

# Cleanup function to ensure clean environment
cleanup() {
    # Kill any running test processes
    pkill -f ipc_daemon || true
    # Remove test files
    rm -f /tmp/fifo1 /tmp/fifo2
}

# Ensure clean starting environment
cleanup
echo "" > /tmp/daemon.log

# Print test header
echo "===== BASIC FUNCTIONALITY TESTS ====="
echo "Testing basic execution with different valid inputs"

# Array of test cases: [test_name, arg1, arg2, expected_result]
declare -a test_cases=(
    "Regular positive numbers:40:20:40"
    "Regular number order reversed:20:40:40"
    "Equal numbers:30:30:30"
    "Zero and positive:0:10:10"
    "Negative numbers:-10:-5:-5"
    "Large positive difference:1000:1:-1000"
    "Very large numbers:2147483647:1073741824:2147483647"
)

# Track test results
tests_passed=0
tests_total=0

# Run through all test cases
for test_case in "${test_cases[@]}"; do
    # Parse test case
    IFS=':' read -r test_name arg1 arg2 expected < <(echo "$test_case")
    
    echo -e "\n--- Testing: $test_name ---"
    echo "Input: $arg1 $arg2, Expected larger: $expected"
    
    # Clear log file
    echo "" > /tmp/daemon.log
    
    # Run the program
    ./ipc_daemon "$arg1" "$arg2" &
    program_pid=$!
    
    # Wait for program to complete (max 20 seconds)
    wait_time=0
    while kill -0 $program_pid 2>/dev/null && [ $wait_time -lt 5 ]; do
        sleep 0.5
        wait_time=$((wait_time + 1))
        echo -n "."
    done
    echo ""
    
    # Kill program if it's still running after timeout
    if kill -0 $program_pid 2>/dev/null; then
        echo "Program timed out, killing..."
        kill -9 $program_pid
        test_result="FAIL: Program timed out"
    else
        # Check log file for expected result
        if grep -q "The larger number is $expected" /tmp/daemon.log; then
            test_result="PASS"
            tests_passed=$((tests_passed + 1))
        else
            test_result="FAIL: Didn't find expected result in log"
        fi
    fi
    
    echo "Result: $test_result"
    tests_total=$((tests_total + 1))
    
    # Ensure clean environment for next test
    cleanup
    sleep 0.5
done

# Test general structure behavior
echo -e "\n--- Testing general program structure ---"

# Run with default test values
./ipc_daemon 40 20 &
daemon_pid=$!

# Give it time to initialize
sleep 1

# Check if FIFOs were created properly
if [ -p /tmp/fifo1 ] && [ -p /tmp/fifo2 ]; then
    echo "PASS: FIFOs created successfully"
    tests_passed=$((tests_passed + 1))
else
    echo "FAIL: FIFOs not created properly"
fi
tests_total=$((tests_total + 1))

# Wait for processing to complete
sleep 5

# Check if daemon exits properly
if ! kill -0 $daemon_pid 2>/dev/null; then
    echo "PASS: Daemon exited properly"
    tests_passed=$((tests_passed + 1))
else
    echo "FAIL: Daemon still running after expected completion"
    kill -9 $daemon_pid 2>/dev/null
fi
tests_total=$((tests_total + 1))

# Final cleanup
cleanup

# Report results
echo -e "\n===== BASIC TEST RESULTS ====="
echo "Tests passed: $tests_passed / $tests_total"

# Return success only if all tests passed
if [ $tests_passed -eq $tests_total ]; then
    echo "All basic functionality tests PASSED!"
    exit 0
else
    echo "Some basic functionality tests FAILED!"
    exit 1
fi 