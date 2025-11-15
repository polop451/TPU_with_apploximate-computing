# Makefile for TPU Driver
# Supports macOS, Linux, and Windows (MinGW)

# Detect OS
ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
    EXE_EXT := .exe
    RM := del /Q
else
    DETECTED_OS := $(shell uname -s)
    EXE_EXT :=
    RM := rm -f
endif

# Compiler settings
CC := gcc
CXX := g++
CFLAGS := -Wall -O2
CXXFLAGS := -Wall -O2 -std=c++17

# Targets
C_TARGET := tpu_driver$(EXE_EXT)
CPP_TARGET := tpu_driver_cpp$(EXE_EXT)

# Source files
C_SRC := tpu_driver.c
CPP_SRC := tpu_driver.cpp

.PHONY: all c cpp clean help

# Default target
all: c cpp
	@echo "=============================================="
	@echo "✓ Build complete!"
	@echo "=============================================="
	@echo "C driver:   ./$(C_TARGET)"
	@echo "C++ driver: ./$(CPP_TARGET)"
	@echo ""
	@echo "Usage examples:"
	@echo "  macOS:   ./$(C_TARGET) /dev/tty.usbserial-XXX"
	@echo "  Linux:   ./$(C_TARGET) /dev/ttyUSB0"
	@echo "  Windows: $(C_TARGET) COM3"
	@echo "=============================================="

# Build C driver
c: $(C_TARGET)

$(C_TARGET): $(C_SRC)
	@echo "Building C driver..."
	$(CC) $(CFLAGS) -o $@ $<
	@echo "✓ Built $(C_TARGET)"

# Build C++ driver
cpp: $(CPP_TARGET)

$(CPP_TARGET): $(CPP_SRC)
	@echo "Building C++ driver..."
	$(CXX) $(CXXFLAGS) -o $@ $<
	@echo "✓ Built $(CPP_TARGET)"

# Clean
clean:
	@echo "Cleaning..."
	$(RM) $(C_TARGET) $(CPP_TARGET)
	@echo "✓ Clean complete"

# Help
help:
	@echo "TPU Driver Makefile"
	@echo "===================="
	@echo ""
	@echo "Targets:"
	@echo "  all     - Build both C and C++ drivers (default)"
	@echo "  c       - Build C driver only"
	@echo "  cpp     - Build C++ driver only"
	@echo "  clean   - Remove built executables"
	@echo "  help    - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make           # Build everything"
	@echo "  make c         # Build C driver only"
	@echo "  make clean     # Remove executables"
	@echo ""
	@echo "Running the drivers:"
	@echo "  ./$(C_TARGET) /dev/ttyUSB0"
	@echo "  ./$(CPP_TARGET) COM3"
