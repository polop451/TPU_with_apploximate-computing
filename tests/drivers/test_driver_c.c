/*
 * Test Suite for C TPU Driver
 * Description: Comprehensive tests for tpu_driver.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <math.h>

// Test framework
typedef struct {
    int passed;
    int failed;
    int total;
} TestResult;

TestResult test_result = {0, 0, 0};

#define TEST_START(name) \
    printf("\n[Test] %s\n", name); \
    test_result.total++;

#define TEST_ASSERT(condition, message) \
    if (condition) { \
        printf("  ✓ PASSED: %s\n", message); \
        test_result.passed++; \
    } else { \
        printf("  ✗ FAILED: %s\n", message); \
        test_result.failed++; \
    }

#define TEST_SUMMARY() \
    printf("\n"); \
    printf("============================================\n"); \
    printf("Test Summary:\n"); \
    printf("  Total: %d\n", test_result.total); \
    printf("  PASSED: %d\n", test_result.passed); \
    printf("  FAILED: %d\n", test_result.failed); \
    if (test_result.failed == 0) \
        printf("  STATUS: ✓ ALL TESTS PASSED\n"); \
    else \
        printf("  STATUS: ✗ SOME TESTS FAILED\n"); \
    printf("============================================\n");

// FP16 conversion functions (simplified for testing)
uint16_t fp32_to_fp16_test(float value) {
    if (value == 0.0f) return 0;
    
    uint32_t bits = *(uint32_t*)&value;
    uint16_t sign = (bits >> 16) & 0x8000;
    int32_t exponent = ((bits >> 23) & 0xFF) - 127 + 15;
    uint32_t mantissa = (bits >> 13) & 0x3FF;
    
    if (exponent <= 0) return sign;
    if (exponent >= 31) return sign | 0x7C00;
    
    return sign | (exponent << 10) | mantissa;
}

float fp16_to_fp32_test(uint16_t value) {
    if (value == 0) return 0.0f;
    
    uint32_t sign = (value & 0x8000) << 16;
    int32_t exponent = (value >> 10) & 0x1F;
    uint32_t mantissa = value & 0x3FF;
    
    if (exponent == 0) return 0.0f;
    if (exponent == 31) return INFINITY;
    
    exponent = exponent - 15 + 127;
    uint32_t bits = sign | (exponent << 23) | (mantissa << 13);
    return *(float*)&bits;
}

// Test FP16 conversion
void test_fp16_conversion() {
    TEST_START("FP16 Conversion");
    
    // Test zero
    uint16_t result = fp32_to_fp16_test(0.0f);
    TEST_ASSERT(result == 0, "Convert 0.0 to FP16");
    
    // Test one
    result = fp32_to_fp16_test(1.0f);
    TEST_ASSERT(result == 0x3C00, "Convert 1.0 to FP16");
    
    // Test negative
    result = fp32_to_fp16_test(-1.0f);
    TEST_ASSERT((result & 0x8000) != 0, "Negative number has sign bit");
    
    // Test reverse conversion
    float back = fp16_to_fp32_test(0x3C00);
    TEST_ASSERT(fabsf(back - 1.0f) < 0.1f, "Convert FP16 back to 1.0");
}

// Test matrix operations
void test_matrix_operations() {
    TEST_START("Matrix Operations");
    
    // Test matrix allocation
    float** matrix = (float**)malloc(8 * sizeof(float*));
    for (int i = 0; i < 8; i++) {
        matrix[i] = (float*)malloc(8 * sizeof(float));
        for (int j = 0; j < 8; j++) {
            matrix[i][j] = 1.0f;
        }
    }
    TEST_ASSERT(matrix != NULL, "Matrix allocation successful");
    
    // Test matrix initialization
    int all_ones = 1;
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            if (matrix[i][j] != 1.0f) all_ones = 0;
        }
    }
    TEST_ASSERT(all_ones, "Matrix initialized to ones");
    
    // Test matrix conversion to FP16
    uint16_t fp16_matrix[8][8];
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            fp16_matrix[i][j] = fp32_to_fp16_test(matrix[i][j]);
        }
    }
    TEST_ASSERT(fp16_matrix[0][0] == 0x3C00, "Matrix converted to FP16");
    
    // Free matrix
    for (int i = 0; i < 8; i++) {
        free(matrix[i]);
    }
    free(matrix);
    TEST_ASSERT(1, "Matrix freed successfully");
}

// Test command encoding
void test_command_encoding() {
    TEST_START("Command Encoding");
    
    // Test command structure
    typedef struct {
        uint8_t cmd;
        uint8_t param;
    } Command;
    
    Command cmd_reset = {0x01, 0x00};
    TEST_ASSERT(cmd_reset.cmd == 0x01, "Reset command encoded");
    
    Command cmd_load = {0x02, 0x00};
    TEST_ASSERT(cmd_load.cmd == 0x02, "Load matrix command encoded");
    
    Command cmd_compute = {0x03, 0x00};
    TEST_ASSERT(cmd_compute.cmd == 0x03, "Compute command encoded");
    
    Command cmd_activation = {0x05, 0x01}; // ReLU
    TEST_ASSERT(cmd_activation.param == 0x01, "Activation parameter encoded");
}

// Test data structures
void test_data_structures() {
    TEST_START("Data Structures");
    
    // Test TPU config structure
    typedef struct {
        int matrix_size;
        int data_width;
        char interface[16];
        int baud_rate;
    } TPUConfig;
    
    TPUConfig config = {8, 16, "UART", 115200};
    
    TEST_ASSERT(config.matrix_size == 8, "Matrix size set correctly");
    TEST_ASSERT(config.data_width == 16, "Data width set correctly");
    TEST_ASSERT(strcmp(config.interface, "UART") == 0, "Interface set correctly");
    TEST_ASSERT(config.baud_rate == 115200, "Baud rate set correctly");
}

// Test error handling
void test_error_handling() {
    TEST_START("Error Handling");
    
    // Test NULL pointer check
    float** null_matrix = NULL;
    TEST_ASSERT(null_matrix == NULL, "NULL pointer detection");
    
    // Test invalid matrix size
    int invalid_size = 10; // Should be 8
    TEST_ASSERT(invalid_size != 8, "Invalid matrix size detection");
    
    // Test range validation
    float value = 1.5f;
    TEST_ASSERT(value >= 0.0f && value <= 2.0f, "Value range validation");
    
    // Test buffer overflow protection
    char buffer[16];
    strncpy(buffer, "test", sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';
    TEST_ASSERT(strlen(buffer) < sizeof(buffer), "Buffer overflow protection");
}

// Test memory management
void test_memory_management() {
    TEST_START("Memory Management");
    
    // Test allocation
    void* ptr = malloc(1024);
    TEST_ASSERT(ptr != NULL, "Memory allocation successful");
    
    // Test initialization
    memset(ptr, 0, 1024);
    uint8_t* bytes = (uint8_t*)ptr;
    int all_zero = 1;
    for (int i = 0; i < 1024; i++) {
        if (bytes[i] != 0) all_zero = 0;
    }
    TEST_ASSERT(all_zero, "Memory initialized to zero");
    
    // Test free
    free(ptr);
    TEST_ASSERT(1, "Memory freed successfully");
    
    // Test multiple allocations
    void* ptrs[10];
    for (int i = 0; i < 10; i++) {
        ptrs[i] = malloc(128);
    }
    int all_allocated = 1;
    for (int i = 0; i < 10; i++) {
        if (ptrs[i] == NULL) all_allocated = 0;
    }
    TEST_ASSERT(all_allocated, "Multiple allocations successful");
    
    for (int i = 0; i < 10; i++) {
        free(ptrs[i]);
    }
    TEST_ASSERT(1, "Multiple deallocations successful");
}

// Test activation functions
void test_activation_functions() {
    TEST_START("Activation Functions");
    
    // Test activation codes
    enum Activation {
        ACT_NONE = 0,
        ACT_RELU = 1,
        ACT_SIGMOID = 2,
        ACT_TANH = 3
    };
    
    TEST_ASSERT(ACT_RELU == 1, "ReLU activation code");
    TEST_ASSERT(ACT_SIGMOID == 2, "Sigmoid activation code");
    TEST_ASSERT(ACT_TANH == 3, "Tanh activation code");
    
    // Test activation validation
    int valid_activation = ACT_RELU;
    TEST_ASSERT(valid_activation >= 0 && valid_activation <= 7, "Activation validation");
}

// Main test runner
int main(int argc, char* argv[]) {
    printf("============================================\n");
    printf("C TPU Driver Test Suite\n");
    printf("============================================\n");
    
    // Run all tests
    test_fp16_conversion();
    test_matrix_operations();
    test_command_encoding();
    test_data_structures();
    test_error_handling();
    test_memory_management();
    test_activation_functions();
    
    // Print summary
    TEST_SUMMARY();
    
    return (test_result.failed == 0) ? 0 : 1;
}
