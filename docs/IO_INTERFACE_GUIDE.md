# TPU I/O Interface Documentation

## Overview
TPU มี 3 ระบบ I/O ที่สามารถเลือกใช้งานได้:
1. **Button/Switch** - ควบคุมโดยตรงจาก Basys3 (ไม่ต้องใช้ PC)
2. **UART** - เชื่อมต่อผ่าน USB (115200 baud)
3. **SPI** - ความเร็วสูง ผ่าน PMOD connector (up to 25 MHz)

## การเลือก Interface Mode
ใช้ Switch 15-14 เพื่อเลือกโหมด:
- `SW[15:14] = 00`: Button/Switch mode (standalone)
- `SW[15:14] = 01`: UART mode (USB connection)
- `SW[15:14] = 10`: SPI mode (PMOD connector)

---

## 1. Button/Switch Interface

### การใช้งาน (Standalone Mode)
**ไม่ต้องใช้ PC เลย - ควบคุมทุกอย่างผ่านปุ่มและสวิตช์**

#### ขั้นตอน:
1. **ตั้งค่าโหมด**: `SW[15:14] = 00` (Button mode)
2. **ใส่ข้อมูล**: 
   - ตั้งค่าที่ `SW[7:0]` (8-bit data)
   - กดปุ่ม **CENTER** เพื่อบันทึก
   - ข้อมูลจะถูกเขียนไปที่ address ปัจจุบัน และ address จะเพิ่มขึ้นอัตโนมัติ
3. **เริ่มการคำนวณ**: กดปุ่ม **UP**
4. **ดูผลลัพธ์**:
   - กดปุ่ม **LEFT/RIGHT** เพื่อดูผลลัพธ์แต่ละตัว (0-63)
   - LED แสดง result index และค่า output
   - 7-segment แสดง result index (2 หลัก) และค่า output (2 หลัก)
5. **Reset**: กดปุ่ม **DOWN**

#### LED Indicators (Button Mode)
```
LED[15]    = TPU Done
LED[14]    = TPU Busy
LED[13:8]  = Result Index (0-63)
LED[7:0]   = Output Value (8-bit)
```

#### 7-Segment Display
```
Digit 3-2: Result Index (hex)
Digit 1-0: Output Value (hex)
```

### ตัวอย่างการใช้งาน
```
1. SW[15:14] = 00          // เลือก Button mode
2. SW[7:0] = 0x12          // ตั้งค่า data
3. กด CENTER                // บันทึก (address 0)
4. SW[7:0] = 0x34          // ตั้งค่า data ใหม่
5. กด CENTER                // บันทึก (address 1)
6. ... ใส่ข้อมูลต่อไปเรื่อยๆ
7. กด UP                    // เริ่มคำนวณ
8. รอ LED[14] ดับ           // รอการคำนวณเสร็จ
9. กด RIGHT/LEFT            // ดูผลลัพธ์
```

---

## 2. UART Interface

### Specifications
- **Baud Rate**: 115200
- **Data Format**: 8N1 (8 data bits, no parity, 1 stop bit)
- **Connection**: USB port on Basys3 (appears as COM port)

### Command Protocol

#### Write Weight/Activation
```
TX: 'W' (0x57)           // Write Weight command
TX: [address]            // 8-bit address (0-255)
TX: [data]               // 8-bit data
RX: 'K'                  // ACK
```

#### Write Activation
```
TX: 'A' (0x41)           // Write Activation command
TX: [address]            // 8-bit address (128-255)
TX: [data]               // 8-bit data
RX: 'K'                  // ACK
```

#### Start Computation
```
TX: 'S' (0x53)           // Start command
RX: 'K'                  // ACK
```

#### Read Result
```
TX: 'R' (0x52)           // Read command
TX: [address]            // Result address (192-255)
RX: [data]               // 8-bit result data
```

#### Check Status
```
TX: '?' (0x3F)           // Status query
RX: [status]             // Bit 0: busy, Bit 1: done
```

### Memory Map
```
0x00 - 0x7F (0-127):     Weight Memory (256 bytes = 128 FP16 values)
0x80 - 0xFF (128-255):   Activation Memory (256 bytes = 128 FP16 values)
0xC0 - 0xFF (192-255):   Result Memory (read-only)
```

### Python Example
```python
import serial
import time

# เปิด serial port
ser = serial.Serial('COM3', 115200, timeout=1)  # เปลี่ยน COM port ตามเครื่อง

# เขียน weight
def write_weight(addr, data):
    ser.write(b'W')
    ser.write(bytes([addr]))
    ser.write(bytes([data]))
    ack = ser.read(1)
    return ack == b'K'

# เขียน activation
def write_activation(addr, data):
    ser.write(b'A')
    ser.write(bytes([addr]))
    ser.write(bytes([data]))
    ack = ser.read(1)
    return ack == b'K'

# เริ่มการคำนวณ
def start_computation():
    ser.write(b'S')
    ack = ser.read(1)
    return ack == b'K'

# อ่านผลลัพธ์
def read_result(addr):
    ser.write(b'R')
    ser.write(bytes([addr]))
    data = ser.read(1)
    return data[0] if data else None

# ตรวจสอบสถานะ
def check_status():
    ser.write(b'?')
    status = ser.read(1)
    if status:
        busy = bool(status[0] & 0x01)
        done = bool(status[0] & 0x02)
        return {'busy': busy, 'done': done}
    return None

# ตัวอย่างการใช้งาน
# 1. เขียน weights (address 0-127)
for i in range(16):
    write_weight(i, i * 10)

# 2. เขียน activations (address 128-255)
for i in range(16):
    write_activation(128 + i, i * 5)

# 3. เริ่มการคำนวณ
start_computation()

# 4. รอให้เสร็จ
while True:
    status = check_status()
    if status and status['done']:
        break
    time.sleep(0.1)

# 5. อ่านผลลัพธ์
for i in range(16):
    result = read_result(192 + i)
    print(f"Result[{i}] = {result}")

ser.close()
```

---

## 3. SPI Interface

### Specifications
- **Mode**: Mode 0 (CPOL=0, CPHA=0)
- **Speed**: Up to 25 MHz
- **Pins** (PMOD JA):
  - JA1: SCLK (Clock)
  - JA2: MOSI (Master Out Slave In)
  - JA3: MISO (Master In Slave Out)
  - JA4: CS_N (Chip Select, active low)

### Command Protocol

#### Write Data
```
1. CS_N = 0
2. Send CMD_WRITE (0x01)
3. Send Address (0x00-0xFF)
4. Send Data (0x00-0xFF)
5. CS_N = 1
```

#### Read Data
```
1. CS_N = 0
2. Send CMD_READ (0x02)
3. Send Address (0x00-0xFF)
4. Receive Data (0x00-0xFF)
5. CS_N = 1
```

#### Start Computation
```
1. CS_N = 0
2. Send CMD_START (0x03)
3. CS_N = 1
```

#### Check Status
```
1. CS_N = 0
2. Send CMD_STATUS (0x04)
3. Receive Status byte (bit 0: busy, bit 1: done)
4. CS_N = 1
```

### Arduino Example (SPI Master)
```cpp
#include <SPI.h>

#define CS_PIN 10
#define CMD_WRITE  0x01
#define CMD_READ   0x02
#define CMD_START  0x03
#define CMD_STATUS 0x04

void setup() {
  pinMode(CS_PIN, OUTPUT);
  digitalWrite(CS_PIN, HIGH);
  SPI.begin();
  SPI.setClockDivider(SPI_CLOCK_DIV4);  // 4 MHz (16MHz/4)
}

void spi_write(uint8_t addr, uint8_t data) {
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(CMD_WRITE);
  SPI.transfer(addr);
  SPI.transfer(data);
  digitalWrite(CS_PIN, HIGH);
  delayMicroseconds(10);
}

uint8_t spi_read(uint8_t addr) {
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(CMD_READ);
  SPI.transfer(addr);
  uint8_t data = SPI.transfer(0x00);
  digitalWrite(CS_PIN, HIGH);
  delayMicroseconds(10);
  return data;
}

void spi_start() {
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(CMD_START);
  digitalWrite(CS_PIN, HIGH);
}

uint8_t spi_status() {
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(CMD_STATUS);
  uint8_t status = SPI.transfer(0x00);
  digitalWrite(CS_PIN, HIGH);
  return status;
}

void loop() {
  // Write weights
  for (int i = 0; i < 16; i++) {
    spi_write(i, i * 10);
  }
  
  // Write activations
  for (int i = 0; i < 16; i++) {
    spi_write(128 + i, i * 5);
  }
  
  // Start computation
  spi_start();
  
  // Wait for completion
  while (spi_status() & 0x01) {
    delay(10);
  }
  
  // Read results
  for (int i = 0; i < 16; i++) {
    uint8_t result = spi_read(192 + i);
    Serial.print("Result[");
    Serial.print(i);
    Serial.print("] = ");
    Serial.println(result);
  }
  
  delay(5000);
}
```

---

## Performance Comparison

| Interface | Speed | Pros | Cons |
|-----------|-------|------|------|
| **Button/Switch** | Manual | - ไม่ต้องใช้ PC<br>- ง่ายที่สุด<br>- ดี debug | - ช้ามาก<br>- ใส่ข้อมูลเยอะไม่ได้ |
| **UART** | 115200 bps<br>(~11 KB/s) | - มี USB onboard<br>- ง่ายโปรแกรม<br>- PC support ดี | - ช้ากว่า SPI<br>- Serial overhead |
| **SPI** | Up to 25 MHz<br>(~3 MB/s) | - **เร็วที่สุด**<br>- Efficient protocol<br>- Low latency | - ต้องใช้ PMOD<br>- ต้องมี SPI master |

---

## การใช้งานจริง

### สำหรับการทดสอบ: ใช้ Button/Switch Mode
```
1. ตั้ง SW[15:14] = 00
2. ใส่ข้อมูลผ่านปุ่ม CENTER
3. เริ่มคำนวณด้วยปุ่ม UP
4. ดูผลลัพธ์ที่ LED และ 7-segment
```

### สำหรับ Development: ใช้ UART
```
1. ตั้ง SW[15:14] = 01
2. เชื่อมต่อ USB cable
3. ใช้ Python script เพื่อโหลดข้อมูลและอ่านผลลัพธ์
4. Monitor การทำงานผ่าน serial terminal
```

### สำหรับ Performance: ใช้ SPI
```
1. ตั้ง SW[15:14] = 10
2. ต่อ SPI master (Arduino, Raspberry Pi, etc.) ที่ PMOD JA
3. โหลดข้อมูลด้วยความเร็วสูง
4. เหมาะสำหรับ real-time applications
```

---

## Troubleshooting

### UART ไม่ทำงาน
- ตรวจสอบ COM port ที่ถูกต้อง (Device Manager)
- ตรวจสอบ baud rate = 115200
- ตรวจสอบ SW[15:14] = 01

### SPI ไม่ทำงาน
- ตรวจสอบการต่อสายที่ PMOD JA
- ตรวจสอบ Clock speed (ไม่เกิน 25 MHz)
- ตรวจสอบ CS_N toggle ถูกต้อง
- ตรวจสอบ SW[15:14] = 10

### Button/Switch ไม่ตอบสนอง
- ตรวจสอบ SW[15:14] = 00
- กดปุ่ม DOWN เพื่อ reset
- ตรวจสอบ LED[14:15] สำหรับสถานะ TPU

---

## Files Summary

| File | Description |
|------|-------------|
| `uart_interface.v` | UART communication module (115200 baud) |
| `io_interfaces.v` | SPI and Button/Switch interface modules |
| `tpu_top_with_io.v` | Top-level integration with all 3 interfaces |
| `basys3_io_constraints.xdc` | Pin assignments for Basys3 |

---

## Next Steps

1. **Synthesis**: Open Vivado, create project, add all .v files and .xdc
2. **Simulation**: Test with testbench (optional)
3. **Implementation**: Run synthesis → implementation → generate bitstream
4. **Programming**: Upload .bit file to Basys3
5. **Testing**: Try each interface mode!

สนุกกับการทดลอง TPU! 🚀
