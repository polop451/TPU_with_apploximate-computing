// Activation Buffer - Specialized for activation storage
module activation_buffer #(
    parameter DATA_WIDTH = 8,
    parameter NUM_ACTIVATIONS = 256
)(
    input wire clk,
    input wire rst_n,
    input wire load_enable,
    input wire [$clog2(NUM_ACTIVATIONS)-1:0] load_addr,
    input wire [DATA_WIDTH-1:0] load_data,
    input wire read_enable,
    input wire [$clog2(NUM_ACTIVATIONS)-1:0] read_addr,
    output reg [DATA_WIDTH-1:0] activation_data
);

    reg [DATA_WIDTH-1:0] activation_mem [0:NUM_ACTIVATIONS-1];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            activation_data <= {DATA_WIDTH{1'b0}};
        end else begin
            if (load_enable)
                activation_mem[load_addr] <= load_data;
            if (read_enable)
                activation_data <= activation_mem[read_addr];
        end
    end

endmodule
