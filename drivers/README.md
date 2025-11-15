# Software Drivers

Software drivers for communicating with the TPU FPGA via UART interface.

## 📦 Available Drivers

### 1. 🐍 Python Driver (`tpu_driver.py`)
**Best for**: Rapid prototyping, ML integration, data analysis

**Features**:
- NumPy integration for easy matrix operations
- Context manager support (`with` statement)
- Automatic serial port detection
- Built-in FP16 conversion
- Comprehensive error handling

**Requirements**:
```bash
pip install -r requirements.txt
```

**Usage**:
```python
from tpu_driver import TPUDriver
import numpy as np

with TPUDriver('/dev/ttyUSB0') as tpu:
    weights = np.random.randn(8, 8).astype(np.float32)
    activations = np.random.randn(8, 8).astype(np.float32)
    results = tpu.matrix_multiply(weights, activations)
    print(results)
```

---

### 2. ⚡ C Driver (`tpu_driver.c`)
**Best for**: High performance, embedded systems, no dependencies

**Features**:
- Pure C implementation
- No external dependencies
- Cross-platform (Windows/macOS/Linux)
- Small executable size (~35 KB)
- Direct hardware control

**Build**:
```bash
make c
# or
gcc -Wall -O2 -o tpu_driver tpu_driver.c
```

**Usage**:
```c
#include "tpu_driver.c"

int main() {
    TPUDriver* tpu = tpu_init("/dev/ttyUSB0");
    
    float weights[8][8], activations[8][8], results[8][8];
    // Initialize matrices...
    
    tpu_write_weights(tpu, weights);
    tpu_write_activations(tpu, activations);
    tpu_start(tpu);
    tpu_wait_until_done(tpu, 10000);
    tpu_read_results(tpu, results);
    
    tpu_close(tpu);
    return 0;
}
```

---

### 3. 🚀 C++ Driver (`tpu_driver.cpp`)
**Best for**: Large applications, type safety, modern C++ projects

**Features**:
- Modern C++17 features
- RAII design (automatic cleanup)
- Exception-based error handling
- STL container support
- Type-safe API

**Build**:
```bash
make cpp
# or
g++ -std=c++17 -Wall -O2 -o tpu_driver_cpp tpu_driver.cpp
```

**Usage**:
```cpp
#include "tpu_driver.cpp"

int main() {
    try {
        TPUDriver tpu("/dev/ttyUSB0");
        
        TPUDriver::Matrix weights, activations;
        // Initialize matrices...
        
        auto results = tpu.matrixMultiply(weights, activations);
        printMatrix("Results", results);
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    return 0;
}
```

---

## 🔨 Building

### Build All Drivers

```bash
# Using build script (recommended)
./build.sh all

# Using Makefile
make
```

### Build Individual Drivers

```bash
# Python setup
pip install -r requirements.txt

# C driver only
make c

# C++ driver only
make cpp
```

### Clean Build

```bash
make clean
```

## 🚀 Quick Start

### 1. Find Serial Port

**macOS**:
```bash
ls /dev/tty.usb*
# Example: /dev/tty.usbserial-XXXXXXXX
```

**Linux**:
```bash
ls /dev/ttyUSB*
# Example: /dev/ttyUSB0
```

**Windows**:
```
Device Manager → Ports (COM & LPT)
# Example: COM3
```

### 2. Run Demo

```bash
# Python
python3 tpu_driver.py

# C
./tpu_driver /dev/ttyUSB0

# C++
./tpu_driver_cpp /dev/ttyUSB0
```

## 📊 Feature Comparison

| Feature | Python | C | C++ |
|---------|--------|---|-----|
| **Ease of Use** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐☆ |
| **Performance** | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Memory Usage** | ⭐⭐☆☆☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ |
| **Dependencies** | NumPy, pyserial | None | None |
| **Type Safety** | ⭐⭐⭐☆☆ | ⭐⭐☆☆☆ | ⭐⭐⭐⭐⭐ |
| **Error Handling** | Exceptions | Return codes | Exceptions |
| **Executable Size** | N/A | 35 KB | 40 KB |
| **Build Time** | N/A | Fast | Moderate |

## 📡 Communication Protocol

### UART Settings
- **Baud Rate**: 115200
- **Data Format**: 8N1 (8 data bits, no parity, 1 stop bit)
- **Flow Control**: None

### Commands
```
'W' (0x57) + addr + data  →  Write Weight
'A' (0x41) + addr + data  →  Write Activation  
'S' (0x53)                →  Start Computation
'R' (0x52) + addr         →  Read Result
'?' (0x3F)                →  Get Status
```

### Memory Map
```
0x00-0x7F (0-127):     Weight Memory (128 bytes)
0x80-0xFF (128-255):   Activation Memory (128 bytes)
0xC0-0xFF (192-255):   Result Memory (read-only)
```

## 🔧 API Reference

### Common Functions (All Languages)

#### Initialize Connection
```python
# Python
tpu = TPUDriver(port='/dev/ttyUSB0', baudrate=115200)

// C
TPUDriver* tpu = tpu_init("/dev/ttyUSB0");

// C++
TPUDriver tpu("/dev/ttyUSB0");
```

#### Write Data
```python
# Python
tpu.write_weights(weights)        # 8x8 numpy array
tpu.write_activations(activations)

// C
tpu_write_weights(tpu, weights);
tpu_write_activations(tpu, activations);

// C++
tpu.writeWeights(weights);
tpu.writeActivations(activations);
```

#### Compute
```python
# Python
tpu.start()
tpu.wait_until_done(timeout=10.0)

// C
tpu_start(tpu);
tpu_wait_until_done(tpu, 10000);

// C++
tpu.start();
tpu.waitUntilDone(10000);
```

#### Read Results
```python
# Python
results = tpu.read_results()  # Returns 8x8 numpy array

// C
tpu_read_results(tpu, results);

// C++
auto results = tpu.readResults();
```

#### High-Level API
```python
# Python
results = tpu.matrix_multiply(weights, activations)

// C++ only
auto results = tpu.matrixMultiply(weights, activations);
```

## 🛠️ Troubleshooting

### Cannot Open Serial Port

**Linux**:
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER
# Logout and login

# Or temporary fix
sudo chmod 666 /dev/ttyUSB0
```

**macOS**:
```bash
# No permission issues usually
# If issues, try /dev/cu.* instead of /dev/tty.*
```

**Windows**:
- Install FTDI drivers from [ftdichip.com](https://ftdichip.com/drivers/vcp-drivers/)
- Check Device Manager for correct COM port

### No Response from TPU

1. ✅ Check FPGA bitstream is loaded
2. ✅ Verify switches: `SW[15:14] = 01` (UART mode)
3. ✅ Try resetting FPGA (CPU_RESET button)
4. ✅ Check USB cable connection
5. ✅ Verify baud rate (115200)

### Compilation Errors

**C/C++**:
```bash
# macOS
xcode-select --install

# Linux (Ubuntu/Debian)
sudo apt install build-essential

# Windows
# Install MinGW from mingw-w64.org
```

**Python**:
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

## 📚 Documentation

For detailed documentation, see `../docs/`:
- **[DRIVER_GUIDE.md](../docs/DRIVER_GUIDE.md)** - Complete user guide
- **[DRIVER_SUMMARY.md](../docs/DRIVER_SUMMARY.md)** - Quick reference
- **[DRIVERS_README.md](../docs/DRIVERS_README.md)** - Comprehensive overview

## 🔬 Examples

### Example 1: Simple Matrix Multiplication (Python)
```python
from tpu_driver import TPUDriver
import numpy as np

with TPUDriver('/dev/ttyUSB0') as tpu:
    # Create test matrices
    weights = np.eye(8, dtype=np.float32)  # Identity matrix
    activations = np.ones((8, 8), dtype=np.float32)
    
    # Compute
    results = tpu.matrix_multiply(weights, activations)
    
    # Should return ones matrix
    assert np.allclose(results, activations, atol=0.1)
    print("✓ Test passed!")
```

### Example 2: Batch Processing (C)
```c
void process_batch(float batch[][8][8], int count) {
    TPUDriver* tpu = tpu_init("/dev/ttyUSB0");
    float weights[8][8] = {{1.0}};  // Initialize weights
    
    for (int i = 0; i < count; i++) {
        float results[8][8];
        tpu_write_weights(tpu, weights);
        tpu_write_activations(tpu, batch[i]);
        tpu_start(tpu);
        tpu_wait_until_done(tpu, 10000);
        tpu_read_results(tpu, results);
        // Process results...
    }
    
    tpu_close(tpu);
}
```

### Example 3: Error Handling (C++)
```cpp
try {
    TPUDriver tpu("/dev/ttyUSB0");
    
    TPUDriver::Matrix weights, activations;
    // Initialize...
    
    auto results = tpu.matrixMultiply(weights, activations);
    
} catch (const std::runtime_error& e) {
    std::cerr << "Runtime error: " << e.what() << std::endl;
} catch (const std::invalid_argument& e) {
    std::cerr << "Invalid argument: " << e.what() << std::endl;
} catch (const std::exception& e) {
    std::cerr << "Unknown error: " << e.what() << std::endl;
}
```

## 📈 Performance

### Communication Speed (UART @ 115200 baud)
- Write weights (64 FP16): ~11 ms
- Write activations (64 FP16): ~11 ms
- TPU compute: <1 ms
- Read results (64 FP16): ~11 ms
- **Total per inference**: ~34 ms

### Optimization Tips
1. Use SPI interface for 200× faster I/O (25 MHz)
2. Batch multiple operations
3. Use C/C++ for lower overhead
4. Minimize serial port operations

## 🚀 Next Steps

1. **Choose your driver** based on your needs
2. **Build the driver** using Makefile or build script
3. **Connect Basys3** via USB
4. **Run the demo** to verify everything works
5. **Integrate** into your project

---

For hardware design, see `../hardware/`  
For documentation, see `../docs/`
