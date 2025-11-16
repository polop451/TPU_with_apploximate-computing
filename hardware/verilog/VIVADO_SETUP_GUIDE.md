# Vivado Project Setup Guide for tpu_top_with_io_complete.v

## Required Verilog Files

สำหรับ module `tpu_top_with_io_complete.v` คุณต้องเพิ่มไฟล์ดังนี้เข้า Vivado Project:

### ✅ Core Required Files (11 ไฟล์)

#### 1. Top-Level Module
- **tpu_top_with_io_complete.v** - Main top-level module

#### 2. FP16 Systolic Array (3 ไฟล์)
- **fp16_approx_systolic_array.v** - 8x8 FP16 systolic array
- **fp16_approx_mac_unit.v** - FP16 approximate MAC unit
- **fp16_approximate_multiplier.v** - FP16 multiplier with approximate computing
- **fp16_approximate_adder.v** - FP16 adder with approximate computing

#### 3. UART Interface (3 ไฟล์)
- **uart_interface.v** - Main UART interface with command processor
- **uart_rx.v** - UART receiver module
- **uart_tx.v** - UART transmitter module

#### 4. Optional I/O Modules (สำหรับ SPI และ Button - ถ้าใช้งานภายหลัง)
- **spi_interface.v** - SPI interface (ยังไม่ได้ใช้งานเต็มรูปแบบในโค้ดปัจจุบัน)
- **button_switch_interface.v** - Button/switch interface (มี logic ใน top-level แล้ว)

---

## สรุปไฟล์ที่ต้องการขั้นต่ำ (Minimum Required)

### ไฟล์หลักที่ต้องมี (8 ไฟล์):

```
hardware/verilog/
├── tpu_top_with_io_complete.v          # Top-level module
├── fp16_approx_systolic_array.v        # Systolic array
├── fp16_approx_mac_unit.v              # MAC unit
├── fp16_approximate_multiplier.v       # FP16 multiplier
├── fp16_approximate_adder.v            # FP16 adder
├── uart_interface.v                    # UART main
├── uart_rx.v                           # UART RX
└── uart_tx.v                           # UART TX
```

---

## Vivado Project Setup Steps

### 1. สร้าง Project ใหม่
```
File > Project > New...
- ตั้งชื่อโปรเจกต์
- เลือก RTL Project
- ติ๊ก "Do not specify sources at this time" (จะเพิ่มทีหลัง)
```

### 2. เลือก FPGA Target
```
- สำหรับ Basys3: เลือก xc7a35tcpg236-1
- หรือเลือกตาม FPGA board ของคุณ
```

### 3. เพิ่มไฟล์ Verilog (Add Sources)
```
Sources > Add Sources > Add or create design sources
เพิ่มไฟล์ทั้ง 8 ไฟล์ที่ระบุข้างต้น
```

### 4. เพิ่มไฟล์ Constraints (ถ้ามี)
```
Sources > Add Sources > Add or create constraints
เพิ่มไฟล์ .xdc สำหรับ pin assignments:
- hardware/constraints/basys3_io_constraints.xdc (ถ้าใช้ Basys3)
```

### 5. Set Top Module
```
คลิกขวาที่ tpu_top_with_io_complete
> Set as Top
```

### 6. Run Synthesis
```
Flow Navigator > Synthesis > Run Synthesis
```

---

## Module Dependencies Tree

```
tpu_top_with_io_complete.v (Top)
│
├── fp16_approx_systolic_array.v
│   └── fp16_approx_mac_unit.v (x64 instances - 8x8 array)
│       ├── fp16_approximate_multiplier.v
│       └── fp16_approximate_adder.v
│
└── uart_interface.v
    ├── uart_rx.v
    └── uart_tx.v
```

---

## การตั้งค่า Constraints (XDC File)

สร้างไฟล์ `.xdc` สำหรับกำหนด pins:

### ตัวอย่างสำหรับ Basys3:

```tcl
## Clock
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 [get_ports clk]

## Reset (Button Center)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst_n]

## UART
set_property -dict { PACKAGE_PIN B18  IOSTANDARD LVCMOS33 } [get_ports uart_rx]
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports uart_tx]

## Switches [15:0]
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {switches[0]}]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {switches[1]}]
# ... (เพิ่มต่อสำหรับ switches[2] ถึง [15])

## LEDs [15:0]
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {leds[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {leds[1]}]
# ... (เพิ่มต่อสำหรับ leds[2] ถึง [15])

## Buttons
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports btn_center]
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports btn_up]
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports btn_left]
set_property -dict { PACKAGE_PIN T17  IOSTANDARD LVCMOS33 } [get_ports btn_right]
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports btn_down]

## 7-Segment Display
set_property -dict { PACKAGE_PIN W7   IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
# ... (เพิ่มสำหรับ seg[1] ถึง [6] และ an[0] ถึง [3])
```

---

## Resource Usage (Expected)

### สำหรับ Artix-7 (Basys3):
- **LUTs**: ~12,000 - 15,000 (35% - 45% ของ xc7a35t)
- **FFs**: ~8,000 - 10,000 (23% - 29%)
- **BRAMs**: ~6 - 8 blocks (สำหรับ matrix memories)
- **DSPs**: 0 (ใช้ approximate computing แทน)

### Timing:
- **Target Frequency**: 100 MHz
- **Expected**: สามารถทำงานที่ 80-100 MHz
- **Critical Path**: อยู่ที่ FP16 adder และ multiplier

---

## การทดสอบ (Simulation)

### ไฟล์ Testbench (ถ้าต้องการ simulate ก่อน):
- **fp16_approx_tpu_testbench.v** - Testbench สำหรับทดสอบ

### Run Simulation:
```
Flow Navigator > Simulation > Run Simulation > Run Behavioral Simulation
```

---

## Troubleshooting

### 1. ถ้าเจอ Error: "Module not found"
- ตรวจสอบว่าเพิ่มไฟล์ครบทั้ง 8 ไฟล์
- ตรวจสอบว่าไม่มี syntax errors ในแต่ละไฟล์

### 2. ถ้า Synthesis ใช้เวลานาน
- ปกติสำหรับ design ขนาดนี้: 5-10 นาที
- ถ้านานเกิน 20 นาที อาจมี issue

### 3. ถ้า Timing ไม่ผ่าน (Negative Slack)
- ลด clock frequency ใน constraints
- เพิ่ม pipeline stages (แก้ไขโค้ด)
- ใช้ optimization strategies ที่สูงขึ้น

### 4. Resource Overflow
- ถ้า FPGA เล็กเกินไป อาจต้องลดขนาด systolic array
- ปรับ SIZE parameter จาก 8x8 เป็น 4x4

---

## Interface Modes

Module นี้รองรับ 3 โหมด (เลือกด้วย switches[15:14]):

1. **Button/Switch Mode (00)**: ควบคุมด้วยปุ่มและสวิตช์บนบอร์ด
2. **UART Mode (01)**: ควบคุมผ่าน serial port (115200 baud)
3. **SPI Mode (10)**: สำหรับการใช้งานภายหลัง (ยังไม่ implement เต็ม)

---

## คำแนะนำเพิ่มเติม

### สำหรับการใช้งานครั้งแรก:
1. เริ่มจาก Button/Switch Mode (ง่ายที่สุด)
2. ทดสอบด้วย UART Mode (ยืดหยุ่นกว่า)
3. เพิ่ม SPI Mode ภายหลัง (เร็วที่สุด)

### Recommended Settings:
- **Synthesis Strategy**: Flow_PerfOptimized_high
- **Implementation Strategy**: Performance_ExplorePostRoutePhysOpt
- **Enable Bitstream Compression**: ✓

---

## Quick Start Checklist

- [ ] เพิ่มไฟล์ทั้ง 8 ไฟล์เข้า Vivado
- [ ] เพิ่มไฟล์ .xdc (constraints)
- [ ] Set tpu_top_with_io_complete เป็น top module
- [ ] Run Synthesis (ใช้เวลา ~5-10 นาที)
- [ ] Run Implementation
- [ ] Generate Bitstream
- [ ] Program FPGA

---

**Last Updated**: November 17, 2025
**Vivado Version**: 2023.2 or newer recommended
**Target Board**: Basys3 (Artix-7) or compatible
