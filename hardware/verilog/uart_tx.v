// Simple UART TX
module uart_tx #(
    parameter CLKS_PER_BIT = 868
)(
    input wire clk,
    input wire rst_n,
    input wire tx_start,
    input wire [7:0] tx_data,
    output reg tx,
    output reg tx_busy,
    output reg tx_done
);

    localparam IDLE = 3'd0;
    localparam START = 3'd1;
    localparam DATA = 3'd2;
    localparam STOP = 3'd3;
    
    reg [2:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_count;
    reg [7:0] tx_shift;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx <= 1'b1;
            tx_busy <= 1'b0;
            tx_done <= 1'b0;
        end else begin
            tx_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_count <= 0;
                    bit_count <= 0;
                    
                    if (tx_start) begin
                        tx_shift <= tx_data;
                        tx_busy <= 1'b1;
                        state <= START;
                    end
                end
                
                START: begin
                    tx <= 1'b0;  // Start bit
                    if (clk_count == CLKS_PER_BIT) begin
                        clk_count <= 0;
                        state <= DATA;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
                
                DATA: begin
                    tx <= tx_shift[bit_count];
                    if (clk_count == CLKS_PER_BIT) begin
                        clk_count <= 0;
                        if (bit_count == 7) begin
                            state <= STOP;
                        end else begin
                            bit_count <= bit_count + 1;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
                
                STOP: begin
                    tx <= 1'b1;  // Stop bit
                    if (clk_count == CLKS_PER_BIT) begin
                        tx_done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
            endcase
        end
    end

endmodule
