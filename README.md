# 🚀 TPU on Basys3 FPGA# TPU Verilog Design for Basys3 FPGA



**Tensor Processing Unit (TPU)** implementation on Basys3 FPGA with FP16 approximate computing and multiple I/O interfaces.## Overview

โปรเจคนี้เป็นการออกแบบ Tensor Processing Unit (TPU) แบบง่ายโดยใช้ Verilog สำหรับบอร์ด Basys3 FPGA มีจุดเด่นคือการใช้ Systolic Array สำหรับการคำนวณ Matrix Multiplication แบบ High-Performance

## 📁 Project Structure

## สถาปัตยกรรม (Architecture)

```

TPUverilog/### 1. **Systolic Array (4x4)**

├── drivers/              # Software drivers (Python, C, C++)- ประกอบด้วย Processing Elements (PE) 16 ตัว จัดเรียงเป็น Grid 4x4

│   ├── tpu_driver.py     # Python driver with NumPy- แต่ละ PE มี MAC (Multiply-Accumulate) Unit

│   ├── tpu_driver.c      # C driver (pure C)- รองรับ Data Width 8-bit สำหรับ input, 32-bit สำหรับการ accumulate

│   ├── tpu_driver.cpp    # C++ driver (modern C++17)- Pipeline architecture เพื่อ throughput สูงสุด

│   ├── Makefile          # Build automation

│   ├── build.sh          # Quick build script### 2. **Memory Controllers**

│   └── requirements.txt  # Python dependencies- Weight Buffer: เก็บ weights สำหรับ neural network

│- Activation Buffer: เก็บ activation values

├── hardware/             # FPGA hardware design- รองรับ double buffering สำหรับการทำงานอย่างต่อเนื่อง

│   ├── verilog/          # Verilog source files

│   │   ├── tpu_top_with_io.v           # Top-level with I/O### 3. **Control Unit**

│   │   ├── fp16_approx_systolic_array.v # 8x8 systolic array- State machine ควบคุม data flow

│   │   ├── fp16_approx_mac_unit.v      # FP16 MAC unit- จัดการ timing สำหรับ systolic array

│   │   ├── fp16_approximate_multiplier.v # FP16 multiplier- รองรับ matrix ขนาดต่างๆ

│   │   ├── activation_functions.v       # Neural network activations

│   │   ├── uart_interface.v            # UART communication## ไฟล์ในโปรเจค

│   │   ├── io_interfaces.v             # SPI and button interfaces

│   │   └── ...                         # Other Verilog modules```

│   │TPUverilog/

│   └── constraints/      # XDC constraint files├── mac_unit.v              # Multiply-Accumulate Unit

│       ├── basys3_io_constraints.xdc   # Complete I/O pins├── systolic_array.v        # 4x4 Systolic Array

│       └── basys3_constraints.xdc      # Original constraints├── memory_controller.v     # Weight & Activation Buffers

│├── tpu_controller.v        # Control Unit with State Machine

└── docs/                 # Documentation├── tpu_top.v              # Top-level Module

    ├── README.md                     # This file (main overview)├── tpu_testbench.v        # Testbench for Simulation

    ├── DRIVERS_README.md             # Driver documentation├── basys3_constraints.xdc # Constraints สำหรับ Basys3

    ├── DRIVER_GUIDE.md               # Detailed driver guide└── README.md              # เอกสารนี้

    ├── DRIVER_SUMMARY.md             # Quick driver reference```

    ├── IO_INTERFACE_GUIDE.md         # I/O interfaces guide

    ├── FP16_APPROXIMATE.md           # Approximate computing details## คุณสมบัติเด่น (Features)

    ├── ACTIVATION_FUNCTIONS.md       # Activation functions doc

    ├── COMPARISON.md                 # INT8 vs FP16 comparison### ด้านประสิทธิภาพ:

    ├── TEST_RESULTS.md               # Test results1. **Pipelining**: ทุก MAC unit ทำงานแบบ pipeline เพื่อ maximize throughput

    └── DRIVER_FILES.txt              # Driver files summary2. **Parallel Processing**: คำนวณหลาย operations พร้อมกันใน systolic array

```3. **Optimized Data Flow**: ลด memory access โดยใช้ systolic architecture

4. **Clock Frequency**: ออกแบบให้ทำงานที่ 100 MHz บน Basys3

## ✨ Features

### ด้านการออกแบบ:

### Hardware (FPGA)1. **Modular Design**: แยก modules ชัดเจน ง่ายต่อการ debug และขยาย

- 🔢 **8×8 Systolic Array** - 64 MAC units2. **Parameterized**: ปรับขนาด array และ data width ได้ง่าย

- 🧮 **FP16 Approximate Computing** - 60% area savings3. **Resource Efficient**: ใช้ resource บน FPGA อย่างมีประสิทธิภาพ

- ⚡ **6.4 GFLOPS** @ 100 MHz

- 🎯 **7 Activation Functions** - ReLU, Sigmoid, Tanh, etc.## Pin Mapping (Basys3)

- 🔌 **Multiple I/O Interfaces** - UART, SPI, Button/Switch

- 📊 **IEEE 754 FP16** format support### Inputs:

- **Clock**: W5 (100 MHz)

### Software (Drivers)- **Reset**: U18 (BTNC - Center Button, Active Low)

- 🐍 **Python Driver** - Easy to use, NumPy integration- **Start**: T18 (BTNU - Up Button)

- ⚡ **C Driver** - High performance, no dependencies- **Load Buttons**: 

- 🚀 **C++ Driver** - Modern C++17, type-safe  - Load Weight: W19 (BTNL)

- 🔧 **Auto Build** - Makefile + bash script  - Load Activation: T17 (BTNR)

- 📚 **Complete Documentation** - User guides in Thai & English- **Matrix Size**: SW[7:0] (Switches)

- **Load Address**: SW[15:8] (Switches)

## 🚀 Quick Start- **Load Data**: PMOD JA[7:0]



### 1. Hardware Setup (FPGA)### Outputs:

- **LEDs[15:0]**: Status และ Debug information

```bash  - LED[0]: Busy signal

cd hardware/verilog  - LED[1]: Done signal

  - LED[2]: Array Enable

# Option 1: Simulation with Icarus Verilog  - LED[3]: Accumulator Clear

iverilog -g2012 -o sim fp16_approx_systolic_array.v fp16_approx_mac_unit.v fp16_approximate_multiplier.v fp16_approx_tpu_testbench.v  - LED[15:8]: Cycle Counter

vvp sim  - LED[7:4]: Matrix Size

- **Result Outputs**: PMOD JB (สำหรับ demo)

# Option 2: Synthesis with Vivado

# Open Vivado → Create Project → Add all .v files from verilog/## วิธีใช้งาน

# Add constraints from hardware/constraints/basys3_io_constraints.xdc

# Run Synthesis → Implementation → Generate Bitstream### 1. Simulation (iverilog):

``````bash

# Compile

### 2. Driver Setup (Software)iverilog -o tpu_sim tpu_top.v systolic_array.v mac_unit.v memory_controller.v tpu_controller.v tpu_testbench.v



```bash# Run simulation

cd driversvvp tpu_sim



# Build all drivers# View waveform

./build.sh allgtkwave tpu_tb.vcd

```

# Or use Makefile

make### 2. Synthesis (Vivado):

1. สร้าง Project ใหม่ใน Vivado

# Install Python dependencies2. เลือก Basys3 board (xc7a35tcpg236-1)

pip install -r requirements.txt3. เพิ่มไฟล์ source ทั้งหมด:

```   - `mac_unit.v`

   - `systolic_array.v`

### 3. Run Demo   - `memory_controller.v`

   - `tpu_controller.v`

```bash   - `tpu_top.v`

# Python4. เพิ่ม constraints file: `basys3_constraints.xdc`

python3 tpu_driver.py5. Run Synthesis → Implementation → Generate Bitstream

6. Program FPGA

# C

./tpu_driver /dev/ttyUSB0### 3. การทดสอบบนบอร์ด:

1. กด BTNC (Reset) เพื่อ reset system

# C++2. ตั้งค่า matrix size ด้วย switches SW[7:0]

./tpu_driver_cpp /dev/ttyUSB03. Load weights และ activations ผ่าน PMOD

```4. กด BTNU (Start) เพื่อเริ่มคำนวณ

5. ดู status จาก LEDs:

## 📖 Documentation   - LED[0] = 1: กำลังคำนวณ

   - LED[1] = 1: คำนวณเสร็จแล้ว

Comprehensive documentation in `docs/` directory:

## ตัวอย่างการคำนวณ

| Document | Description |

|----------|-------------|### Matrix Multiplication 2x2:

| **[DRIVERS_README.md](docs/DRIVERS_README.md)** | Complete driver overview |```

| **[DRIVER_GUIDE.md](docs/DRIVER_GUIDE.md)** | Detailed usage guide |Matrix A = [1 2]    Matrix B = [5 6]

| **[IO_INTERFACE_GUIDE.md](docs/IO_INTERFACE_GUIDE.md)** | I/O interfaces (UART/SPI/Buttons) |           [3 4]               [7 8]

| **[FP16_APPROXIMATE.md](docs/FP16_APPROXIMATE.md)** | Approximate computing details |

| **[ACTIVATION_FUNCTIONS.md](docs/ACTIVATION_FUNCTIONS.md)** | Neural network activations |Result C = A × B = [19 22]

| **[COMPARISON.md](docs/COMPARISON.md)** | Performance comparison |                   [43 50]

| **[TEST_RESULTS.md](docs/TEST_RESULTS.md)** | Test results and validation |```



## 🔧 Hardware SpecificationsTestbench มี test cases สำหรับทดสอบการคำนวณพื้นฐาน



| Specification | Value |## Performance Analysis

|--------------|-------|

| **Architecture** | Systolic Array |### Theoretical Performance:

| **Array Size** | 8×8 (64 MAC units) |- **Operations per cycle**: 16 MACs (4x4 array)

| **Clock Speed** | 100 MHz |- **Clock frequency**: 100 MHz

| **Peak Performance** | 6.4 GFLOPS |- **Peak performance**: 1.6 GOPS (Giga Operations Per Second)

| **Data Format** | FP16 (IEEE 754) |- **Latency**: ~(N + 4) cycles สำหรับ N×N matrix

| **Approximate Computing** | 60% area savings |

| **FPGA Target** | Basys3 (Artix-7 xc7a35tcpg236-1) |### Resource Utilization (ประมาณการ):

| **Resource Usage** | ~2,100 LUTs, ~1,400 FFs |- **Slices**: ~500-800 (ขึ้นกับ optimization)

- **LUTs**: ~2000-3000

## 🔌 I/O Interfaces- **FFs**: ~1500-2500

- **DSP48E1**: 0 (ใช้ LUT-based multiplication)

### 1. UART (115200 baud)- **BRAM**: 0-4 (ถ้าใช้ larger buffers)

- USB connection to PC

- Commands: Write (W/A), Start (S), Read (R), Status (?)## การปรับปรุงเพิ่มเติม (Future Enhancements)

- Memory map: 0x00-0x7F (weights), 0x80-0xFF (activations), 0xC0-0xFF (results)

1. **เพิ่มขนาด Array**: ขยายเป็น 8x8 หรือ 16x16

### 2. SPI (up to 25 MHz)2. **Fixed-Point Arithmetic**: ใช้ fixed-point แทน integer

- PMOD connector (JA)3. **BRAM Integration**: ใช้ Block RAM สำหรับ larger buffers

- 200× faster than UART4. **UART Interface**: เพิ่ม UART สำหรับ data transfer

- Commands: 0x01 (write), 0x02 (read), 0x03 (start), 0x04 (status)5. **Activation Functions**: เพิ่ม ReLU, Sigmoid

6. **Multi-Layer Support**: รองรับหลาย layers

### 3. Button/Switch (Standalone)

- 5 buttons + 16 switches## ข้อควรระวัง

- 16 LEDs + 4-digit 7-segment display

- No PC required1. **Timing**: ตรวจสอบ timing report หลัง implementation

2. **Reset**: ใช้ asynchronous reset, active low

**Select interface with SW[15:14]:**3. **Clock Domain**: ทุก modules ใช้ clock domain เดียวกัน

- `00` = Button/Switch mode4. **Data Loading**: ใน production ควรใช้ UART หรือ AXI interface

- `01` = UART mode

- `10` = SPI mode## References



## 💻 Driver API Examples- Basys3 Reference Manual

- Xilinx Vivado Design Suite

### Python- Systolic Array Architecture Papers

```python- Google TPU Architecture

from tpu_driver import TPUDriver

import numpy as np## License

MIT License - Free to use and modify

with TPUDriver('/dev/ttyUSB0') as tpu:

    weights = np.random.randn(8, 8).astype(np.float32) * 0.1## Author

    activations = np.random.randn(8, 8).astype(np.float32) * 0.1Created for TPU Verilog Project on Basys3

    results = tpu.matrix_multiply(weights, activations)

    print(results)---

```สร้างโดย GitHub Copilot สำหรับการเรียนรู้และพัฒนา TPU บน FPGA


### C
```c
TPUDriver* tpu = tpu_init("/dev/ttyUSB0");
float weights[8][8], activations[8][8], results[8][8];
// ... initialize matrices
tpu_write_weights(tpu, weights);
tpu_write_activations(tpu, activations);
tpu_start(tpu);
tpu_wait_until_done(tpu, 10000);
tpu_read_results(tpu, results);
tpu_close(tpu);
```

### C++
```cpp
TPUDriver tpu("/dev/ttyUSB0");
TPUDriver::Matrix weights, activations;
// ... initialize matrices
auto results = tpu.matrixMultiply(weights, activations);
```

## 🎯 Use Cases

- 🧠 **Neural Network Inference** - Run small NN layers on FPGA
- 📊 **Matrix Operations** - Hardware-accelerated computation
- 🎓 **Education** - Learn FPGA design and ML hardware
- 🔬 **Research** - Approximate computing experiments
- ⚡ **Edge Computing** - Low-power AI acceleration

## 📊 Performance

| Metric | Value |
|--------|-------|
| **Throughput** | 6.4 GFLOPS |
| **Latency** | ~64 cycles (640 ns @ 100 MHz) |
| **Power** | ~0.5W (estimate) |
| **Area** | 60% smaller than exact FP16 |
| **Accuracy** | <5% typical error (approximate) |

### Communication Speed (UART @ 115200)
- Write weights: ~11 ms
- Write activations: ~11 ms
- Compute: <1 ms
- Read results: ~11 ms
- **Total: ~34 ms per inference**

💡 **Tip**: Use SPI interface for 200× faster I/O!

## 🛠️ Development Tools

### Required
- **Vivado** (2020.1 or later) - FPGA synthesis
- **Icarus Verilog** - Simulation (optional)
- **Python 3.7+** - Driver development
- **GCC/G++** - C/C++ compilation

### Optional
- **GTKWave** - Waveform viewer
- **VS Code** - Code editor
- **Serial Terminal** - Testing UART

## 🔍 Testing

### Simulation Tests
```bash
cd hardware/verilog

# Test systolic array
iverilog -g2012 -o sim fp16_approx_tpu_testbench.v fp16_approx_systolic_array.v fp16_approx_mac_unit.v fp16_approximate_multiplier.v
vvp sim

# Test activation functions
iverilog -g2012 -o act_sim activation_functions.v activation_test.v
vvp act_sim
```

### Driver Tests
```bash
cd drivers

# Test compilation
make clean
make

# Run demos (requires connected Basys3)
python3 tpu_driver.py
./tpu_driver /dev/ttyUSB0
./tpu_driver_cpp /dev/ttyUSB0
```

## 🐛 Troubleshooting

### Hardware Issues
- **Synthesis errors**: Check Vivado version compatibility
- **Timing violations**: Reduce clock speed or optimize
- **Resource overflow**: Enable approximate computing features

### Driver Issues
- **Cannot find port**: Check USB connection and device permissions
- **No response**: Verify bitstream loaded and SW[15:14] = 01
- **Compilation errors**: Install required compilers (gcc/g++)

See [DRIVER_GUIDE.md](docs/DRIVER_GUIDE.md) for detailed troubleshooting.

## 📈 Roadmap

- [x] INT8 TPU implementation
- [x] FP16 approximate computing
- [x] Activation functions
- [x] UART interface
- [x] SPI interface
- [x] Button/Switch interface
- [x] Python/C/C++ drivers
- [ ] DMA support
- [ ] Multi-layer pipeline
- [ ] Quantization tools
- [ ] Python package (pip installable)
- [ ] GUI control application

## 🤝 Contributing

This is an educational project for learning FPGA design and ML hardware acceleration.

## 📝 License

Educational project for Basys3 FPGA development.

## 🙏 Acknowledgments

- **Basys3 Board** - Digilent
- **Artix-7 FPGA** - Xilinx/AMD
- **Systolic Array Architecture** - Google TPU inspiration
- **IEEE 754** - FP16 standard

## 📞 Support

For detailed information, see documentation in `docs/` directory:
- Hardware details: `docs/FP16_APPROXIMATE.md`
- Driver usage: `docs/DRIVER_GUIDE.md`
- I/O interfaces: `docs/IO_INTERFACE_GUIDE.md`

---

**Made with ❤️ for FPGA and ML enthusiasts**

*Last Updated: November 15, 2025*
