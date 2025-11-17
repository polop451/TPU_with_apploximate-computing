# UART Protocol Handler Implementation

## Overview

เพิ่ม UART Protocol Handler เข้าไปใน `tpu_top_with_io_complete.v` เพื่อรองรับการสื่อสารกับ Python driver (`tpu_fpga_interface.py`)

---

## สิ่งที่เพิ่มเข้ามา

### 1. **uart_protocol_handler.v** (ไฟล์ใหม่)

FSM ที่ implement protocol matching กับ Python driver:

**Commands:**
- `0x01` - WRITE_MATRIX_A (128 bytes)
- `0x02` - WRITE_MATRIX_B (128 bytes)
- `0x03` - READ_RESULT (128 bytes)
- `0x04` - START_COMPUTE
- `0x05` - GET_STATUS (4 bytes)
- `0x06` - RESET
- `0x07` - READ_MATRIX_A (128 bytes)
- `0x08` - READ_MATRIX_B (128 bytes)

**Responses:**
- `0xAA` - ACK (command accepted)
- `0x55` - NACK (command rejected)
- `0xBB` - BUSY (TPU is busy)
- `0xDD` - DONE (computation done)

**Features:**
- Multi-byte data reception (FP16 = 2 bytes)
- Memory address auto-increment
- Status reporting (busy/done flags)
- Error handling

### 2. **แก้ไข tpu_top_with_io_complete.v**

**เปลี่ยนจาก:**
```verilog
uart_interface #(...) uart_if (
    // Old simple UART without protocol
);
```

**เป็น:**
```verilog
uart_protocol_handler #(...) uart_protocol (
    .mem_addr(uart_mem_addr),
    .mem_data_out(uart_mem_dout),   // Data to write
    .mem_data_in(mem_data_out),     // Data to read
    .mem_we(uart_mem_we),
    .mem_select(uart_mem_sel),
    .tpu_start(uart_tpu_start),
    .tpu_reset(uart_tpu_reset),
    .tpu_busy(tpu_busy),
    .tpu_done(tpu_done),
    ...
);
```

---

## Protocol Flow

### Write Matrix A/B
```
Python: [CMD] [128 bytes of FP16 data]
FPGA:   [ACK]
```

**Example:**
1. Python sends: `0x01` (WRITE_MATRIX_A)
2. FPGA responds: `0xAA` (ACK)
3. Python sends: 128 bytes (64 FP16 values)
4. FPGA writes to matrix_a_mem

### Start Computation
```
Python: [0x04]
FPGA:   [ACK]
```

### Get Status
```
Python: [0x05]
FPGA:   [ACK] [status_byte] [cycle_low] [cycle_mid] [cycle_high]
```

**Status byte format:**
- Bit 0: busy flag
- Bit 1: done flag  
- Bit 2: error flag
- Bits 3-7: reserved

### Read Result
```
Python: [0x03]
FPGA:   [ACK] [128 bytes of FP16 data]
```

---

## FSM States

```
STATE_IDLE          -> รอคำสั่งจาก UART
STATE_RECV_CMD      -> รับคำสั่ง
STATE_PROCESS_CMD   -> ประมวลผลคำสั่ง
STATE_SEND_ACK      -> ส่ง ACK กลับ
STATE_RECV_DATA     -> รับข้อมูล (128 bytes)
STATE_WRITE_MEM     -> เขียนลง memory
STATE_READ_MEM      -> อ่านจาก memory
STATE_SEND_DATA     -> ส่งข้อมูลกลับ
STATE_SEND_STATUS   -> ส่ง status
STATE_WAIT_TX       -> รอ UART TX เสร็จ
```

---

## Memory Interface

Protocol handler เชื่อมต่อกับ memory ผ่าน:

```verilog
// Write to memory
output reg [7:0] mem_addr,          // Address (0-63)
output reg [15:0] mem_data_out,     // Data to write (FP16)
output reg mem_we,                  // Write enable
output reg [1:0] mem_select,        // 00=A, 01=B, 10=Result

// Read from memory
input wire [15:0] mem_data_in,      // Data read (FP16)

// TPU control
output reg tpu_start,               // Start computation
output reg tpu_reset,               // Reset TPU
input wire tpu_busy,                // TPU is busy
input wire tpu_done,                // Computation done
```

---

## Data Format

### FP16 (Half Precision Float)
- **Format:** IEEE 754 binary16
- **Size:** 16 bits (2 bytes)
- **Byte order:** Little-endian
  - Byte 0: bits [7:0]
  - Byte 1: bits [15:8]

### Matrix Layout
- **Size:** 8×8 = 64 values
- **Total bytes:** 64 × 2 = 128 bytes
- **Addressing:** Row-major order
  ```
  matrix[row][col] -> address = row * 8 + col
  matrix[0][0] -> addr 0
  matrix[0][1] -> addr 1
  ...
  matrix[7][7] -> addr 63
  ```

---

## Timing

### UART Configuration
- **Baud rate:** 115200
- **Bit time:** 1/115200 ≈ 8.68 μs
- **Byte time:** 8.68 μs × 10 bits ≈ 86.8 μs

### Estimated Latency

| Operation | Bytes | Time (ms) |
|-----------|-------|-----------|
| Write Matrix A | 129 (cmd + data) | ~11.2 |
| Write Matrix B | 129 | ~11.2 |
| Start Compute | 1 | ~0.09 |
| Computation | - | ~0.08 |
| Read Result | 129 | ~11.2 |
| **Total** | **389** | **~33.6 ms** |

### Throughput
- Matrix multiply: 8×8 = 512 MAC operations
- Time: ~34 ms
- **Throughput:** ~15 kOPS (limited by UART)

---

## Testing

### 1. Synthesize & Program FPGA

```tcl
# In Vivado
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# Program FPGA
open_hw_manager
connect_hw_server
program_hw_devices [get_hw_devices xc7a35t_0]
```

### 2. Test with Python

```bash
# Quick test
cd tests/integration
python3 test_fpga_tpu_complete.py --port /dev/cu.usbserial-XXXXXX --quick

# Full test
python3 test_fpga_tpu_complete.py --port /dev/cu.usbserial-XXXXXX
```

### 3. Expected Results

**Connection:**
```
Connecting to FPGA at /dev/cu.usbserial-XXXXXX (115200 baud)...
✓ Connected to FPGA TPU successfully!
```

**Basic Test:**
```
Test: Basic Matrix Multiplication
  ✓ Identity matrix
  ✓ Zero matrix
  ✓ Ones matrix
  ✓ Simple multiplication
```

**Performance:**
```
Average time per computation: ~33 ms
Throughput: ~0.015 GOPS (15 MOPS)
Efficiency: ~0.2% (limited by UART bandwidth)
```

---

## Debugging

### Status LEDs

UART protocol handler provides status on `status_leds[7:0]`:
- Bit 0: IDLE indicator
- Bit 1: TPU busy
- Bit 2: TPU done
- Bit 3: RX valid (receiving data)
- Bit 4: TX busy (transmitting data)
- Bits 5-7: Reserved

### Common Issues

**1. No response (timeout)**
- Check: FPGA programmed?
- Check: Correct serial port?
- Check: Baud rate = 115200?
- Try: Press reset button

**2. Wrong data**
- Check: Byte order (little-endian)
- Check: Memory address calculation
- Check: switches[7] = 1 (UART mode)

**3. Slow performance**
- Normal: UART is slow (115200 baud)
- Bottleneck: ~11 ms per matrix transfer
- Solution: Use faster interface (SPI, Ethernet)

---

## Files Modified/Created

### Created:
- `hardware/verilog/uart_protocol_handler.v` - Protocol FSM

### Modified:
- `hardware/verilog/tpu_top_with_io_complete.v` - Integration
  - Replaced `uart_interface` with `uart_protocol_handler`
  - Connected memory and control signals
  - Updated signal declarations

### Tested:
- ✅ Syntax check (iverilog)
- ⏳ Synthesis (pending)
- ⏳ Hardware test (pending)

---

## Next Steps

1. **Synthesize** in Vivado
2. **Check timing** - should still meet 100 MHz
3. **Program FPGA** with new bitstream
4. **Run Python tests** to verify communication
5. **Measure performance** and accuracy

---

## Performance Comparison

### Before (No Protocol)
- Manual button/switch control only
- No PC communication
- Demo mode only

### After (With Protocol)
- Full UART protocol support
- PC control via Python
- Automated testing
- Performance measurement
- **~15 MOPS throughput** (UART-limited)

### Theoretical Maximum
- TPU: 64 MACs × 100 MHz = **6.4 GOPS**
- UART: 115200 baud ≈ **15 kOPS**
- **Efficiency: 0.2%** (bottleneck is UART)

### To Improve:
- Use SPI (10 MHz) → **~100x faster**
- Use Ethernet → **~1000x faster**
- Add on-board memory → reduce transfers

---

## Summary

✅ **UART Protocol Handler implemented**  
✅ **Syntax verified (no errors)**  
✅ **Compatible with Python driver**  
✅ **Ready for synthesis and testing**  

**การสื่อสาร UART ทำงานแบบ request-response:**
- Python sends command → FPGA responds
- Support ทุก operations: write, read, compute, status
- Protocol เรียบง่ายและ robust

**ขั้นตอนถัดไป:**
1. Synthesize & program FPGA
2. Test กับ Python driver
3. Measure actual performance
4. ปรับปรุง timing หาก necessary
