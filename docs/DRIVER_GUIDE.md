# TPU Driver User Guide

## Overview
มี Driver 3 ภาษาให้เลือกใช้:
1. **Python** - ง่ายที่สุด, มี NumPy support
2. **C** - เร็ว, portable, ไม่ต้อง runtime
3. **C++** - Modern, type-safe, object-oriented

---

## Python Driver

### Installation

```bash
# Install required packages
pip install -r requirements.txt

# หรือติดตั้งแยก
pip install pyserial numpy
```

### Usage

```python
from tpu_driver import TPUDriver
import numpy as np

# เชื่อมต่อ TPU
tpu = TPUDriver('/dev/ttyUSB0')  # เปลี่ยน port ตามเครื่อง

# สร้าง matrices
weights = np.random.randn(8, 8).astype(np.float32) * 0.1
activations = np.random.randn(8, 8).astype(np.float32) * 0.1

# คำนวณบน TPU
results = tpu.matrix_multiply(weights, activations)

print(f"Results:\n{results}")

# ปิดการเชื่อมต่อ
tpu.disconnect()
```

### Context Manager Support

```python
# แนะนำ: ใช้ with statement เพื่อ auto-close
with TPUDriver('/dev/ttyUSB0') as tpu:
    results = tpu.matrix_multiply(weights, activations)
    print(results)
# เมื่อออกจาก with block จะ disconnect อัตโนมัติ
```

### Advanced Usage

```python
from tpu_driver import TPUDriver, find_serial_ports
import numpy as np

# หา COM ports ที่มี
ports = find_serial_ports()
print(f"Available ports: {ports}")

with TPUDriver(ports[0]) as tpu:
    # เขียน weights ทีละตัว
    for i in range(64):
        tpu.write_fp16(i*2, 0.5)
    
    # เขียน activations
    for i in range(64):
        tpu.write_fp16(128 + i*2, 1.0)
    
    # เริ่มการคำนวณ
    tpu.start()
    
    # ตรวจสอบสถานะ
    status = tpu.get_status()
    print(f"Status: {status}")
    
    # รอให้เสร็จ
    tpu.wait_until_done(timeout=10.0)
    
    # อ่านผลลัพธ์
    results = tpu.read_results()
```

### Run Demo

```bash
# แบบอัตโนมัติ (ใช้ port แรกที่เจอ)
python tpu_driver.py

# หรือระบุ port เอง (แก้ไข code)
# แก้ตรง: port = '/dev/ttyUSB0'  # Your port here
```

---

## C Driver

### Compilation

```bash
# ใช้ Makefile (แนะนำ)
make c

# หรือ compile เอง
gcc -Wall -O2 -o tpu_driver tpu_driver.c

# Windows (MinGW)
gcc -Wall -O2 -o tpu_driver.exe tpu_driver.c
```

### Usage

```bash
# macOS
./tpu_driver /dev/tty.usbserial-XXXXXXXX

# Linux
./tpu_driver /dev/ttyUSB0

# Windows
tpu_driver.exe COM3
```

### C API Example

```c
#include "tpu_driver.c"

int main() {
    // Initialize TPU
    TPUDriver* tpu = tpu_init("/dev/ttyUSB0");
    if (!tpu) {
        fprintf(stderr, "Failed to connect\n");
        return 1;
    }
    
    // Create matrices
    float weights[8][8];
    float activations[8][8];
    float results[8][8];
    
    // Initialize data
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            weights[i][j] = (i + j) * 0.1f;
            activations[i][j] = (i - j) * 0.1f;
        }
    }
    
    // Write to TPU
    tpu_write_weights(tpu, weights);
    tpu_write_activations(tpu, activations);
    
    // Compute
    tpu_start(tpu);
    tpu_wait_until_done(tpu, 10000);  // 10 second timeout
    
    // Read results
    tpu_read_results(tpu, results);
    
    // Print results
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            printf("%7.3f ", results[i][j]);
        }
        printf("\n");
    }
    
    // Cleanup
    tpu_close(tpu);
    return 0;
}
```

### Features
- ✅ Cross-platform (Windows, macOS, Linux)
- ✅ No dependencies
- ✅ FP16 conversion included
- ✅ Simple C API
- ✅ Fast execution

---

## C++ Driver

### Compilation

```bash
# ใช้ Makefile (แนะนำ)
make cpp

# หรือ compile เอง
g++ -std=c++17 -Wall -O2 -o tpu_driver_cpp tpu_driver.cpp

# Windows (MinGW)
g++ -std=c++17 -Wall -O2 -o tpu_driver_cpp.exe tpu_driver.cpp
```

### Usage

```bash
# macOS
./tpu_driver_cpp /dev/tty.usbserial-XXXXXXXX

# Linux
./tpu_driver_cpp /dev/ttyUSB0

# Windows
tpu_driver_cpp.exe COM3
```

### C++ API Example

```cpp
#include "tpu_driver.cpp"

int main() {
    try {
        // Initialize TPU
        TPUDriver tpu("/dev/ttyUSB0");
        
        // Create matrices (using std::array)
        TPUDriver::Matrix weights, activations;
        
        // Initialize data
        for (size_t i = 0; i < 8; i++) {
            for (size_t j = 0; j < 8; j++) {
                weights[i][j] = (i + j) * 0.1f;
                activations[i][j] = (i - j) * 0.1f;
            }
        }
        
        // Perform computation
        auto results = tpu.matrixMultiply(weights, activations);
        
        // Print results
        for (const auto& row : results) {
            for (float val : row) {
                std::cout << std::fixed << std::setprecision(3) 
                         << std::setw(7) << val << " ";
            }
            std::cout << std::endl;
        }
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}
```

### Features
- ✅ Modern C++17
- ✅ RAII design (auto cleanup)
- ✅ Exception handling
- ✅ Type-safe API
- ✅ STL containers
- ✅ Object-oriented

---

## Finding Serial Port

### macOS
```bash
# List all USB serial devices
ls /dev/tty.usb*

# หรือใช้
ls /dev/cu.usb*

# ผลลัพธ์ตัวอย่าง:
# /dev/tty.usbserial-A12345
```

### Linux
```bash
# List all USB serial devices
ls /dev/ttyUSB*

# หรือดูข้อมูลละเอียด
dmesg | grep tty

# ผลลัพธ์ตัวอย่าง:
# /dev/ttyUSB0
```

### Windows
```powershell
# ใน Device Manager
# Ports (COM & LPT) → USB Serial Port (COM3)

# หรือใช้ PowerShell
Get-WmiObject Win32_SerialPort | Select-Object DeviceID,Description

# ผลลัพธ์ตัวอย่าง:
# COM3    USB Serial Port
```

### Python Helper
```python
from tpu_driver import find_serial_ports

ports = find_serial_ports()
for port in ports:
    print(port)
```

---

## Performance Comparison

| Language | Compile Time | Runtime Speed | Memory Usage | Ease of Use |
|----------|--------------|---------------|--------------|-------------|
| Python   | N/A          | ⭐⭐⭐☆☆ (Moderate) | ⭐⭐☆☆☆ (High) | ⭐⭐⭐⭐⭐ (Easy) |
| C        | ⭐⭐⭐⭐☆ (Fast) | ⭐⭐⭐⭐⭐ (Very Fast) | ⭐⭐⭐⭐⭐ (Low) | ⭐⭐⭐☆☆ (Moderate) |
| C++      | ⭐⭐⭐☆☆ (Moderate) | ⭐⭐⭐⭐⭐ (Very Fast) | ⭐⭐⭐⭐☆ (Low) | ⭐⭐⭐⭐☆ (Good) |

### เลือกใช้แบบไหนดี?

**Python** - เหมาะสำหรับ:
- ✅ Prototyping และ testing
- ✅ Data analysis และ visualization
- ✅ Integration กับ ML frameworks (PyTorch, TensorFlow)
- ✅ ผู้ใช้ที่ไม่ชอบ compile

**C** - เหมาะสำหรับ:
- ✅ Embedded systems integration
- ✅ Resource-constrained environments
- ✅ Maximum performance
- ✅ Standalone executables (no dependencies)

**C++** - เหมาะสำหรับ:
- ✅ Large-scale applications
- ✅ Integration กับ C++ codebases
- ✅ Need type safety และ modern features
- ✅ Balance ระหว่าง performance และ ease of use

---

## Troubleshooting

### "Port not found" หรือ "Permission denied"

**Linux:**
```bash
# เพิ่ม user เข้า dialout group
sudo usermod -a -G dialout $USER
# ต้อง logout/login ใหม่

# หรือเปลี่ยน permissions (ชั่วคราว)
sudo chmod 666 /dev/ttyUSB0
```

**macOS:**
```bash
# ไม่มี permission issues โดยปกติ
# แต่ถ้ามี ให้ลองเปลี่ยนเป็น /dev/cu.* แทน /dev/tty.*
```

**Windows:**
```powershell
# ตรวจสอบว่า driver ติดตั้งแล้ว
# Basys3 ใช้ FTDI chip - อาจต้องติดตั้ง FTDI driver
# Download: https://ftdichip.com/drivers/vcp-drivers/
```

### "No data received" หรือ "Timeout"

1. ตรวจสอบ FPGA bitstream โหลดแล้ว
2. ตรวจสอบ switches: `SW[15:14] = 01` (UART mode)
3. ตรวจสอบ baud rate: ต้องเป็น 115200
4. ลอง reset FPGA (ปุ่ม CPU_RESET)
5. ลองถอดแล้วเสียบ USB cable ใหม่

### "Compilation error"

**C:**
```bash
# ต้องมี gcc
gcc --version

# macOS: ติดตั้งด้วย Xcode Command Line Tools
xcode-select --install

# Linux (Ubuntu/Debian):
sudo apt install build-essential

# Windows: ติดตั้ง MinGW
```

**C++:**
```bash
# ต้องมี g++ with C++17 support
g++ --version

# ถ้า compiler เก่าเกินไป ให้อัพเกรด
# หรือเปลี่ยน -std=c++17 เป็น -std=c++14
```

**Python:**
```bash
# NumPy installation failed?
pip install --upgrade pip
pip install numpy --upgrade

# macOS with Apple Silicon (M1/M2):
arch -arm64 pip install numpy
```

---

## Example Workflows

### 1. Quick Test (Python)
```bash
pip install pyserial numpy
python tpu_driver.py
```

### 2. Production C Application
```bash
make c
./tpu_driver /dev/ttyUSB0 > results.txt
```

### 3. C++ Integration
```cpp
// In your main project
#include "tpu_driver.cpp"

void processWithTPU(const std::vector<float>& data) {
    TPUDriver tpu("/dev/ttyUSB0");
    // ... use TPU
}
```

### 4. Batch Processing (Python)
```python
import numpy as np
from tpu_driver import TPUDriver

with TPUDriver('/dev/ttyUSB0') as tpu:
    # Process multiple matrices
    for i in range(100):
        weights = load_weights(f"weights_{i}.npy")
        activations = load_activations(f"activations_{i}.npy")
        results = tpu.matrix_multiply(weights, activations)
        save_results(f"results_{i}.npy", results)
```

---

## API Reference Summary

### Python API
```python
class TPUDriver:
    def __init__(port, baudrate=115200, timeout=1.0)
    def write_byte(addr, data)
    def read_byte(addr) -> int
    def write_fp16(addr, value)
    def read_fp16(addr) -> float
    def write_weights(weights: np.ndarray)
    def write_activations(activations: np.ndarray)
    def start()
    def get_status() -> TPUStatus
    def wait_until_done(timeout=10.0, poll_interval=0.01)
    def read_results() -> np.ndarray
    def matrix_multiply(weights, activations) -> np.ndarray
```

### C API
```c
TPUDriver* tpu_init(const char* port);
void tpu_close(TPUDriver* tpu);
int tpu_write_byte(TPUDriver* tpu, uint8_t addr, uint8_t data);
int tpu_read_byte(TPUDriver* tpu, uint8_t addr, uint8_t* data);
int tpu_write_fp16(TPUDriver* tpu, uint8_t addr, float value);
int tpu_read_fp16(TPUDriver* tpu, uint8_t addr, float* value);
int tpu_write_weights(TPUDriver* tpu, float weights[8][8]);
int tpu_write_activations(TPUDriver* tpu, float activations[8][8]);
int tpu_start(TPUDriver* tpu);
int tpu_get_status(TPUDriver* tpu, TPUStatus* status);
int tpu_wait_until_done(TPUDriver* tpu, int timeout_ms);
int tpu_read_results(TPUDriver* tpu, float results[8][8]);
```

### C++ API
```cpp
class TPUDriver {
    TPUDriver(const std::string& port, int baudrate = 115200);
    void writeByte(uint8_t addr, uint8_t data);
    uint8_t readByte(uint8_t addr);
    void writeFP16(uint8_t addr, float value);
    float readFP16(uint8_t addr);
    void writeWeights(const Matrix& weights);
    void writeActivations(const Matrix& activations);
    void start();
    TPUStatus getStatus();
    void waitUntilDone(int timeout_ms = 10000);
    Matrix readResults();
    Matrix matrixMultiply(const Matrix& weights, const Matrix& activations);
};
```

---

## Next Steps

1. **Test Drivers**: ทดสอบ driver ทั้ง 3 ภาษา
2. **Integration**: นำไปใช้ใน application ของคุณ
3. **Optimization**: ปรับแต่งสำหรับ use case เฉพาะ
4. **Scale Up**: เพิ่ม batch processing หรือ pipelining

Happy coding! 🚀
