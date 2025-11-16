// Standard FP16 MAC Unit (for comparison - exact computation)
module fp16_exact_mac_unit (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire acc_clear,
    
    input wire [15:0] a_in,
    input wire [15:0] w_in,
    input wire [15:0] acc_in,
    
    output reg [15:0] a_out,
    output reg [15:0] w_out,
    output reg [15:0] acc_out
);

    // For exact computation, we would use full-precision FP16 arithmetic
    // This is a placeholder - real implementation would need complete FP16 units
    
    reg [15:0] accumulator;
    
    // Simplified exact computation (placeholder)
    // In real implementation, use full mantissa width
    wire [15:0] mult_result;
    wire [15:0] add_result;
    
    fp16_approximate_multiplier #(.APPROX_BITS(10)) mult (
        .a(a_in), .b(w_in), .result(mult_result)
    );
    
    fp16_approximate_adder #(.APPROX_ALIGN(31)) adder (
        .a(accumulator), .b(mult_result), .result(add_result)
    );
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 16'h0000;
            a_out <= 16'h0000;
            w_out <= 16'h0000;
            acc_out <= 16'h0000;
        end else if (enable) begin
            a_out <= a_in;
            w_out <= w_in;
            if (acc_clear)
                accumulator <= mult_result;
            else
                accumulator <= add_result;
            acc_out <= accumulator;
        end
    end

endmodule
