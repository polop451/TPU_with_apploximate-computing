// FP16 Approximate Systolic Array - 8x8 Configuration
// 64 MAC units for high throughput
// Approximate computing for reduced area
//
// Note: Configurable systolic array has been separated into fp16_configurable_systolic_array.v

module fp16_approx_systolic_array #(
    parameter SIZE = 8,              // 8x8 array (64 PEs)
    parameter APPROX_MULT_BITS = 6,  // Reduced mantissa bits
    parameter APPROX_ALIGN = 4       // Reduced alignment shift
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire acc_clear,
    
    // FP16 Activation inputs (one per row)
    input wire [15:0] a_in_0, a_in_1, a_in_2, a_in_3,
    input wire [15:0] a_in_4, a_in_5, a_in_6, a_in_7,
    
    // FP16 Weight inputs (one per column)
    input wire [15:0] w_in_0, w_in_1, w_in_2, w_in_3,
    input wire [15:0] w_in_4, w_in_5, w_in_6, w_in_7,
    
    // FP16 Accumulated outputs (8x8 = 64 outputs)
    output wire [15:0] acc_out [0:SIZE-1][0:SIZE-1]
);

    // Internal interconnect wires for activation data flow (horizontal)
    wire [15:0] a_wire [0:SIZE-1][0:SIZE];
    
    // Internal interconnect wires for weight data flow (vertical)
    wire [15:0] w_wire [0:SIZE][0:SIZE-1];
    
    // Internal accumulator output wires
    wire [15:0] acc_wire [0:SIZE-1][0:SIZE-1];
    
    // Connect activation inputs
    assign a_wire[0][0] = a_in_0;
    assign a_wire[1][0] = a_in_1;
    assign a_wire[2][0] = a_in_2;
    assign a_wire[3][0] = a_in_3;
    assign a_wire[4][0] = a_in_4;
    assign a_wire[5][0] = a_in_5;
    assign a_wire[6][0] = a_in_6;
    assign a_wire[7][0] = a_in_7;
    
    // Connect weight inputs
    assign w_wire[0][0] = w_in_0;
    assign w_wire[0][1] = w_in_1;
    assign w_wire[0][2] = w_in_2;
    assign w_wire[0][3] = w_in_3;
    assign w_wire[0][4] = w_in_4;
    assign w_wire[0][5] = w_in_5;
    assign w_wire[0][6] = w_in_6;
    assign w_wire[0][7] = w_in_7;
    
    // Connect outputs
    genvar i, j;
    generate
        for (i = 0; i < SIZE; i = i + 1) begin : gen_out_row
            for (j = 0; j < SIZE; j = j + 1) begin : gen_out_col
                assign acc_out[i][j] = acc_wire[i][j];
            end
        end
    endgenerate
    
    // Generate 8x8 array of approximate MAC units
    genvar row, col;
    generate
        for (row = 0; row < SIZE; row = row + 1) begin : gen_row
            for (col = 0; col < SIZE; col = col + 1) begin : gen_col
                fp16_approx_mac_unit #(
                    .APPROX_MULT_BITS(APPROX_MULT_BITS),
                    .APPROX_ALIGN(APPROX_ALIGN)
                ) pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .enable(enable),
                    .acc_clear(acc_clear),
                    .a_in(a_wire[row][col]),
                    .w_in(w_wire[row][col]),
                    .acc_in(16'h0000),
                    .a_out(a_wire[row][col+1]),
                    .w_out(w_wire[row+1][col]),
                    .acc_out(acc_wire[row][col])
                );
            end
        end
    endgenerate

endmodule
