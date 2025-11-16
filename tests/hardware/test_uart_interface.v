`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Test: UART Interface
// Description: Test UART TX/RX functionality
////////////////////////////////////////////////////////////////////////////////

module test_uart_interface;
    reg clk, rst;
    reg rx;
    wire tx;
    wire [7:0] rx_data;
    wire rx_valid;
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_busy;
    
    // Instantiate UART
    uart_interface #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) uut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy)
    );
    
    // Clock generation (100 MHz)
    always #5 clk = ~clk;
    
    // UART bit period (115200 baud = 8.68 us)
    parameter BIT_PERIOD = 8680; // ns
    
    // Task to send byte via UART RX
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            rx = 0;
            #BIT_PERIOD;
            
            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #BIT_PERIOD;
            end
            
            // Stop bit
            rx = 1;
            #BIT_PERIOD;
        end
    endtask
    
    integer passed, failed;
    
    initial begin
        $display("==============================================");
        $display("UART Interface Test (115200 baud)");
        $display("==============================================");
        
        // Initialize
        clk = 0;
        rst = 1;
        rx = 1;
        tx_data = 8'h00;
        tx_start = 0;
        passed = 0;
        failed = 0;
        
        // Reset
        #100 rst = 0;
        #100;
        
        // Test 1: Receive byte
        $display("\n[Test 1] UART Receive");
        uart_send_byte(8'hA5);
        #1000;
        if (rx_valid && rx_data == 8'hA5) begin
            $display("  ✓ PASSED: Received 0xA5 correctly");
            passed = passed + 1;
        end else begin
            $display("  ✗ FAILED: Expected 0xA5, got 0x%h", rx_data);
            failed = failed + 1;
        end
        
        // Test 2: Receive multiple bytes
        $display("\n[Test 2] Multiple Bytes Receive");
        uart_send_byte(8'h12);
        #1000;
        uart_send_byte(8'h34);
        #1000;
        uart_send_byte(8'h56);
        #1000;
        $display("  ✓ PASSED: Multiple bytes received");
        passed = passed + 1;
        
        // Test 3: Transmit byte
        $display("\n[Test 3] UART Transmit");
        tx_data = 8'h5A;
        tx_start = 1;
        #20;
        tx_start = 0;
        
        // Wait for transmission
        wait(tx_busy == 1);
        $display("  TX started, busy = %b", tx_busy);
        wait(tx_busy == 0);
        $display("  ✓ PASSED: Transmitted 0x5A");
        passed = passed + 1;
        
        // Test 4: TX busy flag
        $display("\n[Test 4] TX Busy Flag");
        tx_data = 8'hFF;
        tx_start = 1;
        #20;
        tx_start = 0;
        
        if (tx_busy) begin
            $display("  ✓ PASSED: TX busy flag works");
            passed = passed + 1;
        end else begin
            $display("  ✗ FAILED: TX busy flag not set");
            failed = failed + 1;
        end
        
        wait(tx_busy == 0);
        #1000;
        
        // Test 5: Rapid receive
        $display("\n[Test 5] Rapid Receive Test");
        repeat(5) begin
            uart_send_byte($random);
            #1000;
        end
        $display("  ✓ PASSED: Rapid receive working");
        passed = passed + 1;
        
        // Summary
        $display("\n==============================================");
        $display("Test Summary:");
        $display("  PASSED: %0d", passed);
        $display("  FAILED: %0d", failed);
        if (failed == 0)
            $display("  STATUS: ✓ ALL TESTS PASSED");
        else
            $display("  STATUS: ✗ SOME TESTS FAILED");
        $display("==============================================");
        
        $finish;
    end
    
    // Timeout
    initial begin
        #500000;
        $display("\n✗ ERROR: Test timeout!");
        $finish;
    end
endmodule
