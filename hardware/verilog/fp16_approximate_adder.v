// FP16 Approximate Adder
// Simplified alignment and rounding for reduced area
module fp16_approximate_adder #(
    parameter APPROX_ALIGN = 4  // Approximate alignment shift
)(
    input wire [15:0] a,
    input wire [15:0] b,
    output wire [15:0] result
);

    // Extract fields
    wire sign_a = a[15];
    wire sign_b = b[15];
    wire [4:0] exp_a = a[14:10];
    wire [4:0] exp_b = b[14:10];
    wire [9:0] mant_a = a[9:0];
    wire [9:0] mant_b = b[9:0];
    
    // Determine larger operand
    wire a_larger = (exp_a > exp_b) || ((exp_a == exp_b) && (mant_a >= mant_b));
    
    // Select larger and smaller
    wire [4:0] exp_large = a_larger ? exp_a : exp_b;
    wire [4:0] exp_small = a_larger ? exp_b : exp_a;
    wire [9:0] mant_large = a_larger ? mant_a : mant_b;
    wire [9:0] mant_small = a_larger ? mant_b : mant_a;
    wire sign_large = a_larger ? sign_a : sign_b;
    wire sign_small = a_larger ? sign_b : sign_a;
    
    // Add implicit leading 1
    wire [10:0] mant_large_full = (exp_large == 0) ? {1'b0, mant_large} : {1'b1, mant_large};
    wire [10:0] mant_small_full = (exp_small == 0) ? {1'b0, mant_small} : {1'b1, mant_small};
    
    // APPROXIMATE COMPUTING: Limit alignment shift to save shifter area
    wire [4:0] exp_diff = exp_large - exp_small;
    wire [4:0] shift_amount = (exp_diff > APPROX_ALIGN) ? APPROX_ALIGN : exp_diff;
    
    // Align mantissa (approximate)
    wire [10:0] mant_small_aligned = mant_small_full >> shift_amount;
    
    // Add or subtract
    reg [11:0] mant_sum;
    reg sign_result;
    
    always @(*) begin
        if (sign_large == sign_small) begin
            mant_sum = mant_large_full + mant_small_aligned;
            sign_result = sign_large;
        end else begin
            mant_sum = mant_large_full - mant_small_aligned;
            sign_result = sign_large;
        end
    end
    
    // Normalize
    reg [4:0] exp_result;
    reg [9:0] mant_result;
    
    always @(*) begin
        if (mant_sum[11]) begin
            // Overflow, shift right
            exp_result = exp_large + 1;
            mant_result = mant_sum[10:1];
        end else if (mant_sum[10]) begin
            // Normalized
            exp_result = exp_large;
            mant_result = mant_sum[9:0];
        end else begin
            // Need to normalize left (simplified)
            exp_result = exp_large - 1;
            mant_result = mant_sum[8:0] << 1;
        end
        
        // Handle special cases
        if (exp_large == 0) begin
            exp_result = 5'b00000;
            mant_result = 10'b0;
        end else if (exp_result >= 5'b11111) begin
            exp_result = 5'b11111;
            mant_result = 10'b0;
        end
    end
    
    assign result = {sign_result, exp_result, mant_result};

endmodule
