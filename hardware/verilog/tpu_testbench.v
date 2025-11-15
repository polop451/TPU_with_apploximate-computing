`timescale 1ns / 1ps

// Testbench for TPU Design
// Tests basic matrix multiplication functionality

module tpu_testbench;

    // Parameters
    parameter SIZE = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter CLK_PERIOD = 10; // 100 MHz
    
    // Testbench signals
    reg clk;
    reg rst_n;
    reg start;
    reg [7:0] matrix_size;
    reg load_weight;
    reg load_activation;
    reg [7:0] load_addr;
    reg [DATA_WIDTH-1:0] load_data;
    
    wire busy;
    wire done;
    wire [15:0] led;
    wire [ACC_WIDTH-1:0] result_0, result_1, result_2, result_3;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation
    tpu_top #(
        .SIZE(SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_size(matrix_size),
        .load_weight(load_weight),
        .load_activation(load_activation),
        .load_addr(load_addr),
        .load_data(load_data),
        .busy(busy),
        .done(done),
        .led(led),
        .result_0(result_0),
        .result_1(result_1),
        .result_2(result_2),
        .result_3(result_3)
    );
    
    // Test procedure
    initial begin
        // Initialize signals
        rst_n = 0;
        start = 0;
        matrix_size = 4;
        load_weight = 0;
        load_activation = 0;
        load_addr = 0;
        load_data = 0;
        
        // Apply reset
        #(CLK_PERIOD*5);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        $display("=== TPU Testbench Started ===");
        $display("Time: %0t", $time);
        
        // Test Case 1: Simple 2x2 matrix multiplication
        // Matrix A = [1 2]    Matrix B = [5 6]
        //            [3 4]               [7 8]
        // Expected Result C = [19 22]
        //                     [43 50]
        
        $display("\n--- Loading Weights (Matrix B) ---");
        load_weight = 1;
        
        // Load weight matrix (column-major for systolic array)
        load_addr = 0; load_data = 8'd5; #CLK_PERIOD;  // B[0,0]
        load_addr = 1; load_data = 8'd7; #CLK_PERIOD;  // B[1,0]
        load_addr = 2; load_data = 8'd6; #CLK_PERIOD;  // B[0,1]
        load_addr = 3; load_data = 8'd8; #CLK_PERIOD;  // B[1,1]
        
        load_weight = 0;
        #CLK_PERIOD;
        
        $display("\n--- Loading Activations (Matrix A) ---");
        load_activation = 1;
        
        // Load activation matrix (row-major)
        load_addr = 0; load_data = 8'd1; #CLK_PERIOD;  // A[0,0]
        load_addr = 1; load_data = 8'd2; #CLK_PERIOD;  // A[0,1]
        load_addr = 2; load_data = 8'd3; #CLK_PERIOD;  // A[1,0]
        load_addr = 3; load_data = 8'd4; #CLK_PERIOD;  // A[1,1]
        
        load_activation = 0;
        #CLK_PERIOD;
        
        $display("\n--- Starting Computation ---");
        matrix_size = 2;
        start = 1;
        #CLK_PERIOD;
        start = 0;
        
        // Wait for computation to complete
        wait(done == 1);
        #(CLK_PERIOD*10);
        
        $display("\n=== Computation Complete ===");
        $display("Result 0 (C[0,0]): %0d (Expected: 19)", $signed(result_0));
        $display("Result 1 (C[0,1]): %0d (Expected: 22)", $signed(result_1));
        $display("Result 2 (C[1,0]): %0d (Expected: 43)", $signed(result_2));
        $display("Result 3 (C[1,1]): %0d (Expected: 50)", $signed(result_3));
        
        // Verify results
        if ($signed(result_0) == 19 && $signed(result_1) == 22 && 
            $signed(result_2) == 43 && $signed(result_3) == 50) begin
            $display("\n*** TEST PASSED ***");
        end else begin
            $display("\n*** TEST FAILED ***");
        end
        
        #(CLK_PERIOD*20);
        
        // Test Case 2: Identity matrix test
        $display("\n\n=== Test Case 2: Identity Matrix ===");
        
        rst_n = 0;
        #(CLK_PERIOD*5);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        // Load identity weight matrix
        load_weight = 1;
        load_addr = 0; load_data = 8'd1; #CLK_PERIOD;  // B[0,0]
        load_addr = 1; load_data = 8'd0; #CLK_PERIOD;  // B[1,0]
        load_addr = 2; load_data = 8'd0; #CLK_PERIOD;  // B[0,1]
        load_addr = 3; load_data = 8'd1; #CLK_PERIOD;  // B[1,1]
        load_weight = 0;
        #CLK_PERIOD;
        
        // Load test activation matrix
        load_activation = 1;
        load_addr = 0; load_data = 8'd5; #CLK_PERIOD;  // A[0,0]
        load_addr = 1; load_data = 8'd6; #CLK_PERIOD;  // A[0,1]
        load_addr = 2; load_data = 8'd7; #CLK_PERIOD;  // A[1,0]
        load_addr = 3; load_data = 8'd8; #CLK_PERIOD;  // A[1,1]
        load_activation = 0;
        #CLK_PERIOD;
        
        matrix_size = 2;
        start = 1;
        #CLK_PERIOD;
        start = 0;
        
        wait(done == 1);
        #(CLK_PERIOD*10);
        
        $display("Result 0 (C[0,0]): %0d (Expected: 5)", $signed(result_0));
        $display("Result 1 (C[0,1]): %0d (Expected: 6)", $signed(result_1));
        $display("Result 2 (C[1,0]): %0d (Expected: 7)", $signed(result_2));
        $display("Result 3 (C[1,1]): %0d (Expected: 8)", $signed(result_3));
        
        if ($signed(result_0) == 5 && $signed(result_1) == 6 && 
            $signed(result_2) == 7 && $signed(result_3) == 8) begin
            $display("*** TEST PASSED ***");
        end else begin
            $display("*** TEST FAILED ***");
        end
        
        #(CLK_PERIOD*50);
        
        $display("\n=== All Tests Complete ===");
        $finish;
    end
    
    // Monitor key signals
    initial begin
        $monitor("Time=%0t | busy=%b | done=%b | LED=%h", 
                 $time, busy, done, led);
    end
    
    // Timeout watchdog
    initial begin
        #(CLK_PERIOD*10000);
        $display("ERROR: Testbench timeout!");
        $finish;
    end
    
    // Waveform dump for debugging
    initial begin
        $dumpfile("tpu_tb.vcd");
        $dumpvars(0, tpu_testbench);
    end

endmodule
