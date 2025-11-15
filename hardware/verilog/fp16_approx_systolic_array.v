// FP16 Approximate Systolic Array - 8x8 Configuration
// 64 MAC units for high throughput
// Approximate computing for reduced area

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


// Configurable Systolic Array - Choose between 4x4, 8x8, or 16x16
module fp16_configurable_systolic_array #(
    parameter SIZE = 8,
    parameter APPROX_MULT_BITS = 6,
    parameter APPROX_ALIGN = 4
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire acc_clear,
    input wire [1:0] size_select,  // 00=4x4, 01=8x8, 10=16x16
    
    // Flattened inputs (max 16x16)
    input wire [15:0] a_in [0:15],
    input wire [15:0] w_in [0:15],
    
    // Flattened outputs
    output wire [15:0] acc_out [0:15][0:15],
    
    // Performance counters
    output reg [31:0] cycle_count,
    output reg [31:0] mac_ops_count
);

    // Internal array instantiation
    wire [15:0] acc_internal [0:15][0:15];
    
    // Performance monitoring
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 32'd0;
            mac_ops_count <= 32'd0;
        end else if (enable) begin
            cycle_count <= cycle_count + 1;
            case (size_select)
                2'b00: mac_ops_count <= mac_ops_count + 16;   // 4x4 = 16 ops
                2'b01: mac_ops_count <= mac_ops_count + 64;   // 8x8 = 64 ops
                2'b10: mac_ops_count <= mac_ops_count + 256;  // 16x16 = 256 ops
                default: mac_ops_count <= mac_ops_count + 64;
            endcase
        end
    end
    
    // Connect outputs
    genvar i, j;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_out_i
            for (j = 0; j < 16; j = j + 1) begin : gen_out_j
                assign acc_out[i][j] = acc_internal[i][j];
            end
        end
    endgenerate
    
    // Instantiate processing elements (simplified - full implementation would be larger)
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_pe_row
            for (j = 0; j < 8; j = j + 1) begin : gen_pe_col
                fp16_approx_mac_unit #(
                    .APPROX_MULT_BITS(APPROX_MULT_BITS),
                    .APPROX_ALIGN(APPROX_ALIGN)
                ) pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .enable(enable),
                    .acc_clear(acc_clear),
                    .a_in(a_in[i]),
                    .w_in(w_in[j]),
                    .acc_in(16'h0000),
                    .a_out(),  // Not used in this simplified version
                    .w_out(),  // Not used in this simplified version
                    .acc_out(acc_internal[i][j])
                );
            end
        end
    endgenerate

endmodule
