#!/usr/bin/env python3
"""
FPGA TPU Interface via UART
Connects to Basys3 board running tpu_top_with_io_complete.v
Supports matrix operations and performance benchmarking
"""

import serial
import serial.tools.list_ports
import numpy as np
import struct
import time
from typing import Tuple, Optional, List
from dataclasses import dataclass
import sys

# FP16 helper functions
def fp32_to_fp16(val: float) -> int:
    """Convert float32 to IEEE 754 FP16 (half precision)"""
    fp32_bytes = struct.pack('f', val)
    fp32_bits = struct.unpack('I', fp32_bytes)[0]
    
    # Extract FP32 fields
    sign = (fp32_bits >> 31) & 0x1
    exp32 = (fp32_bits >> 23) & 0xFF
    mant32 = fp32_bits & 0x7FFFFF
    
    # Convert to FP16
    if exp32 == 0:  # Zero or denormalized
        return (sign << 15)
    elif exp32 == 0xFF:  # Infinity or NaN
        return (sign << 15) | 0x7C00
    else:  # Normalized
        exp16 = exp32 - 127 + 15  # Adjust bias from 127 to 15
        
        # Handle overflow/underflow
        if exp16 >= 31:  # Overflow to infinity
            return (sign << 15) | 0x7C00
        elif exp16 <= 0:  # Underflow to zero
            return (sign << 15)
        else:
            mant16 = mant32 >> 13  # Truncate 23-bit to 10-bit mantissa
            return (sign << 15) | (exp16 << 10) | mant16

def fp16_to_fp32(fp16: int) -> float:
    """Convert IEEE 754 FP16 to float32"""
    sign = (fp16 >> 15) & 0x1
    exp16 = (fp16 >> 10) & 0x1F
    mant16 = fp16 & 0x3FF
    
    # Convert to FP32
    if exp16 == 0:  # Zero or denormalized
        if mant16 == 0:
            fp32_bits = sign << 31
        else:  # Denormalized
            exp32 = 127 - 15 + 1
            mant32 = mant16 << 13
            # Normalize
            while (mant32 & 0x800000) == 0:
                mant32 <<= 1
                exp32 -= 1
            mant32 &= 0x7FFFFF
            fp32_bits = (sign << 31) | (exp32 << 23) | mant32
    elif exp16 == 31:  # Infinity or NaN
        fp32_bits = (sign << 31) | (0xFF << 23) | (mant16 << 13)
    else:  # Normalized
        exp32 = exp16 - 15 + 127
        mant32 = mant16 << 13
        fp32_bits = (sign << 31) | (exp32 << 23) | mant32
    
    return struct.unpack('f', struct.pack('I', fp32_bits))[0]


@dataclass
class TPUStatus:
    """TPU status information"""
    busy: bool
    done: bool
    error: bool
    cycles: int
    
    def __str__(self):
        status = "BUSY" if self.busy else "IDLE"
        if self.done:
            status = "DONE"
        if self.error:
            status = "ERROR"
        return f"TPU Status: {status}, Cycles: {cycles}"


class FPGA_TPU:
    """Interface to FPGA TPU via UART"""
    
    # Protocol commands
    CMD_WRITE_MATRIX_A = 0x01
    CMD_WRITE_MATRIX_B = 0x02
    CMD_READ_RESULT = 0x03
    CMD_START_COMPUTE = 0x04
    CMD_GET_STATUS = 0x05
    CMD_RESET = 0x06
    CMD_READ_MATRIX_A = 0x07
    CMD_READ_MATRIX_B = 0x08
    
    # Response codes
    RESP_ACK = 0xAA
    RESP_NACK = 0x55
    RESP_BUSY = 0xBB
    RESP_DONE = 0xDD
    
    def __init__(self, port: Optional[str] = None, baudrate: int = 115200, timeout: float = 2.0):
        """
        Initialize FPGA TPU connection
        
        Args:
            port: Serial port name (e.g., '/dev/ttyUSB0', 'COM3')
                  If None, auto-detect FTDI device
            baudrate: UART baud rate (default 115200)
            timeout: Serial read timeout in seconds
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.ser: Optional[serial.Serial] = None
        self.matrix_size = 8  # 8x8 systolic array
        
        # Performance tracking
        self.last_compute_time = 0.0
        self.total_computes = 0
        self.total_time = 0.0
        
    def find_fpga_port(self) -> Optional[str]:
        """Auto-detect FPGA/FTDI USB-Serial port"""
        ports = serial.tools.list_ports.comports()
        
        # Look for FTDI devices (common for Basys3)
        for port in ports:
            if 'FTDI' in port.description or 'USB' in port.description:
                print(f"Found FPGA at: {port.device} ({port.description})")
                return port.device
        
        # If no FTDI found, list all available ports
        if ports:
            print("\nAvailable serial ports:")
            for i, port in enumerate(ports):
                print(f"  [{i}] {port.device}: {port.description}")
            return None
        else:
            print("No serial ports found!")
            return None
    
    def connect(self) -> bool:
        """
        Connect to FPGA
        
        Returns:
            True if connection successful
        """
        try:
            if self.port is None:
                self.port = self.find_fpga_port()
                if self.port is None:
                    return False
            
            print(f"Connecting to FPGA at {self.port} ({self.baudrate} baud)...")
            self.ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=self.timeout
            )
            
            # Wait for connection to stabilize
            time.sleep(0.5)
            
            # Flush buffers
            self.ser.reset_input_buffer()
            self.ser.reset_output_buffer()
            
            # Test connection with reset command
            if self.reset():
                print("✓ Connected to FPGA TPU successfully!")
                return True
            else:
                print("✗ Connection test failed")
                return False
                
        except serial.SerialException as e:
            print(f"✗ Serial connection error: {e}")
            return False
    
    def disconnect(self):
        """Close FPGA connection"""
        if self.ser and self.ser.is_open:
            self.ser.close()
            print("Disconnected from FPGA")
    
    def _send_command(self, cmd: int, data: bytes = b'') -> bool:
        """
        Send command to FPGA
        
        Args:
            cmd: Command byte
            data: Optional data payload
            
        Returns:
            True if ACK received
        """
        if not self.ser or not self.ser.is_open:
            print("Error: Not connected to FPGA")
            return False
        
        # Send command
        packet = bytes([cmd]) + data
        self.ser.write(packet)
        
        # Wait for ACK
        response = self.ser.read(1)
        if len(response) == 0:
            print(f"Timeout waiting for response to command 0x{cmd:02X}")
            return False
        
        return response[0] == self.RESP_ACK
    
    def _receive_data(self, length: int) -> Optional[bytes]:
        """Receive data from FPGA"""
        if not self.ser or not self.ser.is_open:
            return None
        
        data = self.ser.read(length)
        if len(data) != length:
            print(f"Timeout: Expected {length} bytes, got {len(data)}")
            return None
        return data
    
    def reset(self) -> bool:
        """Reset TPU"""
        return self._send_command(self.CMD_RESET)
    
    def write_matrix_a(self, matrix: np.ndarray) -> bool:
        """
        Write matrix A to FPGA
        
        Args:
            matrix: numpy array of shape (8, 8)
            
        Returns:
            True if successful
        """
        if matrix.shape != (self.matrix_size, self.matrix_size):
            print(f"Error: Matrix must be {self.matrix_size}x{self.matrix_size}")
            return False
        
        # Convert to FP16
        data = bytearray()
        for i in range(self.matrix_size):
            for j in range(self.matrix_size):
                fp16_val = fp32_to_fp16(float(matrix[i, j]))
                data.extend(fp16_val.to_bytes(2, byteorder='little'))
        
        # Send command with data
        if not self._send_command(self.CMD_WRITE_MATRIX_A, bytes(data)):
            print("Failed to write matrix A")
            return False
        
        return True
    
    def write_matrix_b(self, matrix: np.ndarray) -> bool:
        """
        Write matrix B to FPGA
        
        Args:
            matrix: numpy array of shape (8, 8)
            
        Returns:
            True if successful
        """
        if matrix.shape != (self.matrix_size, self.matrix_size):
            print(f"Error: Matrix must be {self.matrix_size}x{self.matrix_size}")
            return False
        
        # Convert to FP16
        data = bytearray()
        for i in range(self.matrix_size):
            for j in range(self.matrix_size):
                fp16_val = fp32_to_fp16(float(matrix[i, j]))
                data.extend(fp16_val.to_bytes(2, byteorder='little'))
        
        # Send command with data
        if not self._send_command(self.CMD_WRITE_MATRIX_B, bytes(data)):
            print("Failed to write matrix B")
            return False
        
        return True
    
    def start_compute(self) -> bool:
        """Start matrix multiplication"""
        return self._send_command(self.CMD_START_COMPUTE)
    
    def get_status(self) -> Optional[TPUStatus]:
        """Get TPU status"""
        if not self._send_command(self.CMD_GET_STATUS):
            return None
        
        status_data = self._receive_data(4)
        if status_data is None:
            return None
        
        busy = bool(status_data[0] & 0x01)
        done = bool(status_data[0] & 0x02)
        error = bool(status_data[0] & 0x04)
        cycles = int.from_bytes(status_data[1:4], byteorder='little')
        
        return TPUStatus(busy=busy, done=done, error=error, cycles=cycles)
    
    def wait_for_completion(self, timeout: float = 10.0) -> bool:
        """
        Wait for computation to complete
        
        Args:
            timeout: Maximum time to wait in seconds
            
        Returns:
            True if completed successfully
        """
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            status = self.get_status()
            if status is None:
                return False
            
            if status.done:
                return True
            
            if not status.busy:
                print("Warning: TPU not busy but not done")
            
            time.sleep(0.01)  # Poll every 10ms
        
        print("Timeout waiting for computation")
        return False
    
    def read_result(self) -> Optional[np.ndarray]:
        """
        Read result matrix from FPGA
        
        Returns:
            numpy array of shape (8, 8) or None if failed
        """
        if not self._send_command(self.CMD_READ_RESULT):
            print("Failed to request result")
            return None
        
        # Receive 64 FP16 values (128 bytes)
        data = self._receive_data(128)
        if data is None:
            return None
        
        # Convert FP16 to float32
        result = np.zeros((self.matrix_size, self.matrix_size), dtype=np.float32)
        idx = 0
        for i in range(self.matrix_size):
            for j in range(self.matrix_size):
                fp16_val = int.from_bytes(data[idx:idx+2], byteorder='little')
                result[i, j] = fp16_to_fp32(fp16_val)
                idx += 2
        
        return result
    
    def matrix_multiply(self, matrix_a: np.ndarray, matrix_b: np.ndarray, 
                       verbose: bool = True) -> Optional[np.ndarray]:
        """
        Perform matrix multiplication on FPGA
        
        Args:
            matrix_a: First matrix (8x8)
            matrix_b: Second matrix (8x8)
            verbose: Print progress messages
            
        Returns:
            Result matrix (8x8) or None if failed
        """
        start_time = time.time()
        
        # Write matrices
        if verbose:
            print("Writing matrix A...")
        if not self.write_matrix_a(matrix_a):
            return None
        
        if verbose:
            print("Writing matrix B...")
        if not self.write_matrix_b(matrix_b):
            return None
        
        # Start computation
        if verbose:
            print("Starting computation...")
        if not self.start_compute():
            print("Failed to start computation")
            return None
        
        # Wait for completion
        if verbose:
            print("Waiting for completion...")
        if not self.wait_for_completion():
            return None
        
        # Read result
        if verbose:
            print("Reading result...")
        result = self.read_result()
        
        # Track performance
        elapsed = time.time() - start_time
        self.last_compute_time = elapsed
        self.total_computes += 1
        self.total_time += elapsed
        
        if verbose and result is not None:
            print(f"✓ Computation completed in {elapsed*1000:.2f} ms")
        
        return result
    
    def get_performance_stats(self) -> dict:
        """Get performance statistics"""
        if self.total_computes == 0:
            return {
                'total_operations': 0,
                'total_time': 0.0,
                'avg_time': 0.0,
                'throughput': 0.0
            }
        
        avg_time = self.total_time / self.total_computes
        # 8x8 matrix multiply = 8*8*8 = 512 MAC operations
        ops_per_compute = self.matrix_size ** 3
        total_ops = ops_per_compute * self.total_computes
        throughput = total_ops / self.total_time  # Operations per second
        
        return {
            'total_operations': total_ops,
            'total_computes': self.total_computes,
            'total_time': self.total_time,
            'avg_time': avg_time,
            'last_time': self.last_compute_time,
            'throughput_ops': throughput,
            'throughput_gops': throughput / 1e9
        }
    
    def __enter__(self):
        """Context manager entry"""
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.disconnect()


def print_matrix(matrix: np.ndarray, name: str = "Matrix", precision: int = 4):
    """Pretty print matrix"""
    print(f"\n{name}:")
    print("-" * (precision * 8 + 10))
    for row in matrix:
        print("  ", end="")
        for val in row:
            print(f"{val:{precision+3}.{precision}f}", end=" ")
        print()
    print()


if __name__ == "__main__":
    print("=" * 60)
    print("FPGA TPU Interface Test")
    print("=" * 60)
    
    # Test connection
    tpu = FPGA_TPU()
    if not tpu.connect():
        print("\nFailed to connect to FPGA")
        print("Please check:")
        print("  1. FPGA is powered on and programmed")
        print("  2. USB cable is connected")
        print("  3. FTDI drivers are installed")
        sys.exit(1)
    
    try:
        # Simple test matrices
        print("\n" + "=" * 60)
        print("Test 1: Simple Matrix Multiplication")
        print("=" * 60)
        
        A = np.ones((8, 8), dtype=np.float32) * 2.0
        B = np.ones((8, 8), dtype=np.float32) * 3.0
        
        print_matrix(A[:3, :3], "Matrix A (3x3 preview)")
        print_matrix(B[:3, :3], "Matrix B (3x3 preview)")
        
        result = tpu.matrix_multiply(A, B)
        
        if result is not None:
            print_matrix(result[:3, :3], "Result (3x3 preview)")
            
            # Verify with numpy
            expected = A @ B
            error = np.abs(result - expected)
            max_error = np.max(error)
            mean_error = np.mean(error)
            
            print(f"Max error: {max_error:.6f}")
            print(f"Mean error: {mean_error:.6f}")
            
            if max_error < 1.0:  # Approximate computing tolerance
                print("✓ Result matches expected (within tolerance)")
            else:
                print("✗ Result does not match expected")
        
        # Performance test
        print("\n" + "=" * 60)
        print("Test 2: Performance Benchmark")
        print("=" * 60)
        
        num_iterations = 10
        print(f"Running {num_iterations} iterations...")
        
        for i in range(num_iterations):
            A = np.random.randn(8, 8).astype(np.float32)
            B = np.random.randn(8, 8).astype(np.float32)
            result = tpu.matrix_multiply(A, B, verbose=False)
            if result is None:
                print(f"✗ Iteration {i+1} failed")
                break
            print(f"  Iteration {i+1}/{num_iterations} completed")
        
        # Print statistics
        stats = tpu.get_performance_stats()
        print("\n" + "=" * 60)
        print("Performance Statistics")
        print("=" * 60)
        print(f"Total computations: {stats['total_computes']}")
        print(f"Total operations: {stats['total_operations']:,}")
        print(f"Total time: {stats['total_time']:.3f} s")
        print(f"Average time per computation: {stats['avg_time']*1000:.2f} ms")
        print(f"Throughput: {stats['throughput_ops']/1e6:.2f} MOPS")
        print(f"Throughput: {stats['throughput_gops']:.4f} GOPS")
        
        # Calculate theoretical vs actual
        clock_freq = 100e6  # 100 MHz
        macs_per_cycle = 64  # 8x8 array
        theoretical_gops = (clock_freq * macs_per_cycle) / 1e9
        efficiency = (stats['throughput_gops'] / theoretical_gops) * 100
        
        print(f"\nTheoretical peak: {theoretical_gops:.2f} GOPS")
        print(f"Efficiency: {efficiency:.1f}%")
        
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
    finally:
        tpu.disconnect()
    
    print("\n" + "=" * 60)
    print("Test completed")
    print("=" * 60)
