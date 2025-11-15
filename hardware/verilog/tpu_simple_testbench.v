`timescale 1ns / 1ps

// Simple Testbench for TPU
module tpu_simple_testbench;

    parameter SIZE = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter CLK_PERIOD = 10;
    
    reg clk;
    reg rst_n;
    reg start;
    reg [7:0] matrix_size;
    
    reg signed [DATA_WIDTH-1:0] matrix_a [0:SIZE-1][0:SIZE-1];
    reg signed [DATA_WIDTH-1:0] matrix_b [0:SIZE-1][0:SIZE-1];
    wire signed [ACC_WIDTH-1:0] matrix_c [0:SIZE-1][0:SIZE-1];
    
    wire busy;
    wire done;
    
    integer i, j;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT
    tpu_simple #(
        .SIZE(SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_size(matrix_size),
        .matrix_a(matrix_a),
        .matrix_b(matrix_b),
        .matrix_c(matrix_c),
        .busy(busy),
        .done(done)
    );
    
    // Test
    initial begin
        $dumpfile("tpu_simple_tb.vcd");
        $dumpvars(0, tpu_simple_testbench);
        
        // Initialize
        rst_n = 0;
        start = 0;
        matrix_size = 2;
        
        // Initialize matrices to zero
        for (i = 0; i < SIZE; i = i + 1) begin
            for (j = 0; j < SIZE; j = j + 1) begin
                matrix_a[i][j] = 0;
                matrix_b[i][j] = 0;
            end
        end
        
        #(CLK_PERIOD*5);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        $display("\n=== TPU Simple Testbench ===\n");
        
        // Test Case 1: 2x2 matrix multiplication
        // A = [1 2]    B = [5 6]
        //     [3 4]        [7 8]
        // C = [19 22]
        //     [43 50]
        
        $display("Test Case 1: Basic 2x2 Matrix Multiplication");
        $display("Matrix A:");
        matrix_a[0][0] = 1; matrix_a[0][1] = 2;
        matrix_a[1][0] = 3; matrix_a[1][1] = 4;
        $display("  [%0d %0d]", matrix_a[0][0], matrix_a[0][1]);
        $display("  [%0d %0d]", matrix_a[1][0], matrix_a[1][1]);
        
        $display("Matrix B:");
        matrix_b[0][0] = 5; matrix_b[0][1] = 6;
        matrix_b[1][0] = 7; matrix_b[1][1] = 8;
        $display("  [%0d %0d]", matrix_b[0][0], matrix_b[0][1]);
        $display("  [%0d %0d]", matrix_b[1][0], matrix_b[1][1]);
        
        matrix_size = 2;
        start = 1;
        #CLK_PERIOD;
        start = 0;
        
        wait(done == 1);
        #(CLK_PERIOD*2);
        
        $display("\nResult Matrix C:");
        $display("  [%0d %0d]", $signed(matrix_c[0][0]), $signed(matrix_c[0][1]));
        $display("  [%0d %0d]", $signed(matrix_c[1][0]), $signed(matrix_c[1][1]));
        
        $display("\nExpected:");
        $display("  [19 22]");
        $display("  [43 50]");
        
        if (matrix_c[0][0] == 19 && matrix_c[0][1] == 22 && 
            matrix_c[1][0] == 43 && matrix_c[1][1] == 50) begin
            $display("\n✓ TEST PASSED!\n");
        end else begin
            $display("\n✗ TEST FAILED!\n");
        end
        
        #(CLK_PERIOD*10);
        
        // Test Case 2: Identity matrix
        $display("\nTest Case 2: Identity Matrix");
        
        rst_n = 0;
        #(CLK_PERIOD*2);
        rst_n = 1;
        #(CLK_PERIOD*2);
        
        $display("Matrix A:");
        matrix_a[0][0] = 5; matrix_a[0][1] = 6;
        matrix_a[1][0] = 7; matrix_a[1][1] = 8;
        $display("  [%0d %0d]", matrix_a[0][0], matrix_a[0][1]);
        $display("  [%0d %0d]", matrix_a[1][0], matrix_a[1][1]);
        
        $display("Matrix B (Identity):");
        matrix_b[0][0] = 1; matrix_b[0][1] = 0;
        matrix_b[1][0] = 0; matrix_b[1][1] = 1;
        $display("  [%0d %0d]", matrix_b[0][0], matrix_b[0][1]);
        $display("  [%0d %0d]", matrix_b[1][0], matrix_b[1][1]);
        
        matrix_size = 2;
        start = 1;
        #CLK_PERIOD;
        start = 0;
        
        wait(done == 1);
        #(CLK_PERIOD*2);
        
        $display("\nResult Matrix C:");
        $display("  [%0d %0d]", $signed(matrix_c[0][0]), $signed(matrix_c[0][1]));
        $display("  [%0d %0d]", $signed(matrix_c[1][0]), $signed(matrix_c[1][1]));
        
        $display("\nExpected (same as A):");
        $display("  [5 6]");
        $display("  [7 8]");
        
        if (matrix_c[0][0] == 5 && matrix_c[0][1] == 6 && 
            matrix_c[1][0] == 7 && matrix_c[1][1] == 8) begin
            $display("\n✓ TEST PASSED!\n");
        end else begin
            $display("\n✗ TEST FAILED!\n");
        end
        
        #(CLK_PERIOD*20);
        
        $display("\n=== All Tests Complete ===\n");
        $finish;
    end
    
    // Timeout
    initial begin
        #(CLK_PERIOD*1000);
        $display("\nERROR: Timeout!");
        $finish;
    end

endmodule
