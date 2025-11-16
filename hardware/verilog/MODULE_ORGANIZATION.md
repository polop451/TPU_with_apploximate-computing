# Verilog Module Organization

## Overview
The Verilog modules have been reorganized to follow the principle of **one file per module**. This improves code maintainability, reusability, and makes the project structure clearer.

## Module Separation Summary

### 1. Memory Controller Modules
**Original file:** `memory_controller.v` (contained 3 modules)

**Separated into:**
- `memory_controller.v` - Main memory controller with double buffering
- `weight_buffer.v` - Specialized weight storage buffer
- `activation_buffer.v` - Specialized activation storage buffer

### 2. I/O Interface Modules
**Original file:** `io_interfaces.v` (contained 2 modules)

**Separated into:**
- `spi_interface.v` - SPI interface for TPU communication
- `button_switch_interface.v` - Basys3 button and switch interface
- `io_interfaces.v` - Kept for backward compatibility (now includes header comment)

### 3. UART Interface Modules
**Original file:** `uart_interface.v` (contained 3 modules)

**Separated into:**
- `uart_interface.v` - Main UART interface with command processor
- `uart_rx.v` - UART receiver module
- `uart_tx.v` - UART transmitter module

### 4. FP16 Approximate Multiplier Modules
**Original file:** `fp16_approximate_multiplier.v` (contained 2 modules)

**Separated into:**
- `fp16_approximate_multiplier.v` - FP16 approximate multiplier
- `fp16_approximate_adder.v` - FP16 approximate adder

### 5. FP16 MAC Unit Modules
**Original file:** `fp16_approx_mac_unit.v` (contained 2 modules)

**Separated into:**
- `fp16_approx_mac_unit.v` - Approximate FP16 MAC unit
- `fp16_exact_mac_unit.v` - Exact FP16 MAC unit (for comparison)

### 6. Activation Function Modules
**Original file:** `activation_functions.v` (contained 3 modules)

**Separated into:**
- `activation_functions.v` - Main activation functions (ReLU, Sigmoid, Tanh)
- `activation_layer.v` - Apply activation to all outputs
- `sigmoid_lut.v` - LUT-based sigmoid implementation

### 7. FP16 Systolic Array Modules
**Original file:** `fp16_approx_systolic_array.v` (contained 2 modules)

**Separated into:**
- `fp16_approx_systolic_array.v` - 8x8 FP16 approximate systolic array
- `fp16_configurable_systolic_array.v` - Configurable size systolic array

## Complete Module List

### Core TPU Modules
1. `tpu_top.v` - Top-level TPU module with systolic array
2. `tpu_simple.v` - Simplified TPU for testing
3. `tpu_controller.v` - TPU control unit
4. `systolic_array.v` - 4x4 systolic array
5. `mac_unit.v` - Multiply-accumulate unit

### Memory Modules
6. `memory_controller.v` - Main memory controller
7. `weight_buffer.v` - Weight storage buffer
8. `activation_buffer.v` - Activation storage buffer

### I/O Interface Modules
9. `uart_interface.v` - UART interface with command processor
10. `uart_rx.v` - UART receiver
11. `uart_tx.v` - UART transmitter
12. `spi_interface.v` - SPI interface
13. `button_switch_interface.v` - Button and switch interface
14. `io_interfaces.v` - I/O interfaces collection (legacy)

### FP16 Approximate Computing Modules
15. `fp16_approximate_multiplier.v` - FP16 approximate multiplier
16. `fp16_approximate_adder.v` - FP16 approximate adder
17. `fp16_approx_mac_unit.v` - Approximate FP16 MAC unit
18. `fp16_exact_mac_unit.v` - Exact FP16 MAC unit
19. `fp16_approx_systolic_array.v` - FP16 systolic array

### Activation Functions
20. `activation_functions.v` - ReLU, sigmoid, tanh functions
21. `activation_layer.v` - Apply activation to all outputs
22. `sigmoid_lut.v` - LUT-based sigmoid implementation

### Top-Level Integration Modules
23. `tpu_top_with_io.v` - TPU with I/O interfaces
24. `tpu_top_with_io_complete.v` - Complete TPU with all I/O

### FP16 Approximate Systolic Arrays
25. `fp16_approx_systolic_array.v` - 8x8 FP16 systolic array
26. `fp16_configurable_systolic_array.v` - Configurable size systolic array

### Testbench Modules
27. `tpu_testbench.v` - Main TPU testbench
28. `tpu_simple_testbench.v` - Simplified TPU testbench
29. `fp16_approx_tpu_testbench.v` - FP16 approximate TPU testbench
30. `activation_test.v` - Activation functions testbench

## Benefits of This Organization

1. **Modularity**: Each module is in its own file, making it easier to locate and modify specific functionality
2. **Reusability**: Modules can be easily reused in different projects
3. **Version Control**: Changes to one module don't affect others, making git diffs cleaner
4. **Synthesis**: Easier to synthesize individual modules for testing
5. **Collaboration**: Multiple developers can work on different modules without conflicts
6. **Documentation**: Each file can have its own detailed documentation

## Backward Compatibility

The original multi-module files (`io_interfaces.v`) have been updated with header comments explaining the reorganization. The separated modules maintain the same interfaces and functionality as the original implementations.

## Usage Notes

When using these modules in your designs:

1. **Include all necessary files** in your synthesis/simulation tool
2. **Check module dependencies** - some modules instantiate others
3. **Use consistent file naming** when creating new modules
4. **Update testbenches** to reference the correct file names if needed

## Module Dependencies

### Core Dependencies
- `tpu_top.v` depends on:
  - `systolic_array.v`
  - `weight_buffer.v`
  - `activation_buffer.v`
  - `tpu_controller.v`

- `systolic_array.v` depends on:
  - `mac_unit.v`

### FP16 Dependencies
- `fp16_approx_mac_unit.v` depends on:
  - `fp16_approximate_multiplier.v`
  - `fp16_approximate_adder.v`

- `fp16_exact_mac_unit.v` depends on:
  - `fp16_approximate_multiplier.v`
  - `fp16_approximate_adder.v`

### UART Dependencies
- `uart_interface.v` depends on:
  - `uart_rx.v`
  - `uart_tx.v`

## File Statistics

- **Total Verilog files**: 30
- **Module files**: 27
- **Testbench files**: 3
- **New files created**: 11
- **Files modified**: 7

---
**Last Updated**: November 17, 2025
**Project**: TPU with Approximate Computing
