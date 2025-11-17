# FPGA TPU Testing Guide

Complete guide for testing the TPU on Basys3 FPGA hardware.

---

## Prerequisites

### Hardware
- ✅ Basys3 FPGA board (Artix-7)
- ✅ USB cable (Micro-USB for programming + power)
- ✅ Programmed with `tpu_top_with_io_complete.bit`

### Software
- ✅ Python 3.7+
- ✅ PySerial library (`pip install pyserial`)
- ✅ NumPy library (`pip install numpy`)

---

## Quick Start

### 1. Program FPGA

In Vivado:
```tcl
open_hw_manager
connect_hw_server
open_hw_target
current_hw_device [get_hw_devices xc7a35t_0]
set_property PROGRAM.FILE {path/to/tpu_top_with_io_complete.bit} [get_hw_devices xc7a35t_0]
program_hw_devices [get_hw_devices xc7a35t_0]
```

### 2. Find Serial Port

**Linux:**
```bash
ls /dev/tty* | grep -E "USB|ACM"
# Common: /dev/ttyUSB0, /dev/ttyACM0
```

**macOS:**
```bash
ls /dev/cu.* | grep -i usb
# Common: /dev/cu.usbserial-XXXXXXXX
# Example: /dev/cu.usbserial-210183BE12810
```

**Windows:**
- Open Device Manager
- Look under "Ports (COM & LPT)"
- Find "USB Serial Port (COMx)"

### 3. Run Tests

**Auto-detect port (recommended):**
```bash
cd tests/integration
./run_fpga_tests.sh
```

**Or specify port manually:**
```bash
# Linux
./run_fpga_tests.sh --port /dev/ttyUSB0

# macOS
./run_fpga_tests.sh --port /dev/cu.usbserial-210183BE12810

# Windows
./run_fpga_tests.sh --port COM3
```

**Quick test:**
```bash
./run_fpga_tests.sh --quick
```

---

## Python API Usage

### Basic Example

```python
from tpu_fpga_interface import FPGA_TPU
import numpy as np

# Connect to FPGA (auto-detect or specify port)
tpu = FPGA_TPU()  # Auto-detect
# tpu = FPGA_TPU(port='/dev/ttyUSB0')  # Linux
# tpu = FPGA_TPU(port='/dev/cu.usbserial-210183BE12810')  # macOS
if not tpu.connect():
    print("Connection failed")
    exit(1)

# Create test matrices
A = np.random.randn(8, 8).astype(np.float32)
B = np.random.randn(8, 8).astype(np.float32)

# Perform matrix multiplication
result = tpu.matrix_multiply(A, B)

if result is not None:
    print("Result:")
    print(result)
    
    # Verify accuracy
    expected = A @ B
    error = np.max(np.abs(result - expected))
    print(f"Max error: {error:.6f}")

tpu.disconnect()
```

### Context Manager

```python
# Auto-detect port
with FPGA_TPU() as tpu:
    # Or specify: FPGA_TPU(port='/dev/cu.usbserial-210183BE12810')
    A = np.ones((8, 8), dtype=np.float32)
    B = np.ones((8, 8), dtype=np.float32) * 2.0
    result = tpu.matrix_multiply(A, B)
```

### Performance Monitoring

```python
tpu = FPGA_TPU()
tpu.connect()

# Run multiple operations
for i in range(100):
    A = np.random.randn(8, 8).astype(np.float32)
    B = np.random.randn(8, 8).astype(np.float32)
    result = tpu.matrix_multiply(A, B, verbose=False)

# Get statistics
stats = tpu.get_performance_stats()
print(f"Average time: {stats['avg_time']*1000:.2f} ms")
print(f"Throughput: {stats['throughput_gops']:.4f} GOPS")

tpu.disconnect()
```

---

## Test Suite Details

### Test 1: FP16 Conversion
- Tests FP32 ↔ FP16 conversion
- Validates special values (zero, infinity, NaN)
- No hardware required

### Test 2: Basic Matrix Multiplication
- Identity matrix
- Zero matrix
- Ones matrix
- Simple multiplication

### Test 3: Edge Cases
- Very small values (0.001)
- Large values (10.0)
- Mixed signs (positive/negative)
- Diagonal matrices

### Test 4: Random Matrices (20 iterations)
- Random values from normal distribution
- Validates approximate computing accuracy
- Measures error statistics

### Test 5: Accuracy Analysis (50 iterations)
- Absolute error statistics
- Relative error statistics
- Accuracy grading

### Test 6: Performance Benchmark (100 iterations)
- Mean/median/min/max timing
- Throughput in GOPS
- Efficiency vs theoretical peak
- CPU comparison

---

## Expected Results

### Timing
| Metric | Typical Value | Notes |
|--------|---------------|-------|
| Single matmul | 0.1 - 0.5 ms | Includes UART overhead |
| Computation only | 80 - 100 μs | 8-10 cycles @ 100 MHz |
| Throughput | 1-5 GOPS | Limited by UART bandwidth |

### Accuracy (Approximate Computing)
| Metric | Typical Value | Acceptable Range |
|--------|---------------|------------------|
| Mean absolute error | 0.01 - 0.1 | < 1.0 |
| Max absolute error | 0.1 - 0.5 | < 2.0 |
| Mean relative error | 0.5% - 2% | < 10% |

### Theoretical Peak Performance
```
Clock: 100 MHz
MACs per cycle: 64 (8×8 array)
Peak throughput: 6.4 GOPS

Actual throughput limited by:
- UART bandwidth (115200 baud ≈ 14 KB/s)
- Protocol overhead
- FP16 conversion
```

---

## Protocol Details

### UART Configuration
- **Baud rate:** 115200
- **Data bits:** 8
- **Parity:** None
- **Stop bits:** 1

### Commands

| Command | Code | Data | Response |
|---------|------|------|----------|
| WRITE_MATRIX_A | 0x01 | 128 bytes (64 FP16) | ACK (0xAA) |
| WRITE_MATRIX_B | 0x02 | 128 bytes (64 FP16) | ACK (0xAA) |
| READ_RESULT | 0x03 | - | ACK + 128 bytes |
| START_COMPUTE | 0x04 | - | ACK (0xAA) |
| GET_STATUS | 0x05 | - | ACK + 4 bytes |
| RESET | 0x06 | - | ACK (0xAA) |

### Status Byte Format
```
Bit 0: Busy flag
Bit 1: Done flag
Bit 2: Error flag
Bits 3-7: Reserved
```

### Data Format
- **FP16:** Little-endian, 2 bytes per value
- **Matrix layout:** Row-major order
- **Index mapping:** `matrix[i][j]` → byte offset `(i*8 + j)*2`

---

## Troubleshooting

### Connection Issues

**Problem:** "No serial ports found"
- **Solution:** Check USB cable, try different port
- **Linux:** Add user to `dialout` group: `sudo usermod -a -G dialout $USER`

**Problem:** "Permission denied" (Linux)
- **Solution:** 
  ```bash
  sudo chmod 666 /dev/ttyUSB0
  # Or permanently:
  sudo usermod -a -G dialout $USER
  # Then logout and login
  ```

**Problem:** "Port already in use"
- **Solution:** Close other programs using the port (minicom, screen, etc.)

### Communication Issues

**Problem:** Timeout waiting for response
- **Check:** FPGA is programmed and running
- **Check:** Correct baud rate (115200)
- **Try:** Reset FPGA (press center button)
- **Try:** Replug USB cable

**Problem:** Wrong results
- **Check:** Bitstream version matches software
- **Check:** Clock constraints met (timing report)
- **Try:** Lower clock frequency in constraints

### Performance Issues

**Problem:** Slow throughput (<1 GOPS)
- **Normal:** UART is slow (115200 baud)
- **Optimize:** Batch operations
- **Alternative:** Use SPI interface (requires hardware mod)

**Problem:** High error rate
- **Check:** Approximate computing parameters
- **Adjust:** Increase APPROX_MULT_BITS in Verilog
- **Adjust:** Increase APPROX_ALIGN in adder

---

## Advanced Usage

### Custom Test Script

```python
#!/usr/bin/env python3
import sys
sys.path.insert(0, '../../drivers')
from tpu_fpga_interface import FPGA_TPU
import numpy as np

def custom_test():
    with FPGA_TPU() as tpu:
        # Your custom test here
        A = np.array([[...]])  # 8x8
        B = np.array([[...]])  # 8x8
        result = tpu.matrix_multiply(A, B)
        return result

if __name__ == '__main__':
    result = custom_test()
    print(result)
```

### Batch Processing

```python
def batch_multiply(tpu, matrices_a, matrices_b):
    """Multiply multiple matrix pairs"""
    results = []
    for A, B in zip(matrices_a, matrices_b):
        result = tpu.matrix_multiply(A, B, verbose=False)
        if result is not None:
            results.append(result)
    return results
```

### Error Analysis

```python
def analyze_error(tpu, A, B):
    """Detailed error analysis"""
    result = tpu.matrix_multiply(A, B)
    expected = A @ B
    
    abs_error = np.abs(result - expected)
    rel_error = abs_error / (np.abs(expected) + 1e-8)
    
    print(f"Max absolute error: {np.max(abs_error):.6f}")
    print(f"Mean absolute error: {np.mean(abs_error):.6f}")
    print(f"Max relative error: {np.max(rel_error)*100:.2f}%")
    print(f"Mean relative error: {np.mean(rel_error)*100:.2f}%")
    
    return abs_error, rel_error
```

---

## Performance Optimization

### FPGA Side
1. **Increase clock frequency** (if timing permits)
2. **Optimize UART module** (wider data path)
3. **Add DMA for memory** (reduce FSM overhead)
4. **Pipeline depth** (trade latency for throughput)

### Software Side
1. **Batch operations** (amortize setup cost)
2. **Async I/O** (overlap communication)
3. **Binary protocol** (reduce encoding overhead)
4. **Pre-convert to FP16** (reduce CPU load)

### Alternative Interfaces
- **SPI:** 10-50x faster than UART
- **Ethernet:** For high-bandwidth applications
- **PCIe:** Maximum throughput (FPGA add-on cards)

---

## Validation Checklist

Before running tests:
- [ ] FPGA programmed with latest bitstream
- [ ] Timing constraints met (check timing report)
- [ ] UART baud rate = 115200
- [ ] Python packages installed (pyserial, numpy)
- [ ] Serial port identified
- [ ] Port permissions granted (Linux)

After tests:
- [ ] All basic tests pass
- [ ] Error within tolerance (<1.0)
- [ ] Throughput reasonable (>1 GOPS)
- [ ] No communication timeouts
- [ ] Performance stats saved

---

## Next Steps

### After Successful Testing
1. **Characterize accuracy** vs approximate parameters
2. **Profile performance** at different clock speeds
3. **Test power consumption** (if available)
4. **Integrate into application** (ML inference, DSP, etc.)

### Improvements
1. **Add SPI interface** for faster communication
2. **Implement streaming mode** for continuous operation
3. **Add on-chip memory** to reduce PCIe overhead
4. **Support larger matrices** (tiling algorithm)

---

## References

- Verilog source: `hardware/verilog/tpu_top_with_io_complete.v`
- Constraints: `hardware/constraints/basys3_simplified.xdc`
- Driver code: `drivers/tpu_fpga_interface.py`
- Test suite: `tests/integration/test_fpga_tpu_complete.py`

---

## Support

For issues or questions:
1. Check this guide thoroughly
2. Review test output messages
3. Check Vivado timing/synthesis reports
4. Verify hardware connections
5. Review protocol implementation

**Common Success Rate:** 95%+ of tests should pass for properly configured system.
