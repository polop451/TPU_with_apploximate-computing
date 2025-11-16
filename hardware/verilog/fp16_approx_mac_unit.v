// Approximate FP16 MAC Unit
// Multiply-Accumulate with Half-Precision Floating Point
// Features approximate computing for reduced circuit area
//
// Note: FP16 exact MAC unit has been separated into fp16_exact_mac_unit.v

module fp16_approx_mac_unit #(
    parameter APPROX_MULT_BITS = 6,  // Mantissa bits for multiplication
    parameter APPROX_ALIGN = 4        // Max alignment shift for addition
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire acc_clear,
    
    // FP16 inputs
    input wire [15:0] a_in,      // Activation (FP16)
    input wire [15:0] w_in,      // Weight (FP16)
    input wire [15:0] acc_in,    // Accumulator input (for chaining)
    
    // FP16 outputs
    output reg [15:0] a_out,     // Pass-through activation
    output reg [15:0] w_out,     // Pass-through weight
    output reg [15:0] acc_out    // Accumulated result
);

    // Internal wires and pipeline registers
    wire [15:0] mult_result;
    reg [15:0] mult_result_reg;  // Pipeline stage 1
    wire [15:0] add_result;
    reg [15:0] accumulator;
    
    // Approximate FP16 Multiplier
    fp16_approximate_multiplier #(
        .APPROX_BITS(APPROX_MULT_BITS)
    ) mult (
        .a(a_in),
        .b(w_in),
        .result(mult_result)
    );
    
    // Approximate FP16 Adder (uses pipelined mult result)
    fp16_approximate_adder #(
        .APPROX_ALIGN(APPROX_ALIGN)
    ) adder (
        .a(accumulator),
        .b(mult_result_reg),
        .result(add_result)
    );
    
    // Pipeline and accumulation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_result_reg <= 16'h0000;  // Pipeline register
            accumulator <= 16'h0000;  // +0.0 in FP16
            a_out <= 16'h0000;
            w_out <= 16'h0000;
            acc_out <= 16'h0000;
        end else if (enable) begin
            // Pipeline stage 1: Register multiplier output
            mult_result_reg <= mult_result;
            
            // Pass data to next PE
            a_out <= a_in;
            w_out <= w_in;
            
            // Accumulate
            if (acc_clear) begin
                accumulator <= mult_result_reg;
            end else begin
                accumulator <= add_result;
            end
            
            acc_out <= accumulator;
        end
    end

endmodule
