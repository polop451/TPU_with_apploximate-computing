#!/bin/bash
# Quick Build Script for TPU Drivers
# Usage: ./build.sh [all|c|cpp|python|clean]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TPU Driver Build Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="Linux"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS="Windows"
else
    OS="Unknown"
fi

print_info "Detected OS: $OS"
echo ""

# Check for compilers
check_gcc() {
    if command -v gcc &> /dev/null; then
        GCC_VERSION=$(gcc --version | head -n1)
        print_success "gcc found: $GCC_VERSION"
        return 0
    else
        print_error "gcc not found"
        return 1
    fi
}

check_gpp() {
    if command -v g++ &> /dev/null; then
        GPP_VERSION=$(g++ --version | head -n1)
        print_success "g++ found: $GPP_VERSION"
        return 0
    else
        print_error "g++ not found"
        return 1
    fi
}

check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        print_success "python3 found: $PYTHON_VERSION"
        return 0
    elif command -v python &> /dev/null; then
        PYTHON_VERSION=$(python --version)
        print_success "python found: $PYTHON_VERSION"
        return 0
    else
        print_error "python not found"
        return 1
    fi
}

# Build functions
build_c() {
    echo ""
    print_info "Building C driver..."
    if check_gcc; then
        gcc -Wall -O2 -o tpu_driver tpu_driver.c
        print_success "C driver built successfully: ./tpu_driver"
    else
        print_error "Cannot build C driver: gcc not found"
        print_info "Install gcc:"
        print_info "  macOS: xcode-select --install"
        print_info "  Linux: sudo apt install build-essential"
        print_info "  Windows: Install MinGW"
        return 1
    fi
}

build_cpp() {
    echo ""
    print_info "Building C++ driver..."
    if check_gpp; then
        g++ -std=c++17 -Wall -O2 -o tpu_driver_cpp tpu_driver.cpp
        print_success "C++ driver built successfully: ./tpu_driver_cpp"
    else
        print_error "Cannot build C++ driver: g++ not found"
        print_info "Install g++:"
        print_info "  macOS: xcode-select --install"
        print_info "  Linux: sudo apt install build-essential"
        print_info "  Windows: Install MinGW"
        return 1
    fi
}

setup_python() {
    echo ""
    print_info "Setting up Python environment..."
    if check_python; then
        # Determine python command
        if command -v python3 &> /dev/null; then
            PYTHON_CMD=python3
            PIP_CMD=pip3
        else
            PYTHON_CMD=python
            PIP_CMD=pip
        fi
        
        # Check if pip is available
        if command -v $PIP_CMD &> /dev/null; then
            print_success "pip found"
            
            # Install requirements
            print_info "Installing Python requirements..."
            $PIP_CMD install -r requirements.txt
            print_success "Python environment ready"
            
            # Test import
            if $PYTHON_CMD -c "import serial; import numpy" 2>/dev/null; then
                print_success "All Python dependencies available"
            else
                print_error "Failed to import dependencies"
                return 1
            fi
        else
            print_error "pip not found"
            print_info "Install pip: $PYTHON_CMD -m ensurepip --upgrade"
            return 1
        fi
    else
        print_error "Cannot setup Python: python not found"
        return 1
    fi
}

clean_build() {
    echo ""
    print_info "Cleaning build artifacts..."
    rm -f tpu_driver tpu_driver.exe tpu_driver_cpp tpu_driver_cpp.exe
    rm -rf __pycache__ *.pyc
    print_success "Clean complete"
}

# Main script
case "${1:-all}" in
    c)
        build_c
        ;;
    cpp)
        build_cpp
        ;;
    python)
        setup_python
        ;;
    clean)
        clean_build
        ;;
    all)
        print_info "Building all drivers..."
        SUCCESS=0
        
        if build_c; then
            ((SUCCESS++))
        fi
        
        if build_cpp; then
            ((SUCCESS++))
        fi
        
        if setup_python; then
            ((SUCCESS++))
        fi
        
        echo ""
        echo -e "${BLUE}========================================${NC}"
        print_success "Build complete! ($SUCCESS/3 drivers ready)"
        echo -e "${BLUE}========================================${NC}"
        echo ""
        echo "Usage examples:"
        if [ -f "tpu_driver" ]; then
            echo "  C:       ./tpu_driver /dev/ttyUSB0"
        fi
        if [ -f "tpu_driver_cpp" ]; then
            echo "  C++:     ./tpu_driver_cpp /dev/ttyUSB0"
        fi
        if command -v python3 &> /dev/null || command -v python &> /dev/null; then
            echo "  Python:  python3 tpu_driver.py"
        fi
        echo ""
        ;;
    help|--help|-h)
        echo "Usage: ./build.sh [OPTION]"
        echo ""
        echo "Options:"
        echo "  all      Build all drivers (default)"
        echo "  c        Build C driver only"
        echo "  cpp      Build C++ driver only"
        echo "  python   Setup Python environment only"
        echo "  clean    Remove build artifacts"
        echo "  help     Show this help message"
        echo ""
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Run './build.sh help' for usage information"
        exit 1
        ;;
esac
