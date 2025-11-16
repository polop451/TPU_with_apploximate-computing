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
