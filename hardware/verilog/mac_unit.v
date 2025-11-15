// Multiply-Accumulate (MAC) Unit
// Optimized for TPU systolic array
// Data width: 8-bit for input, 32-bit for accumulation

module mac_unit #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire acc_clear,
    input wire signed [DATA_WIDTH-1:0] a_in,      // Activation input
    input wire signed [DATA_WIDTH-1:0] w_in,      // Weight input
    input wire signed [ACC_WIDTH-1:0] acc_in,     // Partial sum from previous stage
    output reg signed [DATA_WIDTH-1:0] a_out,     // Pass activation to next PE
    output reg signed [DATA_WIDTH-1:0] w_out,     // Pass weight to next PE
    output reg signed [ACC_WIDTH-1:0] acc_out     // Accumulated result
);

    // Internal signals
    reg signed [ACC_WIDTH-1:0] accumulator;
    wire signed [2*DATA_WIDTH-1:0] mult_result;
    
    // Multiplication (combinational)
    assign mult_result = a_in * w_in;
    
    // Pipeline registers and accumulation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= {ACC_WIDTH{1'b0}};
            a_out <= {DATA_WIDTH{1'b0}};
            w_out <= {DATA_WIDTH{1'b0}};
            acc_out <= {ACC_WIDTH{1'b0}};
        end else if (enable) begin
            // Pass data to next processing element
            a_out <= a_in;
            w_out <= w_in;
            
            // Clear accumulator if needed
            if (acc_clear) begin
                accumulator <= {{(ACC_WIDTH-2*DATA_WIDTH){mult_result[2*DATA_WIDTH-1]}}, mult_result};
            end else begin
                // Accumulate: MAC operation
                accumulator <= accumulator + {{(ACC_WIDTH-2*DATA_WIDTH){mult_result[2*DATA_WIDTH-1]}}, mult_result};
            end
            
            // Output accumulated result
            acc_out <= accumulator;
        end
    end

endmodule
