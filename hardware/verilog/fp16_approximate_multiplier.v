// FP16 Approximate Multiplier
// IEEE 754 Half-Precision Format: 1 sign bit, 5 exponent bits, 10 mantissa bits
// Approximate Computing: Truncate mantissa for reduced circuit complexity

module fp16_approximate_multiplier #(
    parameter APPROX_BITS = 6  // Use only 6 MSBs of mantissa (instead of 10)
)(
    input wire [15:0] a,      // FP16 input A
    input wire [15:0] b,      // FP16 input B
    output wire [15:0] result // FP16 result
);

    // Extract fields from FP16
    wire sign_a = a[15];
    wire sign_b = b[15];
    wire [4:0] exp_a = a[14:10];
    wire [4:0] exp_b = b[14:10];
    wire [9:0] mant_a = a[9:0];
    wire [9:0] mant_b = b[9:0];
    
    // Result fields
    wire sign_result;
    reg [4:0] exp_result;
    reg [9:0] mant_result;
    
    // Sign calculation
    assign sign_result = sign_a ^ sign_b;
    
    // Exponent calculation with bias
    // FP16 bias = 15
    wire [5:0] exp_sum = exp_a + exp_b;
    wire [5:0] exp_unbiased = exp_sum - 6'd15;
    
    // Approximate mantissa multiplication
    // Add implicit leading 1 for normalized numbers
    wire [10:0] mant_a_full = (exp_a == 0) ? {1'b0, mant_a} : {1'b1, mant_a};
    wire [10:0] mant_b_full = (exp_b == 0) ? {1'b0, mant_b} : {1'b1, mant_b};
    
    // APPROXIMATE COMPUTING: Use only MSBs to reduce multiplier size
    wire [APPROX_BITS-1:0] mant_a_approx = mant_a_full[10:10-APPROX_BITS+1];
    wire [APPROX_BITS-1:0] mant_b_approx = mant_b_full[10:10-APPROX_BITS+1];
    
    // Reduced-width multiplication (saves ~60% area)
    wire [2*APPROX_BITS-1:0] mant_mult_approx = mant_a_approx * mant_b_approx;
    
    // Normalize and extract mantissa
    wire normalize = mant_mult_approx[2*APPROX_BITS-1];
    
    always @(*) begin
        // Handle special cases
        if (exp_a == 0 || exp_b == 0) begin
            // Zero or denormalized
            exp_result = 5'b00000;
            mant_result = 10'b0;
        end else if (exp_a == 5'b11111 || exp_b == 5'b11111) begin
            // Infinity or NaN
            exp_result = 5'b11111;
            mant_result = 10'b0;
        end else begin
            // Normal case
            if (normalize) begin
                exp_result = exp_unbiased[4:0] + 1;
                // Scale up approximate result to 10 bits
                mant_result = {mant_mult_approx[2*APPROX_BITS-2:2*APPROX_BITS-2-5], 4'b0};
            end else begin
                exp_result = exp_unbiased[4:0];
                mant_result = {mant_mult_approx[2*APPROX_BITS-3:2*APPROX_BITS-3-5], 4'b0};
            end
            
            // Handle overflow/underflow
            if (exp_unbiased[5] == 1'b1) begin  // Underflow
                exp_result = 5'b00000;
                mant_result = 10'b0;
            end else if (exp_result >= 5'b11111) begin  // Overflow
                exp_result = 5'b11111;
                mant_result = 10'b0;
            end
        end
    end
    
    // Combine result
    assign result = {sign_result, exp_result, mant_result};

endmodule


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
