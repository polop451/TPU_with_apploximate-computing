/**
 * TPU Driver for Basys3 FPGA (C Implementation)
 * Supports UART communication
 * 
 * Compile:
 *   macOS/Linux: gcc -o tpu_driver tpu_driver.c
 *   Windows: gcc -o tpu_driver.exe tpu_driver.c
 * 
 * Usage:
 *   ./tpu_driver /dev/tty.usbserial-XXX  (macOS)
 *   ./tpu_driver /dev/ttyUSB0            (Linux)
 *   tpu_driver.exe COM3                  (Windows)
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>

#ifdef _WIN32
    #include <windows.h>
    typedef HANDLE serial_port_t;
    #define SERIAL_INVALID INVALID_HANDLE_VALUE
#else
    #include <termios.h>
    typedef int serial_port_t;
    #define SERIAL_INVALID -1
#endif

// TPU Commands
#define CMD_WRITE_WEIGHT     'W'  // 0x57
#define CMD_WRITE_ACTIVATION 'A'  // 0x41
#define CMD_START            'S'  // 0x53
#define CMD_READ_RESULT      'R'  // 0x52
#define CMD_STATUS           '?'  // 0x3F

// Memory map
#define WEIGHT_BASE      0
#define ACTIVATION_BASE  128
#define RESULT_BASE      192

// Status flags
#define STATUS_BUSY 0x01
#define STATUS_DONE 0x02

// Matrix size
#define MATRIX_SIZE 8

typedef struct {
    serial_port_t handle;
    char port_name[256];
} TPUDriver;

typedef struct {
    uint8_t busy;
    uint8_t done;
} TPUStatus;

// FP16 conversion helpers
typedef union {
    uint16_t bits;
    struct {
        uint16_t mantissa : 10;
        uint16_t exponent : 5;
        uint16_t sign : 1;
    };
} fp16_t;

/**
 * Convert float32 to float16
 */
uint16_t float_to_fp16(float value) {
    uint32_t f32;
    memcpy(&f32, &value, sizeof(float));
    
    uint32_t sign = (f32 >> 31) & 0x1;
    uint32_t exp32 = (f32 >> 23) & 0xFF;
    uint32_t mant32 = f32 & 0x7FFFFF;
    
    // Handle special cases
    if (exp32 == 0xFF) {  // Inf or NaN
        return (sign << 15) | 0x7C00 | (mant32 ? 0x200 : 0);
    }
    if (exp32 == 0) {  // Zero or denormal
        return (sign << 15);
    }
    
    // Convert exponent
    int32_t exp16 = exp32 - 127 + 15;
    if (exp16 <= 0) return (sign << 15);  // Underflow
    if (exp16 >= 31) return (sign << 15) | 0x7C00;  // Overflow
    
    // Convert mantissa (23-bit to 10-bit)
    uint16_t mant16 = mant32 >> 13;
    
    return (sign << 15) | (exp16 << 10) | mant16;
}

/**
 * Convert float16 to float32
 */
float fp16_to_float(uint16_t fp16) {
    uint32_t sign = (fp16 >> 15) & 0x1;
    uint32_t exp16 = (fp16 >> 10) & 0x1F;
    uint32_t mant16 = fp16 & 0x3FF;
    
    uint32_t f32;
    
    // Handle special cases
    if (exp16 == 0x1F) {  // Inf or NaN
        f32 = (sign << 31) | 0x7F800000 | (mant16 << 13);
    } else if (exp16 == 0) {  // Zero or denormal
        f32 = (sign << 31);
    } else {
        // Convert exponent
        uint32_t exp32 = exp16 - 15 + 127;
        // Convert mantissa
        uint32_t mant32 = mant16 << 13;
        f32 = (sign << 31) | (exp32 << 23) | mant32;
    }
    
    float result;
    memcpy(&result, &f32, sizeof(float));
    return result;
}

/**
 * Open serial port
 */
serial_port_t serial_open(const char* port, int baudrate) {
#ifdef _WIN32
    HANDLE handle = CreateFileA(port, GENERIC_READ | GENERIC_WRITE, 
                                0, NULL, OPEN_EXISTING, 0, NULL);
    if (handle == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Error opening %s: %lu\n", port, GetLastError());
        return SERIAL_INVALID;
    }
    
    DCB dcb = {0};
    dcb.DCBlength = sizeof(DCB);
    if (!GetCommState(handle, &dcb)) {
        CloseHandle(handle);
        return SERIAL_INVALID;
    }
    
    dcb.BaudRate = baudrate;
    dcb.ByteSize = 8;
    dcb.Parity = NOPARITY;
    dcb.StopBits = ONESTOPBIT;
    
    if (!SetCommState(handle, &dcb)) {
        CloseHandle(handle);
        return SERIAL_INVALID;
    }
    
    COMMTIMEOUTS timeouts = {0};
    timeouts.ReadIntervalTimeout = 50;
    timeouts.ReadTotalTimeoutConstant = 100;
    timeouts.ReadTotalTimeoutMultiplier = 10;
    SetCommTimeouts(handle, &timeouts);
    
    return handle;
#else
    int fd = open(port, O_RDWR | O_NOCTTY);
    if (fd == -1) {
        fprintf(stderr, "Error opening %s: %s\n", port, strerror(errno));
        return SERIAL_INVALID;
    }
    
    struct termios options;
    tcgetattr(fd, &options);
    
    // Set baud rate
    cfsetispeed(&options, B115200);
    cfsetospeed(&options, B115200);
    
    // 8N1
    options.c_cflag &= ~PARENB;
    options.c_cflag &= ~CSTOPB;
    options.c_cflag &= ~CSIZE;
    options.c_cflag |= CS8;
    
    // Raw mode
    options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
    options.c_iflag &= ~(IXON | IXOFF | IXANY);
    options.c_oflag &= ~OPOST;
    
    // Timeout
    options.c_cc[VMIN] = 0;
    options.c_cc[VTIME] = 10;  // 1 second
    
    tcsetattr(fd, TCSANOW, &options);
    tcflush(fd, TCIOFLUSH);
    
    return fd;
#endif
}

/**
 * Close serial port
 */
void serial_close(serial_port_t handle) {
#ifdef _WIN32
    if (handle != SERIAL_INVALID) {
        CloseHandle(handle);
    }
#else
    if (handle != SERIAL_INVALID) {
        close(handle);
    }
#endif
}

/**
 * Write to serial port
 */
int serial_write(serial_port_t handle, const uint8_t* data, size_t len) {
#ifdef _WIN32
    DWORD written;
    if (!WriteFile(handle, data, len, &written, NULL)) {
        return -1;
    }
    return written;
#else
    return write(handle, data, len);
#endif
}

/**
 * Read from serial port
 */
int serial_read(serial_port_t handle, uint8_t* buffer, size_t len) {
#ifdef _WIN32
    DWORD read;
    if (!ReadFile(handle, buffer, len, &read, NULL)) {
        return -1;
    }
    return read;
#else
    return read(handle, buffer, len);
#endif
}

/**
 * Initialize TPU driver
 */
TPUDriver* tpu_init(const char* port) {
    TPUDriver* tpu = (TPUDriver*)malloc(sizeof(TPUDriver));
    if (!tpu) return NULL;
    
    strncpy(tpu->port_name, port, sizeof(tpu->port_name) - 1);
    tpu->handle = serial_open(port, 115200);
    
    if (tpu->handle == SERIAL_INVALID) {
        free(tpu);
        return NULL;
    }
    
    // Wait for connection to stabilize
    usleep(100000);  // 100ms
    
    printf("✓ Connected to TPU on %s\n", port);
    return tpu;
}

/**
 * Close TPU driver
 */
void tpu_close(TPUDriver* tpu) {
    if (tpu) {
        serial_close(tpu->handle);
        printf("✓ Disconnected from TPU\n");
        free(tpu);
    }
}

/**
 * Write a byte to TPU memory
 */
int tpu_write_byte(TPUDriver* tpu, uint8_t addr, uint8_t data) {
    uint8_t cmd_buf[3];
    uint8_t ack;
    
    // Choose command based on address
    cmd_buf[0] = (addr < 128) ? CMD_WRITE_WEIGHT : CMD_WRITE_ACTIVATION;
    cmd_buf[1] = addr;
    cmd_buf[2] = data;
    
    if (serial_write(tpu->handle, cmd_buf, 3) != 3) {
        return -1;
    }
    
    // Wait for ACK
    if (serial_read(tpu->handle, &ack, 1) != 1) {
        return -1;
    }
    
    return (ack == 'K') ? 0 : -1;
}

/**
 * Read a byte from TPU memory
 */
int tpu_read_byte(TPUDriver* tpu, uint8_t addr, uint8_t* data) {
    uint8_t cmd_buf[2];
    
    cmd_buf[0] = CMD_READ_RESULT;
    cmd_buf[1] = addr;
    
    if (serial_write(tpu->handle, cmd_buf, 2) != 2) {
        return -1;
    }
    
    if (serial_read(tpu->handle, data, 1) != 1) {
        return -1;
    }
    
    return 0;
}

/**
 * Write FP16 value to TPU memory
 */
int tpu_write_fp16(TPUDriver* tpu, uint8_t addr, float value) {
    if (addr % 2 != 0) {
        fprintf(stderr, "Error: FP16 address must be even\n");
        return -1;
    }
    
    uint16_t fp16 = float_to_fp16(value);
    uint8_t low = fp16 & 0xFF;
    uint8_t high = (fp16 >> 8) & 0xFF;
    
    if (tpu_write_byte(tpu, addr, low) != 0) return -1;
    if (tpu_write_byte(tpu, addr + 1, high) != 0) return -1;
    
    return 0;
}

/**
 * Read FP16 value from TPU memory
 */
int tpu_read_fp16(TPUDriver* tpu, uint8_t addr, float* value) {
    if (addr % 2 != 0) {
        fprintf(stderr, "Error: FP16 address must be even\n");
        return -1;
    }
    
    uint8_t low, high;
    if (tpu_read_byte(tpu, addr, &low) != 0) return -1;
    if (tpu_read_byte(tpu, addr + 1, &high) != 0) return -1;
    
    uint16_t fp16 = ((uint16_t)high << 8) | low;
    *value = fp16_to_float(fp16);
    
    return 0;
}

/**
 * Write weight matrix to TPU
 */
int tpu_write_weights(TPUDriver* tpu, float weights[MATRIX_SIZE][MATRIX_SIZE]) {
    printf("Writing weights to TPU...\n");
    uint8_t addr = WEIGHT_BASE;
    
    for (int i = 0; i < MATRIX_SIZE; i++) {
        for (int j = 0; j < MATRIX_SIZE; j++) {
            if (tpu_write_fp16(tpu, addr, weights[i][j]) != 0) {
                fprintf(stderr, "Error writing weight[%d][%d]\n", i, j);
                return -1;
            }
            addr += 2;
        }
    }
    
    printf("✓ Wrote %d weights\n", MATRIX_SIZE * MATRIX_SIZE);
    return 0;
}

/**
 * Write activation matrix to TPU
 */
int tpu_write_activations(TPUDriver* tpu, float activations[MATRIX_SIZE][MATRIX_SIZE]) {
    printf("Writing activations to TPU...\n");
    uint8_t addr = ACTIVATION_BASE;
    
    for (int i = 0; i < MATRIX_SIZE; i++) {
        for (int j = 0; j < MATRIX_SIZE; j++) {
            if (tpu_write_fp16(tpu, addr, activations[i][j]) != 0) {
                fprintf(stderr, "Error writing activation[%d][%d]\n", i, j);
                return -1;
            }
            addr += 2;
        }
    }
    
    printf("✓ Wrote %d activations\n", MATRIX_SIZE * MATRIX_SIZE);
    return 0;
}

/**
 * Start TPU computation
 */
int tpu_start(TPUDriver* tpu) {
    printf("Starting computation...\n");
    uint8_t cmd = CMD_START;
    uint8_t ack;
    
    if (serial_write(tpu->handle, &cmd, 1) != 1) {
        return -1;
    }
    
    if (serial_read(tpu->handle, &ack, 1) != 1) {
        return -1;
    }
    
    return (ack == 'K') ? 0 : -1;
}

/**
 * Get TPU status
 */
int tpu_get_status(TPUDriver* tpu, TPUStatus* status) {
    uint8_t cmd = CMD_STATUS;
    uint8_t status_byte;
    
    if (serial_write(tpu->handle, &cmd, 1) != 1) {
        return -1;
    }
    
    if (serial_read(tpu->handle, &status_byte, 1) != 1) {
        return -1;
    }
    
    status->busy = (status_byte & STATUS_BUSY) ? 1 : 0;
    status->done = (status_byte & STATUS_DONE) ? 1 : 0;
    
    return 0;
}

/**
 * Wait until TPU computation is done
 */
int tpu_wait_until_done(TPUDriver* tpu, int timeout_ms) {
    clock_t start = clock();
    TPUStatus status;
    
    while (1) {
        if (tpu_get_status(tpu, &status) != 0) {
            return -1;
        }
        
        if (status.done) {
            printf("✓ Computation complete\n");
            return 0;
        }
        
        clock_t now = clock();
        if ((now - start) * 1000 / CLOCKS_PER_SEC > timeout_ms) {
            fprintf(stderr, "Error: Timeout waiting for TPU\n");
            return -1;
        }
        
        usleep(10000);  // 10ms
    }
}

/**
 * Read result matrix from TPU
 */
int tpu_read_results(TPUDriver* tpu, float results[MATRIX_SIZE][MATRIX_SIZE]) {
    printf("Reading results from TPU...\n");
    uint8_t addr = RESULT_BASE;
    
    for (int i = 0; i < MATRIX_SIZE; i++) {
        for (int j = 0; j < MATRIX_SIZE; j++) {
            if (tpu_read_fp16(tpu, addr, &results[i][j]) != 0) {
                fprintf(stderr, "Error reading result[%d][%d]\n", i, j);
                return -1;
            }
            addr += 2;
        }
    }
    
    printf("✓ Read %d results\n", MATRIX_SIZE * MATRIX_SIZE);
    return 0;
}

/**
 * Demo program
 */
int main(int argc, char* argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <serial_port>\n", argv[0]);
        fprintf(stderr, "Examples:\n");
        fprintf(stderr, "  macOS:   %s /dev/tty.usbserial-XXX\n", argv[0]);
        fprintf(stderr, "  Linux:   %s /dev/ttyUSB0\n", argv[0]);
        fprintf(stderr, "  Windows: %s COM3\n", argv[0]);
        return 1;
    }
    
    const char* port = argv[1];
    
    printf("=============================================================\n");
    printf("TPU Driver Demo (C)\n");
    printf("=============================================================\n");
    
    // Initialize TPU
    TPUDriver* tpu = tpu_init(port);
    if (!tpu) {
        fprintf(stderr, "Failed to initialize TPU\n");
        return 1;
    }
    
    // Check status
    TPUStatus status;
    if (tpu_get_status(tpu, &status) == 0) {
        printf("\nInitial status: busy=%d, done=%d\n", status.busy, status.done);
    }
    
    // Create test matrices
    printf("\n=============================================================\n");
    printf("Creating test matrices...\n");
    
    float weights[MATRIX_SIZE][MATRIX_SIZE];
    float activations[MATRIX_SIZE][MATRIX_SIZE];
    float results[MATRIX_SIZE][MATRIX_SIZE];
    
    // Initialize with simple test values
    for (int i = 0; i < MATRIX_SIZE; i++) {
        for (int j = 0; j < MATRIX_SIZE; j++) {
            weights[i][j] = (i + j) * 0.1f;
            activations[i][j] = (i - j) * 0.1f;
        }
    }
    
    // Write data to TPU
    printf("\n=============================================================\n");
    if (tpu_write_weights(tpu, weights) != 0) {
        tpu_close(tpu);
        return 1;
    }
    
    if (tpu_write_activations(tpu, activations) != 0) {
        tpu_close(tpu);
        return 1;
    }
    
    // Start computation
    clock_t start_time = clock();
    if (tpu_start(tpu) != 0) {
        tpu_close(tpu);
        return 1;
    }
    
    // Wait for completion
    if (tpu_wait_until_done(tpu, 10000) != 0) {
        tpu_close(tpu);
        return 1;
    }
    
    // Read results
    if (tpu_read_results(tpu, results) != 0) {
        tpu_close(tpu);
        return 1;
    }
    
    clock_t end_time = clock();
    double elapsed = (double)(end_time - start_time) * 1000.0 / CLOCKS_PER_SEC;
    
    printf("\nElapsed time: %.2f ms\n", elapsed);
    
    // Print results
    printf("\n=============================================================\n");
    printf("Results:\n");
    for (int i = 0; i < MATRIX_SIZE; i++) {
        for (int j = 0; j < MATRIX_SIZE; j++) {
            printf("%7.3f ", results[i][j]);
        }
        printf("\n");
    }
    
    printf("\n=============================================================\n");
    printf("Demo complete!\n");
    
    tpu_close(tpu);
    return 0;
}
