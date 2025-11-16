// Memory Controller for Weight and Activation Buffers
// Optimized for systolic array data feeding
// Includes double buffering for continuous operation
//
// Note: Weight buffer and activation buffer have been separated
// into individual files: weight_buffer.v and activation_buffer.v

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
