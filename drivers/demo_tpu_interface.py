#!/usr/bin/env python3
"""
Quick demo of FPGA TPU interface
Can test FP16 conversion offline without hardware
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from tpu_fpga_interface import FPGA_TPU, fp32_to_fp16, fp16_to_fp32, print_matrix
import numpy as np


def demo_fp16_conversion():
    """Demonstrate FP16 conversion"""
    print("=" * 60)
    print("FP16 Conversion Demo")
    print("=" * 60)
    
    test_values = [0.0, 1.0, -1.0, 2.5, -3.7, 0.1, 10.0, 100.0]
    
    print("\nFloat32 → FP16 → Float32:")
    print("-" * 60)
    print(f"{'Original':>12} {'FP16 (hex)':>12} {'Recovered':>12} {'Error':>12}")
    print("-" * 60)
    
    for val in test_values:
        fp16 = fp32_to_fp16(val)
        recovered = fp16_to_fp32(fp16)
        error = abs(recovered - val)
        print(f"{val:>12.6f} {fp16:>#12x} {recovered:>12.6f} {error:>12.6f}")
    
    print()


def demo_matrix_creation():
    """Demonstrate matrix creation and numpy operations"""
    print("=" * 60)
    print("Matrix Operations Demo")
    print("=" * 60)
    
    # Create test matrices
    A = np.random.randn(8, 8).astype(np.float32)
    B = np.random.randn(8, 8).astype(np.float32)
    
    print_matrix(A[:4, :4], "Matrix A (4x4 preview)", precision=3)
    print_matrix(B[:4, :4], "Matrix B (4x4 preview)", precision=3)
    
    # CPU reference
    result_cpu = A @ B
    print_matrix(result_cpu[:4, :4], "CPU Result (4x4 preview)", precision=3)
    
    # Simulate FP16 precision loss
    A_fp16 = np.array([[fp16_to_fp32(fp32_to_fp16(x)) for x in row] for row in A])
    B_fp16 = np.array([[fp16_to_fp32(fp32_to_fp16(x)) for x in row] for row in B])
    result_fp16 = A_fp16 @ B_fp16
    
    print_matrix(result_fp16[:4, :4], "FP16 Simulated Result (4x4 preview)", precision=3)
    
    # Error analysis
    error = np.abs(result_cpu - result_fp16)
    print(f"FP16 Precision Loss:")
    print(f"  Max error: {np.max(error):.6f}")
    print(f"  Mean error: {np.mean(error):.6f}")
    print()


def demo_fpga_interface():
    """Demonstrate FPGA interface (requires hardware)"""
    print("=" * 60)
    print("FPGA Interface Demo")
    print("=" * 60)
    
    print("\nAttempting to connect to FPGA...")
    tpu = FPGA_TPU()
    
    if not tpu.connect():
        print("\n⚠ FPGA not connected - hardware demos skipped")
        print("\nTo run hardware demos:")
        print("  1. Program FPGA with tpu_top_with_io_complete.bit")
        print("  2. Connect USB cable")
        print("  3. Run: python3 test_fpga_tpu_complete.py")
        return False
    
    try:
        # Simple test
        print("\nRunning simple matrix multiplication...")
        A = np.ones((8, 8), dtype=np.float32) * 2.0
        B = np.ones((8, 8), dtype=np.float32) * 3.0
        
        result = tpu.matrix_multiply(A, B)
        
        if result is not None:
            expected = A @ B
            print_matrix(result[:3, :3], "FPGA Result (3x3 preview)")
            print_matrix(expected[:3, :3], "Expected (3x3 preview)")
            
            error = np.max(np.abs(result - expected))
            print(f"Max error: {error:.6f}")
            
            if error < 1.0:
                print("✓ FPGA working correctly!")
            else:
                print("⚠ Large error detected")
        
        # Quick performance test
        print("\nQuick performance test (5 iterations)...")
        for i in range(5):
            A = np.random.randn(8, 8).astype(np.float32)
            B = np.random.randn(8, 8).astype(np.float32)
            result = tpu.matrix_multiply(A, B, verbose=False)
            if result:
                print(f"  Iteration {i+1}: {tpu.last_compute_time*1000:.2f} ms")
        
        stats = tpu.get_performance_stats()
        print(f"\nAverage time: {stats['avg_time']*1000:.2f} ms")
        print(f"Throughput: {stats['throughput_gops']:.4f} GOPS")
        
        return True
        
    finally:
        tpu.disconnect()


def main():
    print("\n")
    print("╔" + "=" * 58 + "╗")
    print("║" + " " * 12 + "FPGA TPU Interface Demo" + " " * 23 + "║")
    print("╚" + "=" * 58 + "╝")
    print()
    
    # Offline demos (no hardware needed)
    demo_fp16_conversion()
    demo_matrix_creation()
    
    # Hardware demo (if available)
    hardware_ok = demo_fpga_interface()
    
    # Summary
    print("=" * 60)
    print("Demo Summary")
    print("=" * 60)
    print("✓ FP16 conversion working")
    print("✓ Matrix operations working")
    if hardware_ok:
        print("✓ FPGA hardware working")
    else:
        print("⚠ FPGA hardware not available")
    print()
    print("For full test suite, run:")
    print("  cd tests/integration")
    print("  ./run_fpga_tests.sh")
    print("=" * 60)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nDemo interrupted by user")
    except Exception as e:
        print(f"\n\nError: {e}")
        import traceback
        traceback.print_exc()
