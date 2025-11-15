// Activation Functions Module
// Support for multiple activation functions for neural networks
// Compatible with both INT8 and FP16 TPU

module activation_functions #(
    parameter DATA_WIDTH = 16,     // 8 for INT8, 16 for FP16
    parameter IS_FLOATING_POINT = 1 // 1 for FP16, 0 for INT8
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [2:0] activation_type,  // Select activation function
    input wire [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out
);

    // Activation types
    localparam NONE     = 3'b000;  // Pass-through
    localparam RELU     = 3'b001;  // ReLU (most common)
    localparam RELU6    = 3'b010;  // ReLU6 (capped at 6)
    localparam SIGMOID  = 3'b011;  // Sigmoid (approximate)
    localparam TANH     = 3'b100;  // Tanh (approximate)
    localparam LEAKY    = 3'b101;  // Leaky ReLU
    localparam SWISH    = 3'b110;  // Swish/SiLU
    localparam GELU     = 3'b111;  // GELU (approximate)
    
    // Internal signals
    wire signed [DATA_WIDTH-1:0] data_signed;
    reg signed [DATA_WIDTH-1:0] result;
    
    assign data_signed = data_in;
    
    // FP16 helper function to check sign
    function is_negative_fp16;
        input [15:0] fp16_val;
        begin
            is_negative_fp16 = fp16_val[15]; // Sign bit
        end
    endfunction
    
    // FP16 zero constant
    localparam [15:0] FP16_ZERO = 16'h0000;
    localparam [15:0] FP16_SIX = 16'h4600;  // 6.0 in FP16
    localparam [15:0] FP16_ONE = 16'h3C00;  // 1.0 in FP16
    localparam [15:0] FP16_HALF = 16'h3800; // 0.5 in FP16
    
    // Activation function implementation
    always @(*) begin
        case (activation_type)
            
            // ===== ReLU: max(0, x) =====
            // Most popular! Used in 90% of modern CNNs
            // Benefits: Fast, no vanishing gradient
            RELU: begin
                if (IS_FLOATING_POINT) begin
                    // FP16 ReLU
                    result = is_negative_fp16(data_in) ? FP16_ZERO : data_in;
                end else begin
                    // INT8 ReLU
                    result = (data_signed < 0) ? 0 : data_signed;
                end
            end
            
            // ===== ReLU6: min(max(0, x), 6) =====
            // Used in MobileNet, EfficientNet
            // Benefits: Bounded output, better for quantization
            RELU6: begin
                if (IS_FLOATING_POINT) begin
                    // FP16 ReLU6
                    if (is_negative_fp16(data_in))
                        result = FP16_ZERO;
                    else if (data_in > FP16_SIX)
                        result = FP16_SIX;
                    else
                        result = data_in;
                end else begin
                    // INT8 ReLU6 (assuming scale factor)
                    if (data_signed < 0)
                        result = 0;
                    else if (data_signed > 48)  // 6 * 8 (scale factor)
                        result = 48;
                    else
                        result = data_signed;
                end
            end
            
            // ===== Leaky ReLU: x if x > 0, else 0.01*x =====
            // Used when ReLU causes "dying neurons"
            // Benefits: Non-zero gradient for negative values
            LEAKY: begin
                if (IS_FLOATING_POINT) begin
                    // FP16 Leaky ReLU (alpha = 0.01)
                    if (is_negative_fp16(data_in))
                        result = data_in >> 7;  // Approximate divide by 128 ≈ 0.01
                    else
                        result = data_in;
                end else begin
                    // INT8 Leaky ReLU
                    result = (data_signed < 0) ? (data_signed >>> 7) : data_signed;
                end
            end
            
            // ===== Sigmoid: 1 / (1 + e^-x) =====
            // Used in: Output layer (binary classification), LSTM gates
            // Approximate using piecewise linear (hardware-efficient)
            SIGMOID: begin
                if (IS_FLOATING_POINT) begin
                    // FP16 Approximate Sigmoid
                    // Piecewise: 0 if x<-4, 1 if x>4, else linear
                    if (data_in[14:10] > 5'h12)  // x > 4
                        result = FP16_ONE;
                    else if (is_negative_fp16(data_in) && (data_in[14:10] > 5'h12))
                        result = FP16_ZERO;
                    else
                        result = FP16_HALF;  // Simplified
                end else begin
                    // INT8 Approximate Sigmoid (lookup table would be better)
                    if (data_signed > 32)
                        result = 127;  // Saturate to max
                    else if (data_signed < -32)
                        result = 0;
                    else
                        result = 64 + (data_signed >> 1);  // Linear approximation
                end
            end
            
            // ===== Tanh: (e^x - e^-x) / (e^x + e^-x) =====
            // Used in: LSTM, some CNNs
            // Approximate using piecewise linear
            TANH: begin
                if (IS_FLOATING_POINT) begin
                    // FP16 Approximate Tanh
                    if (data_in[14:10] > 5'h11)  // x > 2
                        result = FP16_ONE;
                    else if (is_negative_fp16(data_in) && (data_in[14:10] > 5'h11))
                        result = 16'hBC00;  // -1.0 in FP16
                    else
                        result = data_in;  // Linear in middle
                end else begin
                    // INT8 Approximate Tanh
                    if (data_signed > 64)
                        result = 127;
                    else if (data_signed < -64)
                        result = -128;
                    else
                        result = data_signed << 1;  // Linear approximation
                end
            end
            
            // ===== Swish/SiLU: x * sigmoid(x) =====
            // Used in: EfficientNet, modern architectures
            // Benefits: Smoother than ReLU, better gradient flow
            SWISH: begin
                if (IS_FLOATING_POINT) begin
                    // FP16 Approximate Swish
                    if (is_negative_fp16(data_in))
                        result = FP16_ZERO;  // Simplified
                    else
                        result = data_in;  // x * 1 for positive
                end else begin
                    // INT8 Approximate Swish
                    if (data_signed < 0)
                        result = data_signed >> 3;  // Small negative values
                    else
                        result = data_signed;
                end
            end
            
            // ===== GELU: 0.5 * x * (1 + tanh(sqrt(2/π) * (x + 0.044715*x³))) =====
            // Used in: Transformers (BERT, GPT), modern NLP
            // Approximate using simpler formula
            GELU: begin
                if (IS_FLOATING_POINT) begin
                    // FP16 Approximate GELU
                    if (is_negative_fp16(data_in))
                        result = FP16_ZERO;  // Very simplified
                    else
                        result = data_in;
                end else begin
                    // INT8 Approximate GELU
                    if (data_signed < -32)
                        result = 0;
                    else if (data_signed < 0)
                        result = data_signed >> 2;
                    else
                        result = data_signed;
                end
            end
            
            // ===== NONE: Pass-through =====
            default: begin
                result = data_in;
            end
            
        endcase
    end
    
    // Output register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= (IS_FLOATING_POINT) ? FP16_ZERO : {DATA_WIDTH{1'b0}};
        else if (enable)
            data_out <= result;
    end

endmodule


// Activation Layer - Apply activation to all outputs
module activation_layer #(
    parameter SIZE = 8,
    parameter DATA_WIDTH = 16,
    parameter IS_FLOATING_POINT = 1
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [2:0] activation_type,
    input wire [DATA_WIDTH-1:0] data_in [0:SIZE-1][0:SIZE-1],
    output wire [DATA_WIDTH-1:0] data_out [0:SIZE-1][0:SIZE-1]
);

    genvar i, j;
    generate
        for (i = 0; i < SIZE; i = i + 1) begin : gen_row
            for (j = 0; j < SIZE; j = j + 1) begin : gen_col
                activation_functions #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .IS_FLOATING_POINT(IS_FLOATING_POINT)
                ) act_func (
                    .clk(clk),
                    .rst_n(rst_n),
                    .enable(enable),
                    .activation_type(activation_type),
                    .data_in(data_in[i][j]),
                    .data_out(data_out[i][j])
                );
            end
        end
    endgenerate

endmodule


// LUT-based Sigmoid (more accurate but uses memory)
module sigmoid_lut #(
    parameter DATA_WIDTH = 8,
    parameter LUT_SIZE = 256
)(
    input wire [DATA_WIDTH-1:0] x_in,
    output reg [DATA_WIDTH-1:0] sigmoid_out
);

    // Pre-computed sigmoid lookup table
    // sigmoid(x) for x in range [-4, 4] mapped to [0, 255]
    always @(*) begin
        case (x_in)
            8'd0:   sigmoid_out = 8'd128;  // sigmoid(0) = 0.5
            8'd16:  sigmoid_out = 8'd138;  // sigmoid(0.5) ≈ 0.62
            8'd32:  sigmoid_out = 8'd156;  // sigmoid(1.0) ≈ 0.73
            8'd64:  sigmoid_out = 8'd193;  // sigmoid(2.0) ≈ 0.88
            8'd96:  sigmoid_out = 8'd225;  // sigmoid(3.0) ≈ 0.95
            8'd127: sigmoid_out = 8'd251;  // sigmoid(4.0) ≈ 0.98
            // Negative values
            8'd240: sigmoid_out = 8'd138;  // sigmoid(-0.5)
            8'd224: sigmoid_out = 8'd100;  // sigmoid(-1.0)
            8'd192: sigmoid_out = 8'd62;   // sigmoid(-2.0)
            8'd160: sigmoid_out = 8'd30;   // sigmoid(-3.0)
            8'd128: sigmoid_out = 8'd4;    // sigmoid(-4.0)
            default: sigmoid_out = 8'd128; // Default to 0.5
        endcase
    end

endmodule
