// Systolic Array - 4x4 Processing Element Array
// High-performance matrix multiplication unit
// Uses pipelining for maximum throughput

module systolic_array #(
    parameter SIZE = 4,              // 4x4 array
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire acc_clear,
    
    // Activation inputs (one per row)
    input wire signed [DATA_WIDTH-1:0] a_in_0,
    input wire signed [DATA_WIDTH-1:0] a_in_1,
    input wire signed [DATA_WIDTH-1:0] a_in_2,
    input wire signed [DATA_WIDTH-1:0] a_in_3,
    
    // Weight inputs (one per column)
    input wire signed [DATA_WIDTH-1:0] w_in_0,
    input wire signed [DATA_WIDTH-1:0] w_in_1,
    input wire signed [DATA_WIDTH-1:0] w_in_2,
    input wire signed [DATA_WIDTH-1:0] w_in_3,
    
    // Accumulated outputs (one per PE)
    output wire signed [ACC_WIDTH-1:0] acc_out_00, acc_out_01, acc_out_02, acc_out_03,
    output wire signed [ACC_WIDTH-1:0] acc_out_10, acc_out_11, acc_out_12, acc_out_13,
    output wire signed [ACC_WIDTH-1:0] acc_out_20, acc_out_21, acc_out_22, acc_out_23,
    output wire signed [ACC_WIDTH-1:0] acc_out_30, acc_out_31, acc_out_32, acc_out_33
);

    // Internal interconnect wires for activation data flow (horizontal)
    wire signed [DATA_WIDTH-1:0] a_wire [0:SIZE-1][0:SIZE];
    
    // Internal interconnect wires for weight data flow (vertical)
    wire signed [DATA_WIDTH-1:0] w_wire [0:SIZE][0:SIZE-1];
    
    // Internal accumulator output wires from each PE
    wire signed [ACC_WIDTH-1:0] acc_wire [0:SIZE-1][0:SIZE-1];
    
    // Connect inputs
    assign a_wire[0][0] = a_in_0;
    assign a_wire[1][0] = a_in_1;
    assign a_wire[2][0] = a_in_2;
    assign a_wire[3][0] = a_in_3;
    
    assign w_wire[0][0] = w_in_0;
    assign w_wire[0][1] = w_in_1;
    assign w_wire[0][2] = w_in_2;
    assign w_wire[0][3] = w_in_3;
    
    // Connect internal accumulator outputs to output ports
    assign acc_out_00 = acc_wire[0][0];
    assign acc_out_01 = acc_wire[0][1];
    assign acc_out_02 = acc_wire[0][2];
    assign acc_out_03 = acc_wire[0][3];
    assign acc_out_10 = acc_wire[1][0];
    assign acc_out_11 = acc_wire[1][1];
    assign acc_out_12 = acc_wire[1][2];
    assign acc_out_13 = acc_wire[1][3];
    assign acc_out_20 = acc_wire[2][0];
    assign acc_out_21 = acc_wire[2][1];
    assign acc_out_22 = acc_wire[2][2];
    assign acc_out_23 = acc_wire[2][3];
    assign acc_out_30 = acc_wire[3][0];
    assign acc_out_31 = acc_wire[3][1];
    assign acc_out_32 = acc_wire[3][2];
    assign acc_out_33 = acc_wire[3][3];
    
    // Generate 4x4 array of MAC units
    genvar row, col;
    generate
        for (row = 0; row < SIZE; row = row + 1) begin : gen_row
            for (col = 0; col < SIZE; col = col + 1) begin : gen_col
                mac_unit #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .enable(enable),
                    .acc_clear(acc_clear),
                    .a_in(a_wire[row][col]),
                    .w_in(w_wire[row][col]),
                    .acc_in({ACC_WIDTH{1'b0}}),  // Not using daisy-chained accumulation
                    .a_out(a_wire[row][col+1]),
                    .w_out(w_wire[row+1][col]),
                    .acc_out(acc_wire[row][col])
                );
            end
        end
    endgenerate

endmodule
