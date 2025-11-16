# Memory Management in tpu_top_with_io_complete.v

## ภาพรวมการจัดการ Memory

Module `tpu_top_with_io_complete.v` ใช้ **Block RAM** แบบง่ายๆ แยกเป็น 3 banks สำหรับเก็บข้อมูล:

```
┌─────────────────────────────────────────────────┐
│          Memory Architecture                     │
├─────────────────────────────────────────────────┤
│  Matrix A Memory  │  Matrix B Memory  │ Result  │
│   [0:63] x 16-bit │   [0:63] x 16-bit │ [0:63]  │
│   (128 bytes)     │   (128 bytes)     │ (128 B) │
│                   │                   │         │
│   8x8 FP16        │   8x8 FP16        │ 8x8 FP16│
│   Activations     │   Weights         │ Output  │
└─────────────────────────────────────────────────┘
```

---

## 1. Memory Banks (3 Banks)

### Memory Declarations
```verilog
// Matrix A memory (8x8 = 64 FP16 values = 128 bytes)
reg [15:0] matrix_a_mem [0:63];

// Matrix B memory (8x8 = 64 FP16 values = 128 bytes)
reg [15:0] matrix_b_mem [0:63];

// Result memory (8x8 = 64 FP16 values = 128 bytes)
reg [15:0] result_mem [0:63];
```

### Memory Sizes
- **แต่ละ bank**: 64 elements × 16 bits = 1,024 bits = 128 bytes
- **รวมทั้งหมด**: 3 banks × 128 bytes = **384 bytes**
- **Format**: FP16 (Half-Precision Floating Point)

---

## 2. Memory Interface Signals

### Control Signals
```verilog
wire [7:0] mem_addr;        // Address (0-63 ใช้แค่ 6 bits)
wire [15:0] mem_data_in;    // Data to write (FP16)
wire [15:0] mem_data_out;   // Data to read (FP16)
wire mem_we;                // Write Enable
wire [1:0] mem_select;      // Bank Select
```

### Bank Selection (`mem_select`)
- `2'b00` = Matrix A memory (activations)
- `2'b01` = Matrix B memory (weights)
- `2'b10` = Result memory (output)
- `2'b11` = Reserved (ไม่ใช้งาน)

---

## 3. Memory Write Logic

### Write Operation (Synchronous)
```verilog
always @(posedge clk) begin
    if (!rst_n) begin
        // Optional: Initialize memory to zero
    end else if (mem_we) begin
        case (mem_select)
            2'b00: matrix_a_mem[mem_addr[5:0]] <= mem_data_in;
            2'b01: matrix_b_mem[mem_addr[5:0]] <= mem_data_in;
            2'b10: result_mem[mem_addr[5:0]] <= mem_data_in;
            default: ;
        endcase
    end
end
```

### คุณสมบัติ:
- ✅ **Synchronous write**: เขียนข้อมูลตาม clock edge
- ✅ **Single-port write**: เขียนได้ครั้งละ 1 ตำแหน่ง
- ✅ **Bank selection**: เลือก bank ด้วย `mem_select`
- ⚠️ **Write priority**: Interface ที่ active จะควบคุม memory

---

## 4. Memory Read Logic

### Read Operation (Combinational)
```verilog
reg [15:0] mem_read_data;

always @(*) begin
    case (mem_select)
        2'b00: mem_read_data = matrix_a_mem[mem_addr[5:0]];
        2'b01: mem_read_data = matrix_b_mem[mem_addr[5:0]];
        2'b10: mem_read_data = result_mem[mem_addr[5:0]];
        default: mem_read_data = 16'h0000;
    endcase
end

assign mem_data_out = mem_read_data;
```

### คุณสมบัติ:
- ✅ **Combinational read**: อ่านได้ทันทีไม่ต้องรอ clock
- ✅ **Single-port read**: อ่านได้ครั้งละ 1 ตำแหน่ง
- ⚠️ **Read latency**: 0 cycles (แต่มี combinational delay)

---

## 5. Memory Access Patterns

### Pattern 1: Loading Data (จาก Interface)
```
External Interface → mem_data_in → matrix_a_mem/matrix_b_mem
                                    (Sequential write, address 0-63)
```

### Pattern 2: Computing (Systolic Array)
```
matrix_a_mem[0:7] → Systolic Array → systolic_results[8][8]
matrix_b_mem[0:7] → (8x8 MAC units) → (Parallel compute)
```

**หมายเหตุ**: Systolic array อ่านแบบ **parallel broadcast**:
- Matrix A → ส่งไปแต่ละ row (8 values พร้อมกัน)
- Matrix B → ส่งไปแต่ละ column (8 values พร้อมกัน)

### Pattern 3: Storing Results
```
systolic_results[8][8] → result_mem[0:63]
                         (Sequential write, 1 row per cycle)
```

```verilog
// Store all 8x8 results to result memory
if (row_counter < 8) begin
    for (j = 0; j < 8; j = j + 1) begin
        result_mem[row_counter * 8 + j] <= systolic_results[row_counter][j];
    end
    row_counter <= row_counter + 1;
end
```

---

## 6. Memory Mapping (Address Layout)

### Matrix A Memory Layout (8x8)
```
Address  │ Row │ Col │ Element │ Description
─────────┼─────┼─────┼─────────┼─────────────────
0        │  0  │  0  │ A[0][0] │ Row 0, Col 0
1        │  0  │  1  │ A[0][1] │ Row 0, Col 1
...      │ ... │ ... │ ...     │ ...
7        │  0  │  7  │ A[0][7] │ Row 0, Col 7
8        │  1  │  0  │ A[1][0] │ Row 1, Col 0
...      │ ... │ ... │ ...     │ ...
63       │  7  │  7  │ A[7][7] │ Row 7, Col 7
```

**Formula**: `address = row * 8 + col`

### Matrix B Memory Layout (8x8)
```
เหมือนกับ Matrix A
Address 0-63 → B[0][0] to B[7][7]
```

### Result Memory Layout (8x8)
```
เหมือนกับ Matrix A และ B
Address 0-63 → Result[0][0] to Result[7][7]
```

---

## 7. Memory Access from Different Interfaces

### Interface Multiplexing
```verilog
assign mem_addr = (interface_mode == 2'b00) ? btn_mem_addr :
                  (interface_mode == 2'b01) ? uart_mem_addr :
                  (interface_mode == 2'b10) ? spi_mem_addr : 8'h00;

assign mem_data_in = (interface_mode == 2'b00) ? btn_mem_din :
                     (interface_mode == 2'b01) ? uart_mem_din :
                     (interface_mode == 2'b10) ? spi_mem_din : 16'h0000;

assign mem_we = (interface_mode == 2'b00) ? btn_mem_we :
                (interface_mode == 2'b01) ? uart_mem_we :
                (interface_mode == 2'b10) ? spi_mem_we : 1'b0;
```

### Interface Modes
1. **Button/Switch Mode** (`switches[15:14] = 00`)
   - เขียนข้อมูลทีละ byte
   - ใช้ switches[7:0] เป็น address
   - กด btn_down เพื่อเขียน

2. **UART Mode** (`switches[15:14] = 01`)
   - รับข้อมูลผ่าน serial port
   - Protocol: Command + Address + Data
   - 115200 baud rate

3. **SPI Mode** (`switches[15:14] = 10`)
   - รองรับในอนาคต (ยังไม่ implement เต็ม)

---

## 8. Memory Timing Diagram

### Write Operation
```
Clock:    __|‾‾|__|‾‾|__|‾‾|__|‾‾|__
mem_we:   ______|‾‾‾‾‾‾‾‾|________
mem_addr: ----< Valid >----------
mem_data: ----< Valid >----------
Memory:   ------[Write]----------
```

### Read Operation
```
Clock:    __|‾‾|__|‾‾|__|‾‾|__
mem_addr: ----< Valid >------
mem_data: ----< Data Valid >-
         (Combinational, ~2ns delay)
```

---

## 9. Memory Bandwidth Analysis

### Write Bandwidth
- **Per cycle**: 1 write × 16 bits = 16 bits/cycle
- **@100MHz**: 16 bits × 100M = **1.6 Gbps** = 200 MB/s

### Read Bandwidth (Systolic Array)
- **Parallel read**: 16 values × 16 bits = 256 bits/cycle
- **@100MHz**: 256 bits × 100M = **25.6 Gbps** = 3.2 GB/s

**Note**: Systolic array อ่านแบบ parallel ทำให้ bandwidth สูงมาก

---

## 10. Memory Issues & Limitations

### ⚠️ ปัญหาที่พบ

#### 1. **Single-Port Limitation**
```
ปัญหา: เขียนได้ครั้งละ 1 address
ผลกระทบ: ต้องใช้เวลา 64 cycles ในการโหลด matrix แต่ละตัว
```

#### 2. **No Memory Initialization**
```verilog
always @(posedge clk) begin
    if (!rst_n) begin
        // Optional: Initialize memory to zero
        // ⚠️ ไม่มีการ clear memory
    end
```
**ปัญหา**: หลัง reset memory ยังเหลือค่าเก่า (unknown state)

#### 3. **Systolic Array Access Pattern**
```verilog
// ปัจจุบัน: อ่านแค่ element แรกของแต่ละ row
.a_in_0(matrix_a_mem[0]),  // Row 0, Col 0
.a_in_1(matrix_a_mem[1]),  // Row 0, Col 1 ??? (ควรเป็น Row 1)
```
**⚠️ BUG**: การ map address ไม่ถูกต้อง!

#### 4. **No Write Conflict Resolution**
```
ถ้า 2 interfaces พยายามเขียนพร้อมกัน → ไม่มีการจัดการ conflict
```

---

## 11. การปรับปรุงที่แนะนำ

### 🔧 Improvement 1: Memory Initialization
```verilog
integer init_i;
always @(posedge clk) begin
    if (!rst_n) begin
        for (init_i = 0; init_i < 64; init_i = init_i + 1) begin
            matrix_a_mem[init_i] <= 16'h0000;
            matrix_b_mem[init_i] <= 16'h0000;
            result_mem[init_i] <= 16'h0000;
        end
    end else if (mem_we) begin
        // ... write logic ...
    end
end
```

### 🔧 Improvement 2: Dual-Port Memory
```verilog
// ใช้ Block RAM แบบ dual-port
// Port A: สำหรับ external interface (write/read)
// Port B: สำหรับ systolic array (read-only)
```

### 🔧 Improvement 3: Fix Systolic Array Mapping
```verilog
// แก้ไขการ map ให้ถูกต้อง
.a_in_0(matrix_a_mem[0 * 8 + 0]),  // Row 0
.a_in_1(matrix_a_mem[1 * 8 + 0]),  // Row 1
.a_in_2(matrix_a_mem[2 * 8 + 0]),  // Row 2
// ...
```

### 🔧 Improvement 4: Memory Arbiter
```verilog
// เพิ่ม arbiter สำหรับจัดการ memory access conflicts
module memory_arbiter (
    input [2:0] request,      // From 3 interfaces
    output [2:0] grant,       // Grant to 1 interface
    input clk, rst_n
);
```

---

## 12. Synthesis Results

### Expected Resource Usage (Artix-7)
```
Memory Type: Distributed RAM หรือ Block RAM

Distributed RAM:
- 384 bytes = 3,072 bits
- ใช้ ~768 LUTs (4 bits per LUT)

Block RAM:
- 3 banks × 2 RAMB18 = 6 RAMB18 blocks
- หรือ 3 RAMB36 blocks (ถ้า synthesis optimize)
```

### Vivado จะเลือกแบบไหน?
- **ถ้า memory เล็ก** (< 1KB): Distributed RAM (LUTs)
- **ถ้า memory ใหญ่** (> 1KB): Block RAM
- **ปกติ**: Vivado เลือก Block RAM เพราะประหยัด LUTs

---

## 13. การใช้งาน Memory (Example)

### Example 1: โหลด Matrix A ผ่าน UART
```python
# Python script
import serial

uart = serial.Serial('/dev/ttyUSB0', 115200)

# โหลด matrix A (8x8 = 64 values)
for addr in range(64):
    fp16_value = float_to_fp16(matrix_a[addr])
    uart.write(bytes([0x57]))  # 'W' = Write command
    uart.write(bytes([addr]))  # Address
    uart.write(bytes([fp16_value >> 8]))    # High byte
    uart.write(bytes([fp16_value & 0xFF]))  # Low byte
```

### Example 2: โหลดผ่าน Button Mode
```
1. Set switches[15:14] = 00 (Button mode)
2. Set switches[9:8] = 00 (Select Matrix A)
3. Set switches[7:0] = address (0-63)
4. กด btn_down เพื่อเขียนค่า
5. ทำซ้ำสำหรับ address 0-63
```

---

## สรุป Memory Architecture

| Feature | Description |
|---------|-------------|
| **Total Size** | 384 bytes (3 banks × 128 bytes) |
| **Data Format** | FP16 (16-bit floating point) |
| **Banks** | 3 banks (Matrix A, B, Result) |
| **Access** | Single-port (1 read/write per cycle) |
| **Read Type** | Combinational (0 cycle latency) |
| **Write Type** | Synchronous (1 cycle latency) |
| **Systolic Access** | Parallel broadcast (16 values) |
| **Synthesis** | Block RAM (RAMB18/RAMB36) |

---

**Last Updated**: November 17, 2025
**Module**: tpu_top_with_io_complete.v
**Memory Size**: 384 bytes total
