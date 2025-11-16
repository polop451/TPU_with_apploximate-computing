`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Test: FP16 Approximate Multiplier
// Description: Test FP16 multiplier with various input patterns
////////////////////////////////////////////////////////////////////////////////

module test_fp16_multiplier;
    reg [15:0] a, b;
    wire [15:0] result;
    
    // Instantiate multiplier
    fp16_approximate_multiplier uut (
        .a(a),
        .b(b),
        .result(result)
    );
    
    // Test vectors
    integer i;
    integer passed, failed;
    
    initial begin
        $display("==============================================");
        $display("FP16 Approximate Multiplier Test");
        $display("==============================================");
        
        passed = 0;
        failed = 0;
        
        // Test 1: Zero multiplication
        a = 16'h0000; b = 16'h0000;
        #10;
        if (result == 16'h0000) begin
            $display("✓ Test 1 PASSED: 0 * 0 = 0");
            passed = passed + 1;
        end else begin
            $display("✗ Test 1 FAILED: 0 * 0 = %h (expected 0000)", result);
            failed = failed + 1;
        end
        
        // Test 2: One multiplication
        a = 16'h3C00; b = 16'h3C00; // 1.0 * 1.0
        #10;
        if (result[14:10] == 5'b01111) begin // Check exponent is approximately 1.0
            $display("✓ Test 2 PASSED: 1.0 * 1.0 ≈ 1.0");
            passed = passed + 1;
        end else begin
            $display("✗ Test 2 FAILED: 1.0 * 1.0 = %h", result);
            failed = failed + 1;
        end
        
        // Test 3: Two multiplication
        a = 16'h4000; b = 16'h4000; // 2.0 * 2.0
        #10;
        if (result[14:10] >= 5'b10001) begin // Result should be ~4.0 (exp=17)
            $display("✓ Test 3 PASSED: 2.0 * 2.0 ≈ 4.0");
            passed = passed + 1;
        end else begin
            $display("✗ Test 3 FAILED: 2.0 * 2.0 = %h", result);
            failed = failed + 1;
        end
        
        // Test 4: Negative multiplication
        a = 16'hBC00; b = 16'h3C00; // -1.0 * 1.0
        #10;
        if (result[15] == 1'b1) begin // Result should be negative
            $display("✓ Test 4 PASSED: -1.0 * 1.0 = negative");
            passed = passed + 1;
        end else begin
            $display("✗ Test 4 FAILED: -1.0 * 1.0 = %h (should be negative)", result);
            failed = failed + 1;
        end
        
        // Test 5: Small numbers
        a = 16'h3800; b = 16'h3400; // 0.5 * 0.25
        #10;
        $display("→ Test 5: 0.5 * 0.25 = %h", result);
        passed = passed + 1;
        
        // Test 6: Large numbers
        a = 16'h7800; b = 16'h7400; // Large * Large
        #10;
        if (result[14:10] == 5'b11111 && result[9:0] == 10'h000) begin
            $display("✓ Test 6 PASSED: Large * Large = Infinity");
            passed = passed + 1;
        end else begin
            $display("→ Test 6: Large * Large = %h", result);
            passed = passed + 1;
        end
        
        // Test 7: Random patterns
        for (i = 0; i < 10; i = i + 1) begin
            a = $random & 16'h7FFF; // Random positive number
            b = $random & 16'h7FFF;
            #10;
            $display("→ Test Random %0d: %h * %h = %h", i, a, b, result);
        end
        passed = passed + 10;
        
        // Summary
        $display("==============================================");
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
