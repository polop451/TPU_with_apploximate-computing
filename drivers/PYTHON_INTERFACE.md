# TPU Python Interface - Quick Reference

## Installation

```bash
pip install pyserial numpy
```

## Basic Usage

```python
from tpu_fpga_interface import FPGA_TPU
import numpy as np

# Auto-connect to FPGA
with FPGA_TPU() as tpu:
    A = np.random.randn(8, 8).astype(np.float32)
    B = np.random.randn(8, 8).astype(np.float32)
    result = tpu.matrix_multiply(A, B)
    print(result)
```

## Files

- **`tpu_fpga_interface.py`** - Main FPGA driver (UART)
- **`demo_tpu_interface.py`** - Demo and offline tests
- Legacy: `tpu_driver.py`, `tpu_driver.c`, `tpu_driver.cpp`

## Testing

```bash
# Demo (no hardware needed)
python3 demo_tpu_interface.py

# Quick test
cd ../tests/integration
./run_fpga_tests.sh --quick

# Full test (auto-detect port)
./run_fpga_tests.sh

# Or specify port manually:
# Linux:   ./run_fpga_tests.sh --port /dev/ttyUSB0
# macOS:   ./run_fpga_tests.sh --port /dev/cu.usbserial-210183BE12810
# Windows: ./run_fpga_tests.sh --port COM3
```

## Documentation

See `../docs/FPGA_TESTING_GUIDE.md` for complete guide.
