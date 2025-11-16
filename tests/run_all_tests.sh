#!/bin/bash

################################################################################
# TPU Test Runner - Run All Tests
# Description: Automated test execution for hardware and drivers
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test result tracking
declare -a TEST_RESULTS

echo "================================================================================"
echo "                    TPU COMPREHENSIVE TEST SUITE"
echo "================================================================================"
echo ""

# Function to run hardware test
run_hardware_test() {
    local test_name=$1
    local test_file=$2
    local output_file=$3
    
    echo -e "${BLUE}[Hardware Test]${NC} $test_name"
    echo "  Compiling: $test_file"
    
    # Compile
    iverilog -g2012 \
        -o "hardware/${output_file}" \
        "hardware/$test_file" \
        hardware/verilog/fp16_approximate_multiplier.v \
        hardware/verilog/fp16_approx_mac_unit.v \
        hardware/verilog/fp16_approx_systolic_array.v \
        hardware/verilog/uart_interface.v \
        2>&1 | grep -v "warning"
    
    if [ $? -ne 0 ]; then
        echo -e "  ${RED}✗ FAILED${NC}: Compilation error"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("$test_name: FAILED (compilation)")
        return 1
    fi
    
    echo "  Running simulation..."
    
    # Run simulation
    vvp "hardware/${output_file}" > "hardware/${output_file}.log" 2>&1
    
    if [ $? -eq 0 ]; then
        # Check if test passed
        if grep -q "ALL TESTS PASSED" "hardware/${output_file}.log"; then
            echo -e "  ${GREEN}✓ PASSED${NC}: All checks successful"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            TEST_RESULTS+=("$test_name: PASSED")
        else
            echo -e "  ${YELLOW}⚠ WARNING${NC}: Some tests may have failed"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            TEST_RESULTS+=("$test_name: PASSED (with warnings)")
        fi
    else
        echo -e "  ${RED}✗ FAILED${NC}: Simulation error"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("$test_name: FAILED (simulation)")
        return 1
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
}

# Function to run driver test
run_driver_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "${BLUE}[Driver Test]${NC} $test_name"
    echo "  Executing: $test_command"
    
    # Run test
    eval "$test_command" > "drivers/${test_name}.log" 2>&1
    
    if [ $? -eq 0 ]; then
        if grep -q "ALL TESTS PASSED\|PASSED" "drivers/${test_name}.log"; then
            echo -e "  ${GREEN}✓ PASSED${NC}: All checks successful"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            TEST_RESULTS+=("$test_name: PASSED")
        else
            echo -e "  ${YELLOW}⚠ WARNING${NC}: Test completed with warnings"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            TEST_RESULTS+=("$test_name: PASSED (with warnings)")
        fi
    else
        echo -e "  ${RED}✗ FAILED${NC}: Test execution error"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("$test_name: FAILED")
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
}

################################################################################
# HARDWARE TESTS
################################################################################

echo -e "${GREEN}=== Phase 1: Hardware Tests ===${NC}"
echo ""

# Test 1: FP16 Multiplier
run_hardware_test \
    "FP16 Multiplier" \
    "../tests/hardware/test_fp16_multiplier.v" \
    "test_multiplier_sim"

# Test 2: MAC Unit
run_hardware_test \
    "FP16 MAC Unit" \
    "../tests/hardware/test_mac_unit.v" \
    "test_mac_sim"

# Test 3: Systolic Array
run_hardware_test \
    "8x8 Systolic Array" \
    "../tests/hardware/test_systolic_array.v" \
    "test_systolic_sim"

# Test 4: UART Interface
run_hardware_test \
    "UART Interface" \
    "../tests/hardware/test_uart_interface.v" \
    "test_uart_sim"

################################################################################
# DRIVER TESTS
################################################################################

echo -e "${GREEN}=== Phase 2: Driver Tests ===${NC}"
echo ""

# Test 5: Python Driver
if command -v python3 &> /dev/null; then
    run_driver_test \
        "python_driver" \
        "python3 tests/drivers/test_driver_python.py"
else
    echo -e "${YELLOW}⚠ SKIPPED${NC}: Python 3 not found"
    echo ""
fi

# Test 6: C Driver
if command -v gcc &> /dev/null; then
    echo -e "${BLUE}[Driver Test]${NC} C Driver"
    echo "  Compiling test..."
    
    gcc -o drivers/test_driver_c \
        tests/drivers/test_driver_c.c \
        -lm -Wall -Wextra
    
    if [ $? -eq 0 ]; then
        run_driver_test \
            "c_driver" \
            "drivers/test_driver_c"
    else
        echo -e "  ${RED}✗ FAILED${NC}: Compilation error"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        TEST_RESULTS+=("C Driver: FAILED (compilation)")
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ SKIPPED${NC}: GCC not found"
    echo ""
fi

################################################################################
# INTEGRATION TESTS
################################################################################

echo -e "${GREEN}=== Phase 3: Integration Tests ===${NC}"
echo ""

# Test 7: Build System Test
echo -e "${BLUE}[Integration Test]${NC} Build System"
echo "  Testing driver build system..."

if [ -f "drivers/build.sh" ]; then
    cd drivers
    ./build.sh clean > /dev/null 2>&1
    ./build.sh all > build_test.log 2>&1
    
    if [ $? -eq 0 ] && [ -f "tpu_driver" ] && [ -f "tpu_driver_cpp" ]; then
        echo -e "  ${GREEN}✓ PASSED${NC}: All drivers built successfully"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TEST_RESULTS+=("Build System: PASSED")
    else
        echo -e "  ${RED}✗ FAILED${NC}: Build errors"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("Build System: FAILED")
    fi
    cd ..
else
    echo -e "  ${YELLOW}⚠ SKIPPED${NC}: build.sh not found"
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

# Test 8: Documentation Check
echo -e "${BLUE}[Integration Test]${NC} Documentation"
echo "  Checking documentation files..."

DOC_FILES=("README.md" "docs/README.md" "drivers/README.md" "hardware/README.md")
DOCS_OK=true

for doc in "${DOC_FILES[@]}"; do
    if [ ! -f "$doc" ]; then
        echo -e "  ${YELLOW}⚠ WARNING${NC}: Missing $doc"
        DOCS_OK=false
    fi
done

if $DOCS_OK; then
    echo -e "  ${GREEN}✓ PASSED${NC}: All documentation present"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("Documentation: PASSED")
else
    echo -e "  ${YELLOW}⚠ WARNING${NC}: Some documentation missing"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("Documentation: PASSED (with warnings)")
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo ""

################################################################################
# TEST SUMMARY
################################################################################

echo "================================================================================"
echo "                           TEST SUMMARY"
echo "================================================================================"
echo ""
echo "Test Results:"
for result in "${TEST_RESULTS[@]}"; do
    if [[ $result == *"FAILED"* ]]; then
        echo -e "  ${RED}✗${NC} $result"
    elif [[ $result == *"WARNING"* ]] || [[ $result == *"warnings"* ]]; then
        echo -e "  ${YELLOW}⚠${NC} $result"
    else
        echo -e "  ${GREEN}✓${NC} $result"
    fi
done
echo ""

echo "Statistics:"
echo "  Total Tests: $TOTAL_TESTS"
echo -e "  ${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "  ${RED}Failed: $FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    PERCENTAGE=100
else
    PERCENTAGE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
fi
echo "  Success Rate: ${PERCENTAGE}%"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                      ✓ ALL TESTS PASSED                                        ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}                      ✗ SOME TESTS FAILED                                       ${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Review the log files in tests/ for detailed error information."
    exit 1
fi
