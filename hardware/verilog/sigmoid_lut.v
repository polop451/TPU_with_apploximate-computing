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
