#!/usr/bin/env python3
"""
Comprehensive Test Suite for FPGA TPU
Tests functionality, accuracy, and performance
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../drivers'))

import numpy as np
import time
from tpu_fpga_interface import FPGA_TPU, fp32_to_fp16, fp16_to_fp32, print_matrix
import argparse


class TestResults:
    """Track test results"""
    def __init__(self):
        self.tests_run = 0
        self.tests_passed = 0
        self.tests_failed = 0
        self.failures = []
    
    def add_result(self, test_name: str, passed: bool, message: str = ""):
        self.tests_run += 1
        if passed:
            self.tests_passed += 1
            print(f"  ✓ {test_name}")
        else:
            self.tests_failed += 1
            self.failures.append((test_name, message))
            print(f"  ✗ {test_name}: {message}")
    
    def print_summary(self):
        print("\n" + "=" * 70)
        print("TEST SUMMARY")
        print("=" * 70)
        print(f"Total tests: {self.tests_run}")
        print(f"Passed: {self.tests_passed} ({100*self.tests_passed/self.tests_run:.1f}%)")
        print(f"Failed: {self.tests_failed}")
        
        if self.failures:
            print("\nFailed tests:")
            for name, msg in self.failures:
                print(f"  - {name}: {msg}")
        
        return self.tests_failed == 0


def test_fp16_conversion():
    """Test FP16 conversion functions"""
    print("\n" + "=" * 70)
    print("Test: FP16 Conversion")
    print("=" * 70)
    
    results = TestResults()
    
    # Test cases
    test_values = [
        0.0, 1.0, -1.0, 0.5, -0.5,
        2.0, -2.0, 10.0, -10.0,
        0.1, 0.01, 0.001,
        100.0, 1000.0,
        np.inf, -np.inf
    ]
    
    for val in test_values:
        fp16 = fp32_to_fp16(val)
        recovered = fp16_to_fp32(fp16)
        
        # Check if within reasonable tolerance for FP16
        if np.isfinite(val):
            error = abs(recovered - val)
            tolerance = max(abs(val) * 0.001, 0.001)  # 0.1% or 0.001
            passed = error < tolerance
            results.add_result(
                f"Convert {val:.6f}",
                passed,
                f"Error: {error:.6f}, Got: {recovered:.6f}"
            )
        else:
            # For infinity
            passed = (np.isinf(val) and np.isinf(recovered) and 
                     np.sign(val) == np.sign(recovered))
            results.add_result(f"Convert {val}", passed)
    
    results.print_summary()
    return results.tests_failed == 0


def test_basic_matrix_multiply(tpu: FPGA_TPU):
    """Test basic matrix multiplication"""
    print("\n" + "=" * 70)
    print("Test: Basic Matrix Multiplication")
    print("=" * 70)
    
    results = TestResults()
    
    # Test 1: Identity matrix
    A = np.eye(8, dtype=np.float32)
    B = np.random.randn(8, 8).astype(np.float32)
    
    result = tpu.matrix_multiply(A, B, verbose=False)
    if result is not None:
        error = np.max(np.abs(result - B))
        passed = error < 0.1
        results.add_result("Identity matrix", passed, f"Max error: {error:.6f}")
    else:
        results.add_result("Identity matrix", False, "Failed to compute")
    
    # Test 2: Zeros
    A = np.zeros((8, 8), dtype=np.float32)
    B = np.random.randn(8, 8).astype(np.float32)
    
    result = tpu.matrix_multiply(A, B, verbose=False)
    if result is not None:
        error = np.max(np.abs(result))
        passed = error < 0.1
        results.add_result("Zero matrix", passed, f"Max value: {error:.6f}")
    else:
        results.add_result("Zero matrix", False, "Failed to compute")
    
    # Test 3: Ones
    A = np.ones((8, 8), dtype=np.float32)
    B = np.ones((8, 8), dtype=np.float32)
    
    result = tpu.matrix_multiply(A, B, verbose=False)
    if result is not None:
        expected = np.ones((8, 8)) * 8.0
        error = np.max(np.abs(result - expected))
        passed = error < 0.5
        results.add_result("Ones matrix", passed, f"Max error: {error:.6f}")
    else:
        results.add_result("Ones matrix", False, "Failed to compute")
    
    # Test 4: Simple values
    A = np.ones((8, 8), dtype=np.float32) * 2.0
    B = np.ones((8, 8), dtype=np.float32) * 3.0
    
    result = tpu.matrix_multiply(A, B, verbose=False)
    if result is not None:
        expected = np.ones((8, 8)) * 48.0  # 2 * 3 * 8
        error = np.max(np.abs(result - expected))
        passed = error < 2.0
        results.add_result("Simple multiplication", passed, f"Max error: {error:.6f}")
    else:
        results.add_result("Simple multiplication", False, "Failed to compute")
    
    results.print_summary()
    return results.tests_failed == 0


def test_random_matrices(tpu: FPGA_TPU, num_tests: int = 20):
    """Test with random matrices"""
    print("\n" + "=" * 70)
    print(f"Test: Random Matrices ({num_tests} iterations)")
    print("=" * 70)
    
    results = TestResults()
    
    errors = []
    for i in range(num_tests):
        # Generate random matrices with reasonable values
        A = np.random.randn(8, 8).astype(np.float32) * 0.5
        B = np.random.randn(8, 8).astype(np.float32) * 0.5
        
        result = tpu.matrix_multiply(A, B, verbose=False)
        
        if result is not None:
            expected = A @ B
            error = np.max(np.abs(result - expected))
            mean_error = np.mean(np.abs(result - expected))
            errors.append(error)
            
            # Approximate computing tolerance
            passed = error < 1.0
            results.add_result(
                f"Random test {i+1}",
                passed,
                f"Max error: {error:.4f}, Mean: {mean_error:.4f}"
            )
        else:
            results.add_result(f"Random test {i+1}", False, "Failed to compute")
    
    if errors:
        print(f"\nError statistics:")
        print(f"  Mean max error: {np.mean(errors):.6f}")
        print(f"  Max error: {np.max(errors):.6f}")
        print(f"  Min error: {np.min(errors):.6f}")
        print(f"  Std dev: {np.std(errors):.6f}")
    
    results.print_summary()
    return results.tests_failed == 0


def test_edge_cases(tpu: FPGA_TPU):
    """Test edge cases"""
    print("\n" + "=" * 70)
    print("Test: Edge Cases")
    print("=" * 70)
    
    results = TestResults()
    
    # Test 1: Very small values
    A = np.ones((8, 8), dtype=np.float32) * 0.001
    B = np.ones((8, 8), dtype=np.float32) * 0.001
    
    result = tpu.matrix_multiply(A, B, verbose=False)
    if result is not None:
        expected = np.ones((8, 8)) * 0.008  # 0.001 * 0.001 * 8
        error = np.max(np.abs(result - expected))
        passed = error < 0.01
        results.add_result("Very small values", passed, f"Max error: {error:.6f}")
    else:
        results.add_result("Very small values", False, "Failed to compute")
    
    # Test 2: Large values (but within FP16 range)
    A = np.ones((8, 8), dtype=np.float32) * 10.0
    B = np.ones((8, 8), dtype=np.float32) * 10.0
    
    result = tpu.matrix_multiply(A, B, verbose=False)
    if result is not None:
        expected = np.ones((8, 8)) * 800.0  # 10 * 10 * 8
        error = np.max(np.abs(result - expected))
        passed = error < 50.0
        results.add_result("Large values", passed, f"Max error: {error:.6f}")
    else:
        results.add_result("Large values", False, "Failed to compute")
    
    # Test 3: Mixed signs
    A = np.random.randn(8, 8).astype(np.float32)
    B = -np.random.randn(8, 8).astype(np.float32)
    
    result = tpu.matrix_multiply(A, B, verbose=False)
    if result is not None:
        expected = A @ B
        error = np.max(np.abs(result - expected))
        passed = error < 1.0
        results.add_result("Mixed signs", passed, f"Max error: {error:.6f}")
    else:
        results.add_result("Mixed signs", False, "Failed to compute")
    
    # Test 4: Diagonal matrix
    A = np.diag(np.arange(1, 9, dtype=np.float32))
    B = np.ones((8, 8), dtype=np.float32)
    
    result = tpu.matrix_multiply(A, B, verbose=False)
    if result is not None:
        expected = A @ B
        error = np.max(np.abs(result - expected))
        passed = error < 0.5
        results.add_result("Diagonal matrix", passed, f"Max error: {error:.6f}")
    else:
        results.add_result("Diagonal matrix", False, "Failed to compute")
    
    results.print_summary()
    return results.tests_failed == 0


def benchmark_performance(tpu: FPGA_TPU, num_iterations: int = 100):
    """Benchmark TPU performance"""
    print("\n" + "=" * 70)
    print(f"Performance Benchmark ({num_iterations} iterations)")
    print("=" * 70)
    
    # Reset statistics
    tpu.total_computes = 0
    tpu.total_time = 0.0
    
    print(f"Running {num_iterations} matrix multiplications...")
    
    times = []
    failed = 0
    
    start_total = time.time()
    for i in range(num_iterations):
        A = np.random.randn(8, 8).astype(np.float32)
        B = np.random.randn(8, 8).astype(np.float32)
        
        start = time.time()
        result = tpu.matrix_multiply(A, B, verbose=False)
        elapsed = time.time() - start
        
        if result is not None:
            times.append(elapsed)
            if (i + 1) % 10 == 0:
                print(f"  Progress: {i+1}/{num_iterations} ({100*(i+1)/num_iterations:.0f}%)")
        else:
            failed += 1
    
    total_time = time.time() - start_total
    
    # Statistics
    print("\n" + "-" * 70)
    print("Performance Results:")
    print("-" * 70)
    print(f"Successful operations: {len(times)}/{num_iterations}")
    print(f"Failed operations: {failed}")
    
    if times:
        print(f"\nTiming statistics:")
        print(f"  Mean time: {np.mean(times)*1000:.2f} ms")
        print(f"  Median time: {np.median(times)*1000:.2f} ms")
        print(f"  Min time: {np.min(times)*1000:.2f} ms")
        print(f"  Max time: {np.max(times)*1000:.2f} ms")
        print(f"  Std dev: {np.std(times)*1000:.2f} ms")
        
        # Throughput
        ops_per_matmul = 8 * 8 * 8  # 512 MAC operations
        total_ops = ops_per_matmul * len(times)
        throughput_ops = total_ops / total_time
        throughput_mops = throughput_ops / 1e6
        throughput_gops = throughput_ops / 1e9
        
        print(f"\nThroughput:")
        print(f"  {throughput_mops:.2f} MOPS (Million Operations/Second)")
        print(f"  {throughput_gops:.4f} GOPS (Giga Operations/Second)")
        
        # Theoretical peak
        clock_freq = 100e6  # 100 MHz
        macs_per_cycle = 64  # 8x8 systolic array
        cycles_per_matmul = 8 + 2  # 8 compute cycles + 2 pipeline
        theoretical_time = cycles_per_matmul / clock_freq
        theoretical_gops = (clock_freq * macs_per_cycle) / 1e9
        
        print(f"\nTheoretical analysis:")
        print(f"  Clock frequency: {clock_freq/1e6:.0f} MHz")
        print(f"  MACs per cycle: {macs_per_cycle}")
        print(f"  Theoretical time per matmul: {theoretical_time*1e6:.2f} μs")
        print(f"  Theoretical peak: {theoretical_gops:.2f} GOPS")
        print(f"  Efficiency: {100*throughput_gops/theoretical_gops:.1f}%")
        
        # Compare with CPU
        print(f"\nCPU comparison:")
        A_test = np.random.randn(8, 8).astype(np.float32)
        B_test = np.random.randn(8, 8).astype(np.float32)
        
        cpu_times = []
        for _ in range(100):
            start = time.time()
            _ = A_test @ B_test
            cpu_times.append(time.time() - start)
        
        cpu_mean = np.mean(cpu_times)
        speedup = cpu_mean / np.mean(times)
        
        print(f"  CPU time: {cpu_mean*1e6:.2f} μs")
        print(f"  FPGA time: {np.mean(times)*1e6:.2f} μs")
        print(f"  Speedup: {speedup:.2f}x")
    
    return failed == 0


def test_accuracy_analysis(tpu: FPGA_TPU):
    """Analyze accuracy of approximate computing"""
    print("\n" + "=" * 70)
    print("Accuracy Analysis")
    print("=" * 70)
    
    num_tests = 50
    errors_absolute = []
    errors_relative = []
    
    print(f"Running {num_tests} accuracy tests...")
    
    for i in range(num_tests):
        A = np.random.randn(8, 8).astype(np.float32) * 2.0
        B = np.random.randn(8, 8).astype(np.float32) * 2.0
        
        result = tpu.matrix_multiply(A, B, verbose=False)
        
        if result is not None:
            expected = A @ B
            
            abs_error = np.abs(result - expected)
            errors_absolute.extend(abs_error.flatten())
            
            # Relative error (avoid division by very small numbers)
            mask = np.abs(expected) > 0.01
            if np.any(mask):
                rel_error = np.abs((result[mask] - expected[mask]) / expected[mask])
                errors_relative.extend(rel_error.flatten())
    
    print("\nAbsolute Error Statistics:")
    print(f"  Mean: {np.mean(errors_absolute):.6f}")
    print(f"  Median: {np.median(errors_absolute):.6f}")
    print(f"  Max: {np.max(errors_absolute):.6f}")
    print(f"  Min: {np.min(errors_absolute):.6f}")
    print(f"  95th percentile: {np.percentile(errors_absolute, 95):.6f}")
    print(f"  99th percentile: {np.percentile(errors_absolute, 99):.6f}")
    
    if errors_relative:
        print("\nRelative Error Statistics:")
        print(f"  Mean: {np.mean(errors_relative)*100:.2f}%")
        print(f"  Median: {np.median(errors_relative)*100:.2f}%")
        print(f"  Max: {np.max(errors_relative)*100:.2f}%")
        print(f"  95th percentile: {np.percentile(errors_relative, 95)*100:.2f}%")
    
    # Accuracy grade
    mean_abs_error = np.mean(errors_absolute)
    if mean_abs_error < 0.01:
        grade = "Excellent"
    elif mean_abs_error < 0.1:
        grade = "Good"
    elif mean_abs_error < 1.0:
        grade = "Acceptable"
    else:
        grade = "Poor"
    
    print(f"\nAccuracy Grade: {grade}")
    
    return True


def main():
    parser = argparse.ArgumentParser(description='FPGA TPU Comprehensive Test Suite')
    parser.add_argument('--port', type=str, help='Serial port (e.g., /dev/ttyUSB0, COM3)')
    parser.add_argument('--skip-connection', action='store_true', 
                       help='Skip connection tests (for offline FP16 conversion tests)')
    parser.add_argument('--quick', action='store_true',
                       help='Run quick tests only')
    args = parser.parse_args()
    
    print("=" * 70)
    print("FPGA TPU - COMPREHENSIVE TEST SUITE")
    print("=" * 70)
    
    # Test FP16 conversion (no hardware needed)
    test_fp16_conversion()
    
    if args.skip_connection:
        print("\nSkipping hardware tests (--skip-connection)")
        return
    
    # Connect to FPGA
    print("\n" + "=" * 70)
    print("Connecting to FPGA...")
    print("=" * 70)
    
    tpu = FPGA_TPU(port=args.port)
    if not tpu.connect():
        print("\n✗ Failed to connect to FPGA")
        print("\nTroubleshooting:")
        print("  1. Check FPGA is powered and programmed with tpu_top_with_io_complete.bit")
        print("  2. Verify USB cable connection")
        print("  3. Check COM port in Device Manager (Windows) or ls /dev/tty* (Linux/Mac)")
        print("  4. Try specifying port with --port option")
        return 1
    
    try:
        # Run test suite
        all_passed = True
        
        all_passed &= test_basic_matrix_multiply(tpu)
        
        if not args.quick:
            all_passed &= test_edge_cases(tpu)
            all_passed &= test_random_matrices(tpu, num_tests=20)
            all_passed &= test_accuracy_analysis(tpu)
            all_passed &= benchmark_performance(tpu, num_iterations=100)
        else:
            print("\n(Quick mode: Skipping extended tests)")
            all_passed &= benchmark_performance(tpu, num_iterations=10)
        
        # Final summary
        print("\n" + "=" * 70)
        if all_passed:
            print("✓ ALL TESTS PASSED")
        else:
            print("✗ SOME TESTS FAILED")
        print("=" * 70)
        
        return 0 if all_passed else 1
        
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        return 1
    finally:
        tpu.disconnect()


if __name__ == "__main__":
    sys.exit(main())
