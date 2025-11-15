#!/usr/bin/env python3
"""
TPU Driver for Basys3 FPGA
Supports UART and SPI communication
Author: TPU Project
Date: 2025-11-15
"""

import serial
import time
import struct
import numpy as np
from typing import List, Tuple, Optional
from enum import IntEnum

class TPUCommand(IntEnum):
    """UART Command codes"""
    WRITE_WEIGHT = ord('W')      # 0x57
    WRITE_ACTIVATION = ord('A')  # 0x41
    START = ord('S')             # 0x53
    READ_RESULT = ord('R')       # 0x52
    STATUS = ord('?')            # 0x3F

class TPUStatus:
    """TPU Status flags"""
    def __init__(self, status_byte):
        self.busy = bool(status_byte & 0x01)
        self.done = bool(status_byte & 0x02)
    
    def __str__(self):
        return f"TPUStatus(busy={self.busy}, done={self.done})"

class TPUDriver:
    """
    TPU Driver for UART interface
    
    Usage:
        tpu = TPUDriver('/dev/tty.usbserial-XXX')  # macOS
        tpu = TPUDriver('COM3')                     # Windows
        tpu = TPUDriver('/dev/ttyUSB0')             # Linux
        
        # Load data
        tpu.write_weights(weight_matrix)
        tpu.write_activations(activation_matrix)
        
        # Compute
        tpu.start()
        tpu.wait_until_done()
        
        # Get results
        results = tpu.read_results()
    """
    
    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 1.0):
        """
        Initialize TPU driver
        
        Args:
            port: Serial port name (e.g., 'COM3', '/dev/ttyUSB0')
            baudrate: Baud rate (default: 115200)
            timeout: Serial timeout in seconds
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.ser = None
        self.connect()
    
    def connect(self):
        """Connect to TPU via serial port"""
        try:
            self.ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=self.timeout
            )
            time.sleep(0.1)  # Wait for connection to stabilize
            self.ser.reset_input_buffer()
            self.ser.reset_output_buffer()
            print(f"✓ Connected to TPU on {self.port}")
        except serial.SerialException as e:
            raise RuntimeError(f"Failed to connect to {self.port}: {e}")
    
    def disconnect(self):
        """Disconnect from TPU"""
        if self.ser and self.ser.is_open:
            self.ser.close()
            print("✓ Disconnected from TPU")
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.disconnect()
    
    def _send_command(self, cmd: int, addr: Optional[int] = None, 
                     data: Optional[int] = None) -> Optional[bytes]:
        """
        Send command to TPU
        
        Args:
            cmd: Command byte
            addr: Optional address byte
            data: Optional data byte
            
        Returns:
            Response bytes (for read commands)
        """
        if not self.ser or not self.ser.is_open:
            raise RuntimeError("Serial port not open")
        
        # Send command
        self.ser.write(bytes([cmd]))
        
        # Send address if provided
        if addr is not None:
            self.ser.write(bytes([addr]))
        
        # Send data if provided
        if data is not None:
            self.ser.write(bytes([data]))
        
        # Read response
        if cmd == TPUCommand.READ_RESULT:
            response = self.ser.read(1)
            if len(response) != 1:
                raise RuntimeError("Failed to read data from TPU")
            return response
        elif cmd == TPUCommand.STATUS:
            response = self.ser.read(1)
            if len(response) != 1:
                raise RuntimeError("Failed to read status from TPU")
            return response
        else:
            # Wait for ACK
            ack = self.ser.read(1)
            if ack != b'K':
                print(f"Warning: Expected ACK 'K', got {ack}")
            return ack
    
    def write_byte(self, addr: int, data: int):
        """Write a single byte to TPU memory"""
        if not (0 <= addr <= 255):
            raise ValueError(f"Address must be 0-255, got {addr}")
        if not (0 <= data <= 255):
            raise ValueError(f"Data must be 0-255, got {data}")
        
        if addr < 128:
            # Weight memory
            self._send_command(TPUCommand.WRITE_WEIGHT, addr, data)
        else:
            # Activation memory
            self._send_command(TPUCommand.WRITE_ACTIVATION, addr, data)
    
    def read_byte(self, addr: int) -> int:
        """Read a single byte from TPU memory"""
        if not (0 <= addr <= 255):
            raise ValueError(f"Address must be 0-255, got {addr}")
        
        response = self._send_command(TPUCommand.READ_RESULT, addr)
        return response[0]
    
    def write_fp16(self, addr: int, value: float):
        """
        Write FP16 value to TPU memory
        
        Args:
            addr: Starting address (must be even, 0-254)
            value: Float value to convert to FP16
        """
        if addr % 2 != 0:
            raise ValueError(f"FP16 address must be even, got {addr}")
        
        # Convert to FP16 (IEEE 754 half precision)
        fp16_bytes = np.float16(value).tobytes()
        
        # Write low byte then high byte
        self.write_byte(addr, fp16_bytes[0])
        self.write_byte(addr + 1, fp16_bytes[1])
    
    def read_fp16(self, addr: int) -> float:
        """
        Read FP16 value from TPU memory
        
        Args:
            addr: Starting address (must be even)
            
        Returns:
            Float value
        """
        if addr % 2 != 0:
            raise ValueError(f"FP16 address must be even, got {addr}")
        
        # Read low byte then high byte
        low = self.read_byte(addr)
        high = self.read_byte(addr + 1)
        
        # Convert to FP16
        fp16_bytes = bytes([low, high])
        return float(np.frombuffer(fp16_bytes, dtype=np.float16)[0])
    
    def write_weights(self, weights: np.ndarray):
        """
        Write weight matrix to TPU
        
        Args:
            weights: numpy array of shape (8, 8) with float values
        """
        if weights.shape != (8, 8):
            raise ValueError(f"Weights must be 8x8, got {weights.shape}")
        
        print("Writing weights to TPU...")
        addr = 0
        for i in range(8):
            for j in range(8):
                self.write_fp16(addr, weights[i, j])
                addr += 2
        print(f"✓ Wrote {weights.size} weights")
    
    def write_activations(self, activations: np.ndarray):
        """
        Write activation matrix to TPU
        
        Args:
            activations: numpy array of shape (8, 8) with float values
        """
        if activations.shape != (8, 8):
            raise ValueError(f"Activations must be 8x8, got {activations.shape}")
        
        print("Writing activations to TPU...")
        addr = 128  # Activation memory starts at 128
        for i in range(8):
            for j in range(8):
                self.write_fp16(addr, activations[i, j])
                addr += 2
        print(f"✓ Wrote {activations.size} activations")
    
    def start(self):
        """Start TPU computation"""
        print("Starting computation...")
        self._send_command(TPUCommand.START)
    
    def get_status(self) -> TPUStatus:
        """Get TPU status"""
        response = self._send_command(TPUCommand.STATUS)
        return TPUStatus(response[0])
    
    def wait_until_done(self, timeout: float = 10.0, poll_interval: float = 0.01):
        """
        Wait until TPU computation is complete
        
        Args:
            timeout: Maximum time to wait in seconds
            poll_interval: Time between status checks in seconds
        """
        start_time = time.time()
        while time.time() - start_time < timeout:
            status = self.get_status()
            if status.done:
                print("✓ Computation complete")
                return
            time.sleep(poll_interval)
        
        raise TimeoutError(f"TPU did not complete within {timeout} seconds")
    
    def read_results(self) -> np.ndarray:
        """
        Read result matrix from TPU
        
        Returns:
            numpy array of shape (8, 8) with float values
        """
        print("Reading results from TPU...")
        results = np.zeros((8, 8), dtype=np.float32)
        addr = 192  # Result memory starts at 192
        
        for i in range(8):
            for j in range(8):
                results[i, j] = self.read_fp16(addr)
                addr += 2
        
        print("✓ Read 64 results")
        return results
    
    def matrix_multiply(self, weights: np.ndarray, activations: np.ndarray) -> np.ndarray:
        """
        Perform matrix multiplication using TPU
        
        Args:
            weights: Weight matrix (8x8)
            activations: Activation matrix (8x8)
            
        Returns:
            Result matrix (8x8)
        """
        self.write_weights(weights)
        self.write_activations(activations)
        self.start()
        self.wait_until_done()
        return self.read_results()


def find_serial_ports() -> List[str]:
    """
    Find available serial ports
    
    Returns:
        List of port names
    """
    import serial.tools.list_ports
    ports = serial.tools.list_ports.comports()
    return [port.device for port in ports]


def demo():
    """Demo TPU driver usage"""
    print("=" * 60)
    print("TPU Driver Demo")
    print("=" * 60)
    
    # Find available ports
    ports = find_serial_ports()
    print(f"\nAvailable serial ports: {ports}")
    
    if not ports:
        print("ERROR: No serial ports found!")
        print("Please connect your Basys3 board and try again.")
        return
    
    # Use first available port (or prompt user)
    port = ports[0]
    print(f"Using port: {port}")
    
    try:
        with TPUDriver(port) as tpu:
            # Check status
            status = tpu.get_status()
            print(f"\nInitial status: {status}")
            
            # Create test matrices
            print("\n" + "=" * 60)
            print("Creating test matrices...")
            weights = np.random.randn(8, 8).astype(np.float32) * 0.1
            activations = np.random.randn(8, 8).astype(np.float32) * 0.1
            
            print(f"Weights:\n{weights}")
            print(f"\nActivations:\n{activations}")
            
            # Perform computation
            print("\n" + "=" * 60)
            print("Performing matrix multiplication on TPU...")
            start_time = time.time()
            results = tpu.matrix_multiply(weights, activations)
            elapsed = time.time() - start_time
            
            print(f"\nResults:\n{results}")
            print(f"\nElapsed time: {elapsed*1000:.2f} ms")
            
            # Compare with numpy
            expected = np.matmul(weights, activations)
            error = np.abs(results - expected)
            max_error = np.max(error)
            mean_error = np.mean(error)
            
            print("\n" + "=" * 60)
            print("Verification:")
            print(f"Expected (NumPy):\n{expected}")
            print(f"\nMax error: {max_error:.6f}")
            print(f"Mean error: {mean_error:.6f}")
            
            if max_error < 0.1:  # Approximate computing tolerance
                print("✓ Results match (within approximate computing tolerance)")
            else:
                print("✗ Results do not match!")
            
            print("\n" + "=" * 60)
            print("Demo complete!")
            
    except Exception as e:
        print(f"\nERROR: {e}")
        print("\nTroubleshooting:")
        print("1. Check that Basys3 is connected via USB")
        print("2. Verify the correct COM port")
        print("3. Make sure TPU bitstream is loaded on FPGA")
        print("4. Check that switches SW[15:14] = 01 (UART mode)")


if __name__ == "__main__":
    demo()
