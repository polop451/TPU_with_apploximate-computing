// Memory Controller for Weight and Activation Buffers
// Optimized for systolic array data feeding
// Includes double buffering for continuous operation

module memory_controller #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10,
    parameter BUFFER_SIZE = 1024  // 1KB buffer
)(
    input wire clk,
    input wire rst_n,
    
    // Control signals
    input wire load_enable,
    input wire read_enable,
    input wire buffer_select,  // 0: buffer A, 1: buffer B (double buffering)
    
    // Write interface (for loading data)
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire wr_enable,
    
    // Read interface (sequential for systolic array)
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output reg [DATA_WIDTH-1:0] rd_data,
    
    // Status
    output reg buffer_ready
);

    // Dual-port RAM for double buffering
    reg [DATA_WIDTH-1:0] buffer_A [0:BUFFER_SIZE-1];
    reg [DATA_WIDTH-1:0] buffer_B [0:BUFFER_SIZE-1];
    
    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_ready <= 1'b0;
            rd_data <= {DATA_WIDTH{1'b0}};
        end else begin
            // Write operation
            if (wr_enable) begin
                if (buffer_select == 1'b0)
                    buffer_A[wr_addr] <= wr_data;
                else
                    buffer_B[wr_addr] <= wr_data;
            end
            
            // Read operation
            if (read_enable) begin
                if (buffer_select == 1'b0)
                    rd_data <= buffer_A[rd_addr];
                else
                    rd_data <= buffer_B[rd_addr];
            end
            
            // Buffer ready signal
            buffer_ready <= load_enable;
        end
    end

endmodule


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
