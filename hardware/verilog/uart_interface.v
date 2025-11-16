// UART Interface for TPU
// 115200 baud rate, 8N1
// Simple protocol for loading data and reading results
//
// Note: UART RX and TX modules have been separated into individual files:
// - uart_rx.v
// - uart_tx.v

module uart_interface #(
    parameter CLK_FREQ = 100_000_000,  // 100 MHz
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire rst_n,
    
    // UART pins
    input wire uart_rx,
    output wire uart_tx,
    
    // TPU interface
    output reg [7:0] tpu_data_out,
    output reg tpu_data_valid,
    output reg [7:0] tpu_addr,
    output reg tpu_write_enable,
    output reg tpu_start,
    
    input wire [7:0] tpu_data_in,
    input wire tpu_busy,
    input wire tpu_done,
    
    // Status
    output reg [7:0] status_leds
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // UART RX
    reg [7:0] rx_data;
    reg rx_data_valid;
    
    // UART TX
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_busy;
    wire tx_done;
    
    // Command decoder
    localparam CMD_WRITE_WEIGHT = 8'h57;     // 'W'
    localparam CMD_WRITE_ACTIVATION = 8'h41; // 'A'
    localparam CMD_START = 8'h53;            // 'S'
    localparam CMD_READ_RESULT = 8'h52;      // 'R'
    localparam CMD_STATUS = 8'h3F;           // '?'
    
    reg [2:0] state;
    localparam IDLE = 3'd0;
    localparam WAIT_ADDR = 3'd1;
    localparam WAIT_DATA = 3'd2;
    localparam PROCESS = 3'd3;
    localparam SEND_RESPONSE = 3'd4;
    
    reg [7:0] current_cmd;
    reg [7:0] current_addr;
    
    // UART RX module
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .rx_data(rx_data),
        .rx_valid(rx_data_valid)
    );
    
    // UART TX module
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(uart_tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );
    
    // Command processor
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tpu_data_valid <= 1'b0;
            tpu_write_enable <= 1'b0;
            tpu_start <= 1'b0;
            tx_start <= 1'b0;
            status_leds <= 8'h00;
            current_cmd <= 8'h00;
        end else begin
            // Default
            tpu_data_valid <= 1'b0;
            tpu_write_enable <= 1'b0;
            tpu_start <= 1'b0;
            tx_start <= 1'b0;
            
            case (state)
                IDLE: begin
                    status_leds[0] <= 1'b1;  // Idle indicator
                    if (rx_data_valid) begin
                        current_cmd <= rx_data;
                        case (rx_data)
                            CMD_WRITE_WEIGHT,
                            CMD_WRITE_ACTIVATION,
                            CMD_READ_RESULT: state <= WAIT_ADDR;
                            CMD_START: begin
                                tpu_start <= 1'b1;
                                state <= PROCESS;
                            end
                            CMD_STATUS: begin
                                tx_data <= {6'b0, tpu_done, tpu_busy};
                                tx_start <= 1'b1;
                                state <= SEND_RESPONSE;
                            end
                        endcase
                    end
                end
                
                WAIT_ADDR: begin
                    if (rx_data_valid) begin
                        current_addr <= rx_data;
                        tpu_addr <= rx_data;
                        if (current_cmd == CMD_READ_RESULT)
                            state <= PROCESS;
                        else
                            state <= WAIT_DATA;
                    end
                end
                
                WAIT_DATA: begin
                    if (rx_data_valid) begin
                        tpu_data_out <= rx_data;
                        tpu_data_valid <= 1'b1;
                        tpu_write_enable <= 1'b1;
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    status_leds[1] <= 1'b1;  // Processing
                    if (current_cmd == CMD_READ_RESULT) begin
                        tx_data <= tpu_data_in;
                        tx_start <= 1'b1;
                        state <= SEND_RESPONSE;
                    end else begin
                        // Send ACK
                        tx_data <= 8'h06;  // ACK
                        tx_start <= 1'b1;
                        state <= SEND_RESPONSE;
                    end
                end
                
                SEND_RESPONSE: begin
                    if (tx_done) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
