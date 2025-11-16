// Simple UART RX
module uart_rx #(
    parameter CLKS_PER_BIT = 868  // 100MHz / 115200
)(
    input wire clk,
    input wire rst_n,
    input wire rx,
    output reg [7:0] rx_data,
    output reg rx_valid
);

    localparam IDLE = 3'd0;
    localparam START = 3'd1;
    localparam DATA = 3'd2;
    localparam STOP = 3'd3;
    
    reg [2:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_count;
    reg [7:0] rx_shift;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rx_valid <= 1'b0;
            clk_count <= 0;
            bit_count <= 0;
        end else begin
            rx_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_count <= 0;
                    if (rx == 1'b0) begin  // Start bit
                        state <= START;
                    end
                end
                
                START: begin
                    if (clk_count == CLKS_PER_BIT/2) begin
                        if (rx == 1'b0) begin
                            clk_count <= 0;
                            state <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
                
                DATA: begin
                    if (clk_count == CLKS_PER_BIT) begin
                        clk_count <= 0;
                        rx_shift[bit_count] <= rx;
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
                    if (clk_count == CLKS_PER_BIT) begin
                        rx_data <= rx_shift;
                        rx_valid <= 1'b1;
                        state <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
            endcase
        end
    end

endmodule
