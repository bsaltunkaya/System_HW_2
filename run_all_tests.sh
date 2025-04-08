#!/bin/bash
#==============================================================================
# Master Test Script for IPC Daemon
# Runs all test suites and reports overall results
#==============================================================================

# Set colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Make test scripts executable
chmod +x test_*.sh

# Track test results
all_passed=true
tests_run=0
tests_passed=0

echo "==============================================="
echo "           IPC DAEMON TEST SUITE              "
echo "==============================================="
echo "Running tests at $(date)"
echo "System: $(uname -a)"
echo

# Create test logs directory if it doesn't exist
mkdir -p test_logs

# Run basic functionality tests
echo -e "\n${YELLOW}Running Basic Functionality Tests...${NC}"
./test_basic.sh | tee test_logs/basic_tests.log
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Basic functionality tests PASSED!${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}Basic functionality tests FAILED!${NC}"
    all_passed=false
fi
tests_run=$((tests_run + 1))

# Run error handling tests
echo -e "\n${YELLOW}Running Error Handling Tests...${NC}"
./test_errors.sh | tee test_logs/error_tests.log
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Error handling tests PASSED!${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}Error handling tests FAILED!${NC}"
    all_passed=false
fi
tests_run=$((tests_run + 1))

# Run performance tests
echo -e "\n${YELLOW}Running Performance Tests...${NC}"
./test_performance.sh | tee test_logs/performance_tests.log
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Performance tests PASSED!${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}Performance tests FAILED!${NC}"
    all_passed=false
fi
tests_run=$((tests_run + 1))

# Print overall results
echo -e "\n${BLUE}===============================================${NC}"
echo -e "${BLUE}           TEST SUITE SUMMARY                  ${NC}"
echo -e "${BLUE}===============================================${NC}"
echo -e "Test suites passed: ${tests_passed}/${tests_run}"
echo 
echo -e "Detailed logs are available in the test_logs directory:"
echo -e "  - test_logs/basic_tests.log"
echo -e "  - test_logs/error_tests.log"
echo -e "  - test_logs/performance_tests.log"
echo

if [ "$all_passed" = true ]; then
    echo -e "\n${GREEN}ALL TEST SUITES PASSED!${NC}"
    exit 0
else
    echo -e "\n${RED}SOME TEST SUITES FAILED!${NC}"
    echo -e "Check the log files in test_logs/ directory for details."
    exit 1
fi 