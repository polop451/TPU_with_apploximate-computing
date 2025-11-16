// Weight Buffer - Specialized for weight storage
module weight_buffer #(
    parameter DATA_WIDTH = 8,
    parameter NUM_WEIGHTS = 256
)(
    input wire clk,
    input wire rst_n,
    input wire load_enable,
    input wire [$clog2(NUM_WEIGHTS)-1:0] load_addr,
    input wire [DATA_WIDTH-1:0] load_data,
    input wire read_enable,
    input wire [$clog2(NUM_WEIGHTS)-1:0] read_addr,
    output reg [DATA_WIDTH-1:0] weight_data
);

    reg [DATA_WIDTH-1:0] weight_mem [0:NUM_WEIGHTS-1];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_data <= {DATA_WIDTH{1'b0}};
        end else begin
            if (load_enable)
                weight_mem[load_addr] <= load_data;
            if (read_enable)
                weight_data <= weight_mem[read_addr];
        end
    end

endmodule
