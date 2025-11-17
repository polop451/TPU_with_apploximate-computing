#!/bin/bash
# Run FPGA TPU Tests

echo "======================================================================"
echo "FPGA TPU Test Runner"
echo "======================================================================"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 not found"
    exit 1
fi

# Check dependencies
echo "Checking dependencies..."
python3 -c "import serial, numpy" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Installing required packages..."
    pip3 install pyserial numpy
fi

# Find script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEST_SCRIPT="$SCRIPT_DIR/test_fpga_tpu_complete.py"

# Parse arguments
PORT=""
QUICK=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --quick)
            QUICK="--quick"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --port PORT    Specify serial port (e.g., /dev/ttyUSB0, COM3)"
            echo "  --quick        Run quick tests only"
            echo "  --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run tests
echo ""
echo "Starting tests..."
echo ""

if [ -n "$PORT" ]; then
    python3 "$TEST_SCRIPT" --port "$PORT" $QUICK
else
    python3 "$TEST_SCRIPT" $QUICK
fi

EXIT_CODE=$?

echo ""
echo "======================================================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo "Tests completed successfully"
else
    echo "Tests failed with exit code $EXIT_CODE"
fi
echo "======================================================================"

exit $EXIT_CODE
