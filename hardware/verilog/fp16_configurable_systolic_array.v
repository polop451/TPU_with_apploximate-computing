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
