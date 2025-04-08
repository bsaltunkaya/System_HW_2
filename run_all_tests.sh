#!/bin/bash
#==============================================================================
# Master Test Script for IPC Daemon
# Runs all test suites and reports overall results
#==============================================================================

# Set colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Make test scripts executable
chmod +x test_errors.sh
chmod +x test_performance.sh

# Track test results
all_passed=true
tests_run=0
tests_passed=0

echo "==============================================="
echo "           IPC DAEMON TEST SUITE              "
echo "==============================================="

# Run error handling tests
echo -e "\n${YELLOW}Running Error Handling Tests...${NC}"
./test_errors.sh
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
./test_performance.sh
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Performance tests PASSED!${NC}"
    tests_passed=$((tests_passed + 1))
else
    echo -e "${RED}Performance tests FAILED!${NC}"
    all_passed=false
fi
tests_run=$((tests_run + 1))

# Print overall results
echo -e "\n==============================================="
echo "           TEST SUITE SUMMARY                  "
echo "==============================================="
echo -e "Test suites passed: ${tests_passed}/${tests_run}"

if [ "$all_passed" = true ]; then
    echo -e "\n${GREEN}ALL TEST SUITES PASSED!${NC}"
    exit 0
else
    echo -e "\n${RED}SOME TEST SUITES FAILED!${NC}"
    exit 1
fi 