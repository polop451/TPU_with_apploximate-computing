// TPU Top Module - Integrated Tensor Processing Unit
// Optimized for Basys3 FPGA board
// Features: 4x4 Systolic Array, Weight/Activation Buffers, Control Unit

module tpu_top #(
    parameter SIZE = 4,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32,
    parameter NUM_WEIGHTS = 256,
    parameter NUM_ACTIVATIONS = 256
)(
    // Clock and reset
    input wire clk,
    input wire rst_n,
    
    // Control interface
    input wire start,
    input wire [7:0] matrix_size,
    
    // Data loading interface (simplified for demo)
    input wire load_weight,
    input wire load_activation,
    input wire [7:0] load_addr,
    input wire [DATA_WIDTH-1:0] load_data,
    
    // Status outputs
    output wire busy,
    output wire done,
    
    // Debug outputs to LEDs (Basys3 has 16 LEDs)
    output wire [15:0] led,
    
    // Result readout (simplified - reading first 4 results)
    output wire [ACC_WIDTH-1:0] result_0,
    output wire [ACC_WIDTH-1:0] result_1,
    output wire [ACC_WIDTH-1:0] result_2,
    output wire [ACC_WIDTH-1:0] result_3
);

    // Internal signals
    wire weight_load_enable, activation_load_enable;
    wire weight_read_enable, activation_read_enable;
    wire [7:0] weight_addr_ctrl, activation_addr_ctrl;
    wire array_enable, acc_clear;
    wire [7:0] cycle_counter;
    
    // Weight and activation data
    wire signed [DATA_WIDTH-1:0] weight_data [0:SIZE-1];
    wire signed [DATA_WIDTH-1:0] activation_data [0:SIZE-1];
    
    // Systolic array outputs
    wire signed [ACC_WIDTH-1:0] acc_out_00, acc_out_01, acc_out_02, acc_out_03;
    wire signed [ACC_WIDTH-1:0] acc_out_10, acc_out_11, acc_out_12, acc_out_13;
    wire signed [ACC_WIDTH-1:0] acc_out_20, acc_out_21, acc_out_22, acc_out_23;
    wire signed [ACC_WIDTH-1:0] acc_out_30, acc_out_31, acc_out_32, acc_out_33;
    
    // Address selection (load vs compute)
    wire [7:0] weight_addr = load_weight ? load_addr : weight_addr_ctrl;
    wire [7:0] activation_addr = load_activation ? load_addr : activation_addr_ctrl;
    
    // Control Unit
    tpu_controller #(
        .SIZE(SIZE),
        .DATA_WIDTH(DATA_WIDTH)
    ) controller (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .matrix_size(matrix_size),
        .weight_load_enable(weight_load_enable),
        .activation_load_enable(activation_load_enable),
        .weight_read_enable(weight_read_enable),
        .activation_read_enable(activation_read_enable),
        .weight_addr(weight_addr_ctrl),
        .activation_addr(activation_addr_ctrl),
        .array_enable(array_enable),
        .acc_clear(acc_clear),
        .busy(busy),
        .done(done),
        .cycle_counter(cycle_counter)
    );
    
    // Weight Buffers (one per column)
    genvar i;
    generate
        for (i = 0; i < SIZE; i = i + 1) begin : gen_weight_buffers
            weight_buffer #(
                .DATA_WIDTH(DATA_WIDTH),
                .NUM_WEIGHTS(NUM_WEIGHTS)
            ) wb (
                .clk(clk),
                .rst_n(rst_n),
                .load_enable(load_weight || weight_load_enable),
                .load_addr(weight_addr),
                .load_data(load_data),
                .read_enable(weight_read_enable),
                .read_addr(weight_addr_ctrl + i),  // Offset for each column
                .weight_data(weight_data[i])
            );
        end
    endgenerate
    
    // Activation Buffers (one per row)
    generate
        for (i = 0; i < SIZE; i = i + 1) begin : gen_activation_buffers
            activation_buffer #(
                .DATA_WIDTH(DATA_WIDTH),
                .NUM_ACTIVATIONS(NUM_ACTIVATIONS)
            ) ab (
                .clk(clk),
                .rst_n(rst_n),
                .load_enable(load_activation || activation_load_enable),
                .load_addr(activation_addr),
                .load_data(load_data),
                .read_enable(activation_read_enable),
                .read_addr(activation_addr_ctrl + i),  // Offset for each row
                .activation_data(activation_data[i])
            );
        end
    endgenerate
    
    // Systolic Array
    systolic_array #(
        .SIZE(SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) sa (
        .clk(clk),
        .rst_n(rst_n),
        .enable(array_enable),
        .acc_clear(acc_clear),
        .a_in_0(activation_data[0]),
        .a_in_1(activation_data[1]),
        .a_in_2(activation_data[2]),
        .a_in_3(activation_data[3]),
        .w_in_0(weight_data[0]),
        .w_in_1(weight_data[1]),
        .w_in_2(weight_data[2]),
        .w_in_3(weight_data[3]),
        .acc_out_00(acc_out_00), .acc_out_01(acc_out_01), .acc_out_02(acc_out_02), .acc_out_03(acc_out_03),
        .acc_out_10(acc_out_10), .acc_out_11(acc_out_11), .acc_out_12(acc_out_12), .acc_out_13(acc_out_13),
        .acc_out_20(acc_out_20), .acc_out_21(acc_out_21), .acc_out_22(acc_out_22), .acc_out_23(acc_out_23),
        .acc_out_30(acc_out_30), .acc_out_31(acc_out_31), .acc_out_32(acc_out_32), .acc_out_33(acc_out_33)
    );
    
    // Output assignments
    assign result_0 = acc_out_00;
    assign result_1 = acc_out_01;
    assign result_2 = acc_out_02;
    assign result_3 = acc_out_03;
    
    // LED debug outputs
    assign led[0] = busy;
    assign led[1] = done;
    assign led[2] = array_enable;
    assign led[3] = acc_clear;
    assign led[15:8] = cycle_counter;
    assign led[7:4] = matrix_size[3:0];

endmodule
