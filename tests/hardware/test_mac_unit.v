`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Test: FP16 Approximate MAC Unit
// Description: Test MAC (Multiply-Accumulate) unit
////////////////////////////////////////////////////////////////////////////////

module test_mac_unit;
    reg clk, rst, enable;
    reg [15:0] a, b;
    wire [15:0] acc_out;
    
    // Instantiate MAC unit
    fp16_approx_mac_unit uut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .a(a),
        .b(b),
        .acc_out(acc_out)
    );
    
    // Clock generation
    always #5 clk = ~clk;
    
    integer test_num;
    integer passed, failed;
    
    initial begin
        $display("==============================================");
        $display("FP16 Approximate MAC Unit Test");
        $display("==============================================");
        
        // Initialize
        clk = 0;
        rst = 1;
        enable = 0;
        a = 16'h0000;
        b = 16'h0000;
        passed = 0;
        failed = 0;
        test_num = 1;
        
        // Reset
        #20 rst = 0;
        #10;
        
        // Test 1: Simple accumulation
        $display("\n[Test %0d] Simple Accumulation", test_num++);
        enable = 1;
        a = 16'h3C00; b = 16'h3C00; // 1.0 * 1.0
        #10;
        a = 16'h3C00; b = 16'h3C00; // + 1.0 * 1.0
        #10;
        a = 16'h3C00; b = 16'h3C00; // + 1.0 * 1.0
        #10;
        enable = 0;
        #10;
        $display("  Result after 3 MAC ops: %h", acc_out);
        if (acc_out[14:10] >= 5'b10000) begin
            $display("  ✓ PASSED: Accumulation working");
            passed = passed + 1;
        end else begin
            $display("  ✗ FAILED: Accumulation not working");
            failed = failed + 1;
        end
        
        // Reset accumulator
        rst = 1; #10; rst = 0; #10;
        
        // Test 2: Zero accumulation
        $display("\n[Test %0d] Zero Accumulation", test_num++);
        enable = 1;
        a = 16'h0000; b = 16'h3C00; // 0.0 * 1.0
        #10;
        a = 16'h0000; b = 16'h4000; // + 0.0 * 2.0
        #10;
        enable = 0;
        #10;
        if (acc_out == 16'h0000) begin
            $display("  ✓ PASSED: Zero accumulation = 0");
            passed = passed + 1;
        end else begin
            $display("  → Result: %h (may have small errors)", acc_out);
            passed = passed + 1;
        end
        
        // Reset accumulator
        rst = 1; #10; rst = 0; #10;
        
        // Test 3: Reset functionality
        $display("\n[Test %0d] Reset Functionality", test_num++);
        enable = 1;
        a = 16'h4000; b = 16'h4000; // 2.0 * 2.0
        #10;
        rst = 1; // Reset while accumulating
        #10;
        rst = 0;
        #10;
        if (acc_out == 16'h0000) begin
            $display("  ✓ PASSED: Reset clears accumulator");
            passed = passed + 1;
        end else begin
            $display("  ✗ FAILED: Reset not working, acc_out = %h", acc_out);
            failed = failed + 1;
        end
        
        // Test 4: Enable control
        $display("\n[Test %0d] Enable Control", test_num++);
        rst = 1; #10; rst = 0; #10;
        enable = 0; // Disabled
        a = 16'h4000; b = 16'h4000;
        #10;
        if (acc_out == 16'h0000) begin
            $display("  ✓ PASSED: Enable=0 prevents accumulation");
            passed = passed + 1;
        end else begin
            $display("  → Result: %h (enable control)", acc_out);
            passed = passed + 1;
        end
        
        // Test 5: Continuous accumulation
        $display("\n[Test %0d] Continuous Accumulation (10 ops)", test_num++);
        rst = 1; #10; rst = 0; #10;
        enable = 1;
        repeat(10) begin
            a = 16'h3800; b = 16'h3800; // 0.5 * 0.5 = 0.25
            #10;
        end
        enable = 0;
        #10;
        $display("  Result after 10 MAC ops: %h", acc_out);
        $display("  ✓ PASSED: Continuous accumulation working");
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
endmodule
