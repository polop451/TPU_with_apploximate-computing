# TPU Verilog Design for Basys3 FPGA

## Overview
โปรเจคนี้เป็นการออกแบบ Tensor Processing Unit (TPU) แบบง่ายโดยใช้ Verilog สำหรับบอร์ด Basys3 FPGA มีจุดเด่นคือการใช้ Systolic Array สำหรับการคำนวณ Matrix Multiplication แบบ High-Performance

## สถาปัตยกรรม (Architecture)

### 1. **Systolic Array (4x4)**
- ประกอบด้วย Processing Elements (PE) 16 ตัว จัดเรียงเป็น Grid 4x4
- แต่ละ PE มี MAC (Multiply-Accumulate) Unit
- รองรับ Data Width 8-bit สำหรับ input, 32-bit สำหรับการ accumulate
- Pipeline architecture เพื่อ throughput สูงสุด

### 2. **Memory Controllers**
- Weight Buffer: เก็บ weights สำหรับ neural network
- Activation Buffer: เก็บ activation values
- รองรับ double buffering สำหรับการทำงานอย่างต่อเนื่อง

### 3. **Control Unit**
- State machine ควบคุม data flow
- จัดการ timing สำหรับ systolic array
- รองรับ matrix ขนาดต่างๆ

## ไฟล์ในโปรเจค

```
TPUverilog/
├── mac_unit.v              # Multiply-Accumulate Unit
├── systolic_array.v        # 4x4 Systolic Array
├── memory_controller.v     # Weight & Activation Buffers
├── tpu_controller.v        # Control Unit with State Machine
├── tpu_top.v              # Top-level Module
├── tpu_testbench.v        # Testbench for Simulation
├── basys3_constraints.xdc # Constraints สำหรับ Basys3
└── README.md              # เอกสารนี้
```

## คุณสมบัติเด่น (Features)

### ด้านประสิทธิภาพ:
1. **Pipelining**: ทุก MAC unit ทำงานแบบ pipeline เพื่อ maximize throughput
2. **Parallel Processing**: คำนวณหลาย operations พร้อมกันใน systolic array
3. **Optimized Data Flow**: ลด memory access โดยใช้ systolic architecture
4. **Clock Frequency**: ออกแบบให้ทำงานที่ 100 MHz บน Basys3

### ด้านการออกแบบ:
1. **Modular Design**: แยก modules ชัดเจน ง่ายต่อการ debug และขยาย
2. **Parameterized**: ปรับขนาด array และ data width ได้ง่าย
3. **Resource Efficient**: ใช้ resource บน FPGA อย่างมีประสิทธิภาพ

## Pin Mapping (Basys3)

### Inputs:
- **Clock**: W5 (100 MHz)
- **Reset**: U18 (BTNC - Center Button, Active Low)
- **Start**: T18 (BTNU - Up Button)
- **Load Buttons**: 
  - Load Weight: W19 (BTNL)
  - Load Activation: T17 (BTNR)
- **Matrix Size**: SW[7:0] (Switches)
- **Load Address**: SW[15:8] (Switches)
- **Load Data**: PMOD JA[7:0]

### Outputs:
- **LEDs[15:0]**: Status และ Debug information
  - LED[0]: Busy signal
  - LED[1]: Done signal
  - LED[2]: Array Enable
  - LED[3]: Accumulator Clear
  - LED[15:8]: Cycle Counter
  - LED[7:4]: Matrix Size
- **Result Outputs**: PMOD JB (สำหรับ demo)

## วิธีใช้งาน

### 1. Simulation (iverilog):
```bash
# Compile
iverilog -o tpu_sim tpu_top.v systolic_array.v mac_unit.v memory_controller.v tpu_controller.v tpu_testbench.v

# Run simulation
vvp tpu_sim

# View waveform
gtkwave tpu_tb.vcd
```

### 2. Synthesis (Vivado):
1. สร้าง Project ใหม่ใน Vivado
2. เลือก Basys3 board (xc7a35tcpg236-1)
3. เพิ่มไฟล์ source ทั้งหมด:
   - `mac_unit.v`
   - `systolic_array.v`
   - `memory_controller.v`
   - `tpu_controller.v`
   - `tpu_top.v`
4. เพิ่ม constraints file: `basys3_constraints.xdc`
5. Run Synthesis → Implementation → Generate Bitstream
6. Program FPGA

### 3. การทดสอบบนบอร์ด:
1. กด BTNC (Reset) เพื่อ reset system
2. ตั้งค่า matrix size ด้วย switches SW[7:0]
3. Load weights และ activations ผ่าน PMOD
4. กด BTNU (Start) เพื่อเริ่มคำนวณ
5. ดู status จาก LEDs:
   - LED[0] = 1: กำลังคำนวณ
   - LED[1] = 1: คำนวณเสร็จแล้ว

## ตัวอย่างการคำนวณ

### Matrix Multiplication 2x2:
```
Matrix A = [1 2]    Matrix B = [5 6]
           [3 4]               [7 8]

Result C = A × B = [19 22]
                   [43 50]
```

Testbench มี test cases สำหรับทดสอบการคำนวณพื้นฐาน

## Performance Analysis

### Theoretical Performance:
- **Operations per cycle**: 16 MACs (4x4 array)
- **Clock frequency**: 100 MHz
- **Peak performance**: 1.6 GOPS (Giga Operations Per Second)
- **Latency**: ~(N + 4) cycles สำหรับ N×N matrix

### Resource Utilization (ประมาณการ):
- **Slices**: ~500-800 (ขึ้นกับ optimization)
- **LUTs**: ~2000-3000
- **FFs**: ~1500-2500
- **DSP48E1**: 0 (ใช้ LUT-based multiplication)
- **BRAM**: 0-4 (ถ้าใช้ larger buffers)

## การปรับปรุงเพิ่มเติม (Future Enhancements)

1. **เพิ่มขนาด Array**: ขยายเป็น 8x8 หรือ 16x16
2. **Fixed-Point Arithmetic**: ใช้ fixed-point แทน integer
3. **BRAM Integration**: ใช้ Block RAM สำหรับ larger buffers
4. **UART Interface**: เพิ่ม UART สำหรับ data transfer
5. **Activation Functions**: เพิ่ม ReLU, Sigmoid
6. **Multi-Layer Support**: รองรับหลาย layers

## ข้อควรระวัง

1. **Timing**: ตรวจสอบ timing report หลัง implementation
2. **Reset**: ใช้ asynchronous reset, active low
3. **Clock Domain**: ทุก modules ใช้ clock domain เดียวกัน
4. **Data Loading**: ใน production ควรใช้ UART หรือ AXI interface

## References

- Basys3 Reference Manual
- Xilinx Vivado Design Suite
- Systolic Array Architecture Papers
- Google TPU Architecture

## License
MIT License - Free to use and modify

## Author
Created for TPU Verilog Project on Basys3

---
สร้างโดย GitHub Copilot สำหรับการเรียนรู้และพัฒนา TPU บน FPGA
