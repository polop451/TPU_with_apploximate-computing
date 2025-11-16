#!/bin/bash

################################################################################
# Quick Test Script - Fast Tests Only
# Description: Run only quick/important tests (< 10 seconds)
################################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=============================================="
echo "    TPU Quick Test (Fast Tests Only)"
echo "=============================================="
echo ""

PASSED=0
FAILED=0

# Test 1: Integration Test (Python)
echo -e "${BLUE}[1/4]${NC} Integration Tests..."
python3 tests/integration/test_integration.py > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓ PASSED${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗ FAILED${NC}"
    FAILED=$((FAILED + 1))
fi

# Test 2: C Driver Test
echo -e "${BLUE}[2/4]${NC} C Driver Tests..."
gcc -o drivers/test_driver_c tests/drivers/test_driver_c.c -lm 2>/dev/null
if [ $? -eq 0 ]; then
    drivers/test_driver_c > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "  ${RED}✗ FAILED${NC} (compilation)"
    FAILED=$((FAILED + 1))
fi

# Test 3: FP16 Multiplier (Hardware)
echo -e "${BLUE}[3/4]${NC} FP16 Multiplier Test..."
iverilog -g2012 -o hardware/test_mult_sim \
    tests/hardware/test_fp16_multiplier.v \
    hardware/verilog/fp16_approximate_multiplier.v 2>/dev/null

if [ $? -eq 0 ]; then
    vvp hardware/test_mult_sim > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        FAILED=$((FAILED + 1))
    fi
else
    echo -e "  ${RED}✗ FAILED${NC} (compilation)"
    FAILED=$((FAILED + 1))
fi

# Test 4: Build System
echo -e "${BLUE}[4/4]${NC} Build System Test..."
cd drivers
make clean > /dev/null 2>&1
make tpu_driver > /dev/null 2>&1
if [ $? -eq 0 ] && [ -f "tpu_driver" ]; then
    echo -e "  ${GREEN}✓ PASSED${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}✗ FAILED${NC}"
    FAILED=$((FAILED + 1))
fi
cd ..

# Summary
echo ""
echo "=============================================="
echo "Summary:"
echo -e "  ${GREEN}Passed: $PASSED / 4${NC}"
echo -e "  ${RED}Failed: $FAILED / 4${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "  ${GREEN}✓ ALL TESTS PASSED${NC}"
    echo "=============================================="
    exit 0
else
    echo -e "  ${RED}✗ SOME TESTS FAILED${NC}"
    echo "=============================================="
    exit 1
fi
