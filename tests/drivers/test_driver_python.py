#!/usr/bin/env python3
"""
Test Suite for Python TPU Driver
Description: Comprehensive tests for tpu_driver.py
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../drivers'))

import unittest
import numpy as np
from unittest.mock import Mock, MagicMock, patch

# Import driver
try:
    from tpu_driver import TPUDriver, fp32_to_fp16, fp16_to_fp32
except ImportError:
    print("Error: Cannot import tpu_driver.py")
    sys.exit(1)


class TestFP16Conversion(unittest.TestCase):
    """Test FP16 conversion functions"""
    
    def test_fp32_to_fp16_zero(self):
        """Test conversion of zero"""
        result = fp32_to_fp16(0.0)
        self.assertEqual(result, 0)
    
    def test_fp32_to_fp16_one(self):
        """Test conversion of 1.0"""
        result = fp32_to_fp16(1.0)
        self.assertEqual(result, 0x3C00)
    
    def test_fp32_to_fp16_negative(self):
        """Test conversion of negative numbers"""
        result = fp32_to_fp16(-1.0)
        self.assertEqual(result & 0x8000, 0x8000)  # Sign bit set
    
    def test_fp32_to_fp16_small(self):
        """Test conversion of small numbers"""
        result = fp32_to_fp16(0.5)
        self.assertIsInstance(result, int)
        self.assertGreater(result, 0)
    
    def test_fp16_to_fp32_zero(self):
        """Test reverse conversion of zero"""
        result = fp16_to_fp32(0)
        self.assertEqual(result, 0.0)
    
    def test_fp16_to_fp32_one(self):
        """Test reverse conversion of 1.0"""
        result = fp16_to_fp32(0x3C00)
        self.assertAlmostEqual(result, 1.0, places=2)
    
    def test_roundtrip_conversion(self):
        """Test roundtrip conversion"""
        test_values = [0.0, 1.0, 2.0, 0.5, 0.25, -1.0, -2.5]
        for val in test_values:
            fp16 = fp32_to_fp16(val)
            result = fp16_to_fp32(fp16)
            # Allow for approximation errors
            self.assertAlmostEqual(result, val, places=1,
                                 msg=f"Failed for {val}")


class TestTPUDriverInit(unittest.TestCase):
    """Test TPU Driver initialization"""
    
    @patch('tpu_driver.serial.Serial')
    def test_init_with_port(self, mock_serial):
        """Test initialization with specific port"""
        driver = TPUDriver(port='/dev/ttyUSB0', auto_connect=False)
        self.assertEqual(driver.port, '/dev/ttyUSB0')
        self.assertIsNone(driver.serial_port)
    
    @patch('tpu_driver.serial.Serial')
    def test_init_auto_connect(self, mock_serial):
        """Test auto-connect on initialization"""
        mock_instance = MagicMock()
        mock_serial.return_value = mock_instance
        
        driver = TPUDriver(port='/dev/ttyUSB0', auto_connect=True)
        mock_serial.assert_called_once()
    
    def test_init_invalid_interface(self):
        """Test initialization with invalid interface"""
        with self.assertRaises(ValueError):
            TPUDriver(interface='invalid')


class TestTPUDriverConnect(unittest.TestCase):
    """Test connection functionality"""
    
    @patch('tpu_driver.serial.Serial')
    def test_connect_success(self, mock_serial):
        """Test successful connection"""
        mock_instance = MagicMock()
        mock_serial.return_value = mock_instance
        
        driver = TPUDriver(port='/dev/ttyUSB0', auto_connect=False)
        result = driver.connect()
        
        self.assertTrue(result)
        self.assertIsNotNone(driver.serial_port)
    
    @patch('tpu_driver.serial.Serial')
    def test_connect_failure(self, mock_serial):
        """Test connection failure"""
        mock_serial.side_effect = Exception("Connection failed")
        
        driver = TPUDriver(port='/dev/ttyUSB0', auto_connect=False)
        result = driver.connect()
        
        self.assertFalse(result)
        self.assertIsNone(driver.serial_port)
    
    @patch('tpu_driver.serial.Serial')
    def test_disconnect(self, mock_serial):
        """Test disconnection"""
        mock_instance = MagicMock()
        mock_serial.return_value = mock_instance
        
        driver = TPUDriver(port='/dev/ttyUSB0', auto_connect=True)
        driver.disconnect()
        
        mock_instance.close.assert_called_once()


class TestTPUDriverMatrixOps(unittest.TestCase):
    """Test matrix operations"""
    
    @patch('tpu_driver.serial.Serial')
    def setUp(self):
        """Set up test driver"""
        self.mock_serial = MagicMock()
        with patch('tpu_driver.serial.Serial', return_value=self.mock_serial):
            self.driver = TPUDriver(port='/dev/ttyUSB0', auto_connect=True)
    
    def test_load_matrix_a(self):
        """Test loading matrix A"""
        matrix = np.ones((8, 8), dtype=np.float32)
        result = self.driver.load_matrix_a(matrix)
        self.assertTrue(result)
    
    def test_load_matrix_b(self):
        """Test loading matrix B"""
        matrix = np.ones((8, 8), dtype=np.float32)
        result = self.driver.load_matrix_b(matrix)
        self.assertTrue(result)
    
    def test_load_matrix_wrong_shape(self):
        """Test loading matrix with wrong shape"""
        matrix = np.ones((4, 4), dtype=np.float32)
        result = self.driver.load_matrix_a(matrix)
        self.assertFalse(result)
    
    def test_matrix_multiply(self):
        """Test matrix multiplication"""
        self.mock_serial.read.return_value = b'\x00' * 128
        
        result = self.driver.matrix_multiply()
        self.assertIsNotNone(result)
        self.assertEqual(result.shape, (8, 8))


class TestTPUDriverActivation(unittest.TestCase):
    """Test activation functions"""
    
    @patch('tpu_driver.serial.Serial')
    def setUp(self):
        """Set up test driver"""
        self.mock_serial = MagicMock()
        with patch('tpu_driver.serial.Serial', return_value=self.mock_serial):
            self.driver = TPUDriver(port='/dev/ttyUSB0', auto_connect=True)
    
    def test_set_activation_relu(self):
        """Test setting ReLU activation"""
        result = self.driver.set_activation('relu')
        self.assertTrue(result)
    
    def test_set_activation_sigmoid(self):
        """Test setting Sigmoid activation"""
        result = self.driver.set_activation('sigmoid')
        self.assertTrue(result)
    
    def test_set_activation_invalid(self):
        """Test setting invalid activation"""
        result = self.driver.set_activation('invalid')
        self.assertFalse(result)


class TestTPUDriverContextManager(unittest.TestCase):
    """Test context manager functionality"""
    
    @patch('tpu_driver.serial.Serial')
    def test_context_manager(self, mock_serial):
        """Test using driver as context manager"""
        mock_instance = MagicMock()
        mock_serial.return_value = mock_instance
        
        with TPUDriver(port='/dev/ttyUSB0') as driver:
            self.assertIsNotNone(driver.serial_port)
        
        mock_instance.close.assert_called_once()


class TestTPUDriverEndToEnd(unittest.TestCase):
    """End-to-end integration tests"""
    
    @patch('tpu_driver.serial.Serial')
    def test_full_matrix_operation(self, mock_serial):
        """Test complete matrix operation workflow"""
        mock_instance = MagicMock()
        mock_instance.read.return_value = b'\x00' * 128
        mock_serial.return_value = mock_instance
        
        with TPUDriver(port='/dev/ttyUSB0') as driver:
            # Load matrices
            A = np.random.rand(8, 8).astype(np.float32)
            B = np.random.rand(8, 8).astype(np.float32)
            
            self.assertTrue(driver.load_matrix_a(A))
            self.assertTrue(driver.load_matrix_b(B))
            
            # Set activation
            self.assertTrue(driver.set_activation('relu'))
            
            # Multiply
            result = driver.matrix_multiply()
            self.assertIsNotNone(result)
            self.assertEqual(result.shape, (8, 8))


def run_tests():
    """Run all tests"""
    print("=" * 60)
    print("Python TPU Driver Test Suite")
    print("=" * 60)
    
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add all test classes
    suite.addTests(loader.loadTestsFromTestCase(TestFP16Conversion))
    suite.addTests(loader.loadTestsFromTestCase(TestTPUDriverInit))
    suite.addTests(loader.loadTestsFromTestCase(TestTPUDriverConnect))
    suite.addTests(loader.loadTestsFromTestCase(TestTPUDriverMatrixOps))
    suite.addTests(loader.loadTestsFromTestCase(TestTPUDriverActivation))
    suite.addTests(loader.loadTestsFromTestCase(TestTPUDriverContextManager))
    suite.addTests(loader.loadTestsFromTestCase(TestTPUDriverEndToEnd))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "=" * 60)
    print("Test Summary:")
    print(f"  Tests run: {result.testsRun}")
    print(f"  Successes: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"  Failures: {len(result.failures)}")
    print(f"  Errors: {len(result.errors)}")
    
    if result.wasSuccessful():
        print("  STATUS: ✓ ALL TESTS PASSED")
    else:
        print("  STATUS: ✗ SOME TESTS FAILED")
    print("=" * 60)
    
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    sys.exit(run_tests())
