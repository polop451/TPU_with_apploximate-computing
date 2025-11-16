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
    
    // FP16 Accumulated outputs (8x8 = 64 individual outputs)
    output wire [15:0] acc_out_00, acc_out_01, acc_out_02, acc_out_03, acc_out_04, acc_out_05, acc_out_06, acc_out_07,
    output wire [15:0] acc_out_10, acc_out_11, acc_out_12, acc_out_13, acc_out_14, acc_out_15, acc_out_16, acc_out_17,
    output wire [15:0] acc_out_20, acc_out_21, acc_out_22, acc_out_23, acc_out_24, acc_out_25, acc_out_26, acc_out_27,
    output wire [15:0] acc_out_30, acc_out_31, acc_out_32, acc_out_33, acc_out_34, acc_out_35, acc_out_36, acc_out_37,
    output wire [15:0] acc_out_40, acc_out_41, acc_out_42, acc_out_43, acc_out_44, acc_out_45, acc_out_46, acc_out_47,
    output wire [15:0] acc_out_50, acc_out_51, acc_out_52, acc_out_53, acc_out_54, acc_out_55, acc_out_56, acc_out_57,
    output wire [15:0] acc_out_60, acc_out_61, acc_out_62, acc_out_63, acc_out_64, acc_out_65, acc_out_66, acc_out_67,
    output wire [15:0] acc_out_70, acc_out_71, acc_out_72, acc_out_73, acc_out_74, acc_out_75, acc_out_76, acc_out_77
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
    
    // Connect outputs to individual ports
    // Row 0
    assign acc_out_00 = acc_wire[0][0];
    assign acc_out_01 = acc_wire[0][1];
    assign acc_out_02 = acc_wire[0][2];
    assign acc_out_03 = acc_wire[0][3];
    assign acc_out_04 = acc_wire[0][4];
    assign acc_out_05 = acc_wire[0][5];
    assign acc_out_06 = acc_wire[0][6];
    assign acc_out_07 = acc_wire[0][7];
    
    // Row 1
    assign acc_out_10 = acc_wire[1][0];
    assign acc_out_11 = acc_wire[1][1];
    assign acc_out_12 = acc_wire[1][2];
    assign acc_out_13 = acc_wire[1][3];
    assign acc_out_14 = acc_wire[1][4];
    assign acc_out_15 = acc_wire[1][5];
    assign acc_out_16 = acc_wire[1][6];
    assign acc_out_17 = acc_wire[1][7];
    
    // Row 2
    assign acc_out_20 = acc_wire[2][0];
    assign acc_out_21 = acc_wire[2][1];
    assign acc_out_22 = acc_wire[2][2];
    assign acc_out_23 = acc_wire[2][3];
    assign acc_out_24 = acc_wire[2][4];
    assign acc_out_25 = acc_wire[2][5];
    assign acc_out_26 = acc_wire[2][6];
    assign acc_out_27 = acc_wire[2][7];
    
    // Row 3
    assign acc_out_30 = acc_wire[3][0];
    assign acc_out_31 = acc_wire[3][1];
    assign acc_out_32 = acc_wire[3][2];
    assign acc_out_33 = acc_wire[3][3];
    assign acc_out_34 = acc_wire[3][4];
    assign acc_out_35 = acc_wire[3][5];
    assign acc_out_36 = acc_wire[3][6];
    assign acc_out_37 = acc_wire[3][7];
    
    // Row 4
    assign acc_out_40 = acc_wire[4][0];
    assign acc_out_41 = acc_wire[4][1];
    assign acc_out_42 = acc_wire[4][2];
    assign acc_out_43 = acc_wire[4][3];
    assign acc_out_44 = acc_wire[4][4];
    assign acc_out_45 = acc_wire[4][5];
    assign acc_out_46 = acc_wire[4][6];
    assign acc_out_47 = acc_wire[4][7];
    
    // Row 5
    assign acc_out_50 = acc_wire[5][0];
    assign acc_out_51 = acc_wire[5][1];
    assign acc_out_52 = acc_wire[5][2];
    assign acc_out_53 = acc_wire[5][3];
    assign acc_out_54 = acc_wire[5][4];
    assign acc_out_55 = acc_wire[5][5];
    assign acc_out_56 = acc_wire[5][6];
    assign acc_out_57 = acc_wire[5][7];
    
    // Row 6
    assign acc_out_60 = acc_wire[6][0];
    assign acc_out_61 = acc_wire[6][1];
    assign acc_out_62 = acc_wire[6][2];
    assign acc_out_63 = acc_wire[6][3];
    assign acc_out_64 = acc_wire[6][4];
    assign acc_out_65 = acc_wire[6][5];
    assign acc_out_66 = acc_wire[6][6];
    assign acc_out_67 = acc_wire[6][7];
    
    // Row 7
    assign acc_out_70 = acc_wire[7][0];
    assign acc_out_71 = acc_wire[7][1];
    assign acc_out_72 = acc_wire[7][2];
    assign acc_out_73 = acc_wire[7][3];
    assign acc_out_74 = acc_wire[7][4];
    assign acc_out_75 = acc_wire[7][5];
    assign acc_out_76 = acc_wire[7][6];
    assign acc_out_77 = acc_wire[7][7];
    
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
