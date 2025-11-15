/**
 * TPU Driver for Basys3 FPGA (C++ Implementation)
 * Supports UART communication with modern C++ features
 * 
 * Compile:
 *   g++ -std=c++17 -o tpu_driver_cpp tpu_driver.cpp
 * 
 * Usage:
 *   ./tpu_driver_cpp /dev/tty.usbserial-XXX  (macOS)
 *   ./tpu_driver_cpp /dev/ttyUSB0            (Linux)
 *   tpu_driver_cpp.exe COM3                  (Windows)
 */

#include <iostream>
#include <vector>
#include <array>
#include <string>
#include <stdexcept>
#include <chrono>
#include <thread>
#include <cstring>
#include <cmath>

#ifdef _WIN32
    #include <windows.h>
    using serial_handle_t = HANDLE;
    constexpr serial_handle_t INVALID_SERIAL = INVALID_HANDLE_VALUE;
#else
    #include <unistd.h>
    #include <fcntl.h>
    #include <termios.h>
    using serial_handle_t = int;
    constexpr serial_handle_t INVALID_SERIAL = -1;
#endif

constexpr size_t MATRIX_SIZE = 8;

// TPU Commands
enum class TPUCommand : uint8_t {
    WriteWeight = 'W',
    WriteActivation = 'A',
    Start = 'S',
    ReadResult = 'R',
    Status = '?'
};

// Memory addresses
constexpr uint8_t WEIGHT_BASE = 0;
constexpr uint8_t ACTIVATION_BASE = 128;
constexpr uint8_t RESULT_BASE = 192;

/**
 * TPU Status structure
 */
struct TPUStatus {
    bool busy;
    bool done;
    
    TPUStatus() : busy(false), done(false) {}
    TPUStatus(uint8_t status_byte) 
        : busy(status_byte & 0x01), done(status_byte & 0x02) {}
    
    friend std::ostream& operator<<(std::ostream& os, const TPUStatus& s) {
        return os << "TPUStatus(busy=" << s.busy << ", done=" << s.done << ")";
    }
};

/**
 * FP16 utilities
 */
class FP16 {
public:
    static uint16_t fromFloat(float value) {
        uint32_t f32;
        std::memcpy(&f32, &value, sizeof(float));
        
        uint32_t sign = (f32 >> 31) & 0x1;
        uint32_t exp32 = (f32 >> 23) & 0xFF;
        uint32_t mant32 = f32 & 0x7FFFFF;
        
        // Special cases
        if (exp32 == 0xFF) {
            return (sign << 15) | 0x7C00 | (mant32 ? 0x200 : 0);
        }
        if (exp32 == 0) {
            return (sign << 15);
        }
        
        // Convert exponent
        int32_t exp16 = exp32 - 127 + 15;
        if (exp16 <= 0) return (sign << 15);
        if (exp16 >= 31) return (sign << 15) | 0x7C00;
        
        // Convert mantissa
        uint16_t mant16 = mant32 >> 13;
        
        return (sign << 15) | (exp16 << 10) | mant16;
    }
    
    static float toFloat(uint16_t fp16) {
        uint32_t sign = (fp16 >> 15) & 0x1;
        uint32_t exp16 = (fp16 >> 10) & 0x1F;
        uint32_t mant16 = fp16 & 0x3FF;
        
        uint32_t f32;
        
        if (exp16 == 0x1F) {
            f32 = (sign << 31) | 0x7F800000 | (mant16 << 13);
        } else if (exp16 == 0) {
            f32 = (sign << 31);
        } else {
            uint32_t exp32 = exp16 - 15 + 127;
            uint32_t mant32 = mant16 << 13;
            f32 = (sign << 31) | (exp32 << 23) | mant32;
        }
        
        float result;
        std::memcpy(&result, &f32, sizeof(float));
        return result;
    }
};

/**
 * Serial port wrapper
 */
class SerialPort {
private:
    serial_handle_t handle_;
    std::string port_;
    
public:
    SerialPort(const std::string& port, int baudrate = 115200) 
        : handle_(INVALID_SERIAL), port_(port) {
        open(baudrate);
    }
    
    ~SerialPort() {
        close();
    }
    
    // Disable copy
    SerialPort(const SerialPort&) = delete;
    SerialPort& operator=(const SerialPort&) = delete;
    
    // Enable move
    SerialPort(SerialPort&& other) noexcept 
        : handle_(other.handle_), port_(std::move(other.port_)) {
        other.handle_ = INVALID_SERIAL;
    }
    
    void open(int baudrate) {
#ifdef _WIN32
        handle_ = CreateFileA(port_.c_str(), GENERIC_READ | GENERIC_WRITE,
                             0, nullptr, OPEN_EXISTING, 0, nullptr);
        if (handle_ == INVALID_HANDLE_VALUE) {
            throw std::runtime_error("Failed to open " + port_);
        }
        
        DCB dcb = {0};
        dcb.DCBlength = sizeof(DCB);
        GetCommState(handle_, &dcb);
        dcb.BaudRate = baudrate;
        dcb.ByteSize = 8;
        dcb.Parity = NOPARITY;
        dcb.StopBits = ONESTOPBIT;
        SetCommState(handle_, &dcb);
        
        COMMTIMEOUTS timeouts = {0};
        timeouts.ReadIntervalTimeout = 50;
        timeouts.ReadTotalTimeoutConstant = 100;
        timeouts.ReadTotalTimeoutMultiplier = 10;
        SetCommTimeouts(handle_, &timeouts);
#else
        handle_ = ::open(port_.c_str(), O_RDWR | O_NOCTTY);
        if (handle_ == -1) {
            throw std::runtime_error("Failed to open " + port_);
        }
        
        termios options;
        tcgetattr(handle_, &options);
        cfsetispeed(&options, B115200);
        cfsetospeed(&options, B115200);
        options.c_cflag &= ~PARENB;
        options.c_cflag &= ~CSTOPB;
        options.c_cflag &= ~CSIZE;
        options.c_cflag |= CS8;
        options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
        options.c_iflag &= ~(IXON | IXOFF | IXANY);
        options.c_oflag &= ~OPOST;
        options.c_cc[VMIN] = 0;
        options.c_cc[VTIME] = 10;
        tcsetattr(handle_, TCSANOW, &options);
        tcflush(handle_, TCIOFLUSH);
#endif
        
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    
    void close() {
        if (handle_ != INVALID_SERIAL) {
#ifdef _WIN32
            CloseHandle(handle_);
#else
            ::close(handle_);
#endif
            handle_ = INVALID_SERIAL;
        }
    }
    
    size_t write(const uint8_t* data, size_t len) {
#ifdef _WIN32
        DWORD written;
        if (!WriteFile(handle_, data, len, &written, nullptr)) {
            throw std::runtime_error("Write failed");
        }
        return written;
#else
        ssize_t n = ::write(handle_, data, len);
        if (n < 0) {
            throw std::runtime_error("Write failed");
        }
        return n;
#endif
    }
    
    size_t read(uint8_t* buffer, size_t len) {
#ifdef _WIN32
        DWORD read_bytes;
        if (!ReadFile(handle_, buffer, len, &read_bytes, nullptr)) {
            throw std::runtime_error("Read failed");
        }
        return read_bytes;
#else
        ssize_t n = ::read(handle_, buffer, len);
        if (n < 0) {
            throw std::runtime_error("Read failed");
        }
        return n;
#endif
    }
    
    bool isOpen() const {
        return handle_ != INVALID_SERIAL;
    }
};

/**
 * TPU Driver class
 */
class TPUDriver {
private:
    SerialPort serial_;
    
public:
    using Matrix = std::array<std::array<float, MATRIX_SIZE>, MATRIX_SIZE>;
    
    /**
     * Constructor
     */
    explicit TPUDriver(const std::string& port, int baudrate = 115200)
        : serial_(port, baudrate) {
        if (!serial_.isOpen()) {
            throw std::runtime_error("Failed to open serial port");
        }
        std::cout << "✓ Connected to TPU on " << port << std::endl;
    }
    
    /**
     * Destructor
     */
    ~TPUDriver() {
        std::cout << "✓ Disconnected from TPU" << std::endl;
    }
    
    /**
     * Write a single byte
     */
    void writeByte(uint8_t addr, uint8_t data) {
        uint8_t cmd = (addr < 128) 
            ? static_cast<uint8_t>(TPUCommand::WriteWeight)
            : static_cast<uint8_t>(TPUCommand::WriteActivation);
        
        uint8_t buffer[3] = {cmd, addr, data};
        serial_.write(buffer, 3);
        
        uint8_t ack;
        if (serial_.read(&ack, 1) != 1 || ack != 'K') {
            throw std::runtime_error("Failed to receive ACK");
        }
    }
    
    /**
     * Read a single byte
     */
    uint8_t readByte(uint8_t addr) {
        uint8_t cmd = static_cast<uint8_t>(TPUCommand::ReadResult);
        uint8_t buffer[2] = {cmd, addr};
        serial_.write(buffer, 2);
        
        uint8_t data;
        if (serial_.read(&data, 1) != 1) {
            throw std::runtime_error("Failed to read data");
        }
        return data;
    }
    
    /**
     * Write FP16 value
     */
    void writeFP16(uint8_t addr, float value) {
        if (addr % 2 != 0) {
            throw std::invalid_argument("FP16 address must be even");
        }
        
        uint16_t fp16 = FP16::fromFloat(value);
        writeByte(addr, fp16 & 0xFF);
        writeByte(addr + 1, (fp16 >> 8) & 0xFF);
    }
    
    /**
     * Read FP16 value
     */
    float readFP16(uint8_t addr) {
        if (addr % 2 != 0) {
            throw std::invalid_argument("FP16 address must be even");
        }
        
        uint8_t low = readByte(addr);
        uint8_t high = readByte(addr + 1);
        uint16_t fp16 = (static_cast<uint16_t>(high) << 8) | low;
        return FP16::toFloat(fp16);
    }
    
    /**
     * Write weight matrix
     */
    void writeWeights(const Matrix& weights) {
        std::cout << "Writing weights to TPU..." << std::endl;
        uint8_t addr = WEIGHT_BASE;
        
        for (size_t i = 0; i < MATRIX_SIZE; i++) {
            for (size_t j = 0; j < MATRIX_SIZE; j++) {
                writeFP16(addr, weights[i][j]);
                addr += 2;
            }
        }
        
        std::cout << "✓ Wrote " << MATRIX_SIZE * MATRIX_SIZE << " weights" << std::endl;
    }
    
    /**
     * Write activation matrix
     */
    void writeActivations(const Matrix& activations) {
        std::cout << "Writing activations to TPU..." << std::endl;
        uint8_t addr = ACTIVATION_BASE;
        
        for (size_t i = 0; i < MATRIX_SIZE; i++) {
            for (size_t j = 0; j < MATRIX_SIZE; j++) {
                writeFP16(addr, activations[i][j]);
                addr += 2;
            }
        }
        
        std::cout << "✓ Wrote " << MATRIX_SIZE * MATRIX_SIZE << " activations" << std::endl;
    }
    
    /**
     * Start computation
     */
    void start() {
        std::cout << "Starting computation..." << std::endl;
        uint8_t cmd = static_cast<uint8_t>(TPUCommand::Start);
        serial_.write(&cmd, 1);
        
        uint8_t ack;
        if (serial_.read(&ack, 1) != 1 || ack != 'K') {
            throw std::runtime_error("Failed to start TPU");
        }
    }
    
    /**
     * Get status
     */
    TPUStatus getStatus() {
        uint8_t cmd = static_cast<uint8_t>(TPUCommand::Status);
        serial_.write(&cmd, 1);
        
        uint8_t status_byte;
        if (serial_.read(&status_byte, 1) != 1) {
            throw std::runtime_error("Failed to read status");
        }
        
        return TPUStatus(status_byte);
    }
    
    /**
     * Wait until computation is done
     */
    void waitUntilDone(int timeout_ms = 10000) {
        auto start = std::chrono::steady_clock::now();
        
        while (true) {
            auto status = getStatus();
            if (status.done) {
                std::cout << "✓ Computation complete" << std::endl;
                return;
            }
            
            auto now = std::chrono::steady_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - start);
            if (elapsed.count() > timeout_ms) {
                throw std::runtime_error("Timeout waiting for TPU");
            }
            
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
    }
    
    /**
     * Read result matrix
     */
    Matrix readResults() {
        std::cout << "Reading results from TPU..." << std::endl;
        Matrix results;
        uint8_t addr = RESULT_BASE;
        
        for (size_t i = 0; i < MATRIX_SIZE; i++) {
            for (size_t j = 0; j < MATRIX_SIZE; j++) {
                results[i][j] = readFP16(addr);
                addr += 2;
            }
        }
        
        std::cout << "✓ Read " << MATRIX_SIZE * MATRIX_SIZE << " results" << std::endl;
        return results;
    }
    
    /**
     * Perform matrix multiplication
     */
    Matrix matrixMultiply(const Matrix& weights, const Matrix& activations) {
        writeWeights(weights);
        writeActivations(activations);
        start();
        waitUntilDone();
        return readResults();
    }
};

/**
 * Print matrix
 */
void printMatrix(const std::string& name, const TPUDriver::Matrix& matrix) {
    std::cout << name << ":" << std::endl;
    for (size_t i = 0; i < MATRIX_SIZE; i++) {
        for (size_t j = 0; j < MATRIX_SIZE; j++) {
            printf("%7.3f ", matrix[i][j]);
        }
        std::cout << std::endl;
    }
}

/**
 * Demo program
 */
int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <serial_port>" << std::endl;
        std::cerr << "Examples:" << std::endl;
        std::cerr << "  macOS:   " << argv[0] << " /dev/tty.usbserial-XXX" << std::endl;
        std::cerr << "  Linux:   " << argv[0] << " /dev/ttyUSB0" << std::endl;
        std::cerr << "  Windows: " << argv[0] << " COM3" << std::endl;
        return 1;
    }
    
    const std::string port = argv[1];
    
    std::cout << "=============================================================" << std::endl;
    std::cout << "TPU Driver Demo (C++)" << std::endl;
    std::cout << "=============================================================" << std::endl;
    
    try {
        // Initialize TPU
        TPUDriver tpu(port);
        
        // Check status
        auto status = tpu.getStatus();
        std::cout << "\nInitial status: " << status << std::endl;
        
        // Create test matrices
        std::cout << "\n=============================================================" << std::endl;
        std::cout << "Creating test matrices..." << std::endl;
        
        TPUDriver::Matrix weights, activations;
        for (size_t i = 0; i < MATRIX_SIZE; i++) {
            for (size_t j = 0; j < MATRIX_SIZE; j++) {
                weights[i][j] = (i + j) * 0.1f;
                activations[i][j] = (i - j) * 0.1f;
            }
        }
        
        // Perform computation
        std::cout << "\n=============================================================" << std::endl;
        std::cout << "Performing matrix multiplication on TPU..." << std::endl;
        
        auto start_time = std::chrono::high_resolution_clock::now();
        auto results = tpu.matrixMultiply(weights, activations);
        auto end_time = std::chrono::high_resolution_clock::now();
        
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            end_time - start_time);
        
        // Print results
        std::cout << "\n=============================================================" << std::endl;
        printMatrix("Weights", weights);
        std::cout << std::endl;
        printMatrix("Activations", activations);
        std::cout << std::endl;
        printMatrix("Results", results);
        
        std::cout << "\nElapsed time: " << elapsed.count() << " ms" << std::endl;
        
        // Calculate expected results for verification
        TPUDriver::Matrix expected;
        for (size_t i = 0; i < MATRIX_SIZE; i++) {
            for (size_t j = 0; j < MATRIX_SIZE; j++) {
                expected[i][j] = 0.0f;
                for (size_t k = 0; k < MATRIX_SIZE; k++) {
                    expected[i][j] += weights[i][k] * activations[k][j];
                }
            }
        }
        
        // Calculate error
        float max_error = 0.0f;
        float total_error = 0.0f;
        for (size_t i = 0; i < MATRIX_SIZE; i++) {
            for (size_t j = 0; j < MATRIX_SIZE; j++) {
                float error = std::abs(results[i][j] - expected[i][j]);
                max_error = std::max(max_error, error);
                total_error += error;
            }
        }
        float mean_error = total_error / (MATRIX_SIZE * MATRIX_SIZE);
        
        std::cout << "\n=============================================================" << std::endl;
        std::cout << "Verification:" << std::endl;
        std::cout << "Max error:  " << max_error << std::endl;
        std::cout << "Mean error: " << mean_error << std::endl;
        
        if (max_error < 0.1f) {
            std::cout << "✓ Results match (within approximate computing tolerance)" << std::endl;
        } else {
            std::cout << "✗ Results do not match!" << std::endl;
        }
        
        std::cout << "\n=============================================================" << std::endl;
        std::cout << "Demo complete!" << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "\nERROR: " << e.what() << std::endl;
        std::cerr << "\nTroubleshooting:" << std::endl;
        std::cerr << "1. Check that Basys3 is connected via USB" << std::endl;
        std::cerr << "2. Verify the correct COM port" << std::endl;
        std::cerr << "3. Make sure TPU bitstream is loaded on FPGA" << std::endl;
        std::cerr << "4. Check that switches SW[15:14] = 01 (UART mode)" << std::endl;
        return 1;
    }
    
    return 0;
}
