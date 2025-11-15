`timescale 1ns / 1ps

// Simplified TPU for testing - Direct matrix multiplication without complex buffering
module tpu_simple #(
    parameter SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] matrix_size,
    
    // Direct matrix inputs for testing
    input wire signed [DATA_WIDTH-1:0] matrix_a [0:SIZE-1][0:SIZE-1],
    input wire signed [DATA_WIDTH-1:0] matrix_b [0:SIZE-1][0:SIZE-1],
    
    // Output matrix
    output reg signed [ACC_WIDTH-1:0] matrix_c [0:SIZE-1][0:SIZE-1],
    
    // Status
    output reg busy,
    output reg done
);

    // State machine
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE = 2'b10;
    
    reg [1:0] state;
    reg [7:0] k_counter;  // K dimension counter
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            k_counter <= 8'd0;
            
            for (i = 0; i < SIZE; i = i + 1) begin
                for (j = 0; j < SIZE; j = j + 1) begin
                    matrix_c[i][j] <= {ACC_WIDTH{1'b0}};
                end
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        k_counter <= 8'd0;
                        state <= COMPUTE;
                        
                        // Clear output matrix
                        for (i = 0; i < SIZE; i = i + 1) begin
                            for (j = 0; j < SIZE; j = j + 1) begin
                                matrix_c[i][j] <= {ACC_WIDTH{1'b0}};
                            end
                        end
                    end
                end
                
                COMPUTE: begin
                    // Perform one iteration of k: C[i][j] += A[i][k] * B[k][j]
                    for (i = 0; i < matrix_size; i = i + 1) begin
                        for (j = 0; j < matrix_size; j = j + 1) begin
                            matrix_c[i][j] <= matrix_c[i][j] + 
                                            (matrix_a[i][k_counter] * matrix_b[k_counter][j]);
                        end
                    end
                    
                    if (k_counter >= matrix_size - 1) begin
                        state <= DONE;
                    end else begin
                        k_counter <= k_counter + 1;
                    end
                end
                
                DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
