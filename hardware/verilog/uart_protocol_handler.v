// UART Protocol Handler for TPU
// Implements protocol matching Python driver (tpu_fpga_interface.py)
// Commands: 0x01-0x08, Responses: 0xAA (ACK), 0x55 (NACK)

module uart_protocol_handler #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire rst_n,
    
    // UART physical interface
    input wire uart_rx,
    output wire uart_tx,
    
    // Memory interface
    output reg [7:0] mem_addr,
    output reg [15:0] mem_data_out,
    input wire [15:0] mem_data_in,
    output reg mem_we,
    output reg [1:0] mem_select,  // 00=matrix_a, 01=matrix_b, 10=result
    
    // TPU control
    output reg tpu_start,
    output reg tpu_reset,
    input wire tpu_busy,
    input wire tpu_done,
    
    // Status LEDs
    output reg [7:0] status_leds
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // Protocol commands (match Python driver)
    localparam CMD_WRITE_MATRIX_A = 8'h01;
    localparam CMD_WRITE_MATRIX_B = 8'h02;
    localparam CMD_READ_RESULT    = 8'h03;
    localparam CMD_START_COMPUTE  = 8'h04;
    localparam CMD_GET_STATUS     = 8'h05;
    localparam CMD_RESET          = 8'h06;
    localparam CMD_READ_MATRIX_A  = 8'h07;
    localparam CMD_READ_MATRIX_B  = 8'h08;
    
    // Response codes
    localparam RESP_ACK  = 8'hAA;
    localparam RESP_NACK = 8'h55;
    localparam RESP_BUSY = 8'hBB;
    localparam RESP_DONE = 8'hDD;
    
    // UART RX signals
    wire [7:0] rx_data;
    wire rx_valid;
    
    // UART TX signals
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_busy;
    wire tx_done;
    
    // UART modules
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );
    
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(uart_tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );
    
    // Protocol FSM
    localparam STATE_IDLE           = 4'd0;
    localparam STATE_RECV_CMD       = 4'd1;
    localparam STATE_SEND_ACK       = 4'd2;
    localparam STATE_RECV_DATA      = 4'd3;
    localparam STATE_WRITE_MEM      = 4'd4;
    localparam STATE_READ_MEM       = 4'd5;
    localparam STATE_SEND_DATA      = 4'd6;
    localparam STATE_SEND_STATUS    = 4'd7;
    localparam STATE_WAIT_TX        = 4'd8;
    localparam STATE_PROCESS_CMD    = 4'd9;
    
    reg [3:0] state;
    reg [7:0] cmd_reg;
    reg [7:0] byte_count;
    reg [7:0] total_bytes;
    reg [15:0] data_buffer;
    reg [7:0] addr_counter;
    
    // Data reception for multi-byte commands
    reg data_byte_low;  // Track if receiving low or high byte
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            cmd_reg <= 8'h00;
            byte_count <= 8'h00;
            total_bytes <= 8'h00;
            mem_addr <= 8'h00;
            mem_data_out <= 16'h0000;
            mem_we <= 1'b0;
            mem_select <= 2'b00;
            tpu_start <= 1'b0;
            tpu_reset <= 1'b0;
            tx_data <= 8'h00;
            tx_start <= 1'b0;
            status_leds <= 8'h00;
            data_buffer <= 16'h0000;
            addr_counter <= 8'h00;
            data_byte_low <= 1'b1;
        end else begin
            // Default values
            mem_we <= 1'b0;
            tpu_start <= 1'b0;
            tpu_reset <= 1'b0;
            tx_start <= 1'b0;
            
            case (state)
                STATE_IDLE: begin
                    status_leds[0] <= 1'b1;  // Idle indicator
                    if (rx_valid) begin
                        cmd_reg <= rx_data;
                        state <= STATE_PROCESS_CMD;
                    end
                end
                
                STATE_PROCESS_CMD: begin
                    case (cmd_reg)
                        CMD_WRITE_MATRIX_A: begin
                            mem_select <= 2'b00;  // Matrix A
                            total_bytes <= 8'd128; // 64 FP16 values * 2 bytes
                            byte_count <= 8'h00;
                            addr_counter <= 8'h00;
                            data_byte_low <= 1'b1;
                            state <= STATE_SEND_ACK;
                        end
                        
                        CMD_WRITE_MATRIX_B: begin
                            mem_select <= 2'b01;  // Matrix B
                            total_bytes <= 8'd128;
                            byte_count <= 8'h00;
                            addr_counter <= 8'h00;
                            data_byte_low <= 1'b1;
                            state <= STATE_SEND_ACK;
                        end
                        
                        CMD_READ_RESULT: begin
                            mem_select <= 2'b10;  // Result
                            total_bytes <= 8'd128;
                            byte_count <= 8'h00;
                            addr_counter <= 8'h00;
                            data_byte_low <= 1'b1;
                            state <= STATE_SEND_ACK;
                        end
                        
                        CMD_START_COMPUTE: begin
                            tpu_start <= 1'b1;
                            state <= STATE_SEND_ACK;
                        end
                        
                        CMD_GET_STATUS: begin
                            state <= STATE_SEND_ACK;
                        end
                        
                        CMD_RESET: begin
                            tpu_reset <= 1'b1;
                            state <= STATE_SEND_ACK;
                        end
                        
                        CMD_READ_MATRIX_A: begin
                            mem_select <= 2'b00;
                            total_bytes <= 8'd128;
                            byte_count <= 8'h00;
                            addr_counter <= 8'h00;
                            data_byte_low <= 1'b1;
                            state <= STATE_SEND_ACK;
                        end
                        
                        CMD_READ_MATRIX_B: begin
                            mem_select <= 2'b01;
                            total_bytes <= 8'd128;
                            byte_count <= 8'h00;
                            addr_counter <= 8'h00;
                            data_byte_low <= 1'b1;
                            state <= STATE_SEND_ACK;
                        end
                        
                        default: begin
                            // Unknown command - send NACK
                            tx_data <= RESP_NACK;
                            tx_start <= 1'b1;
                            state <= STATE_WAIT_TX;
                        end
                    endcase
                end
                
                STATE_SEND_ACK: begin
                    if (!tx_busy) begin
                        tx_data <= RESP_ACK;
                        tx_start <= 1'b1;
                        
                        // Determine next state based on command
                        case (cmd_reg)
                            CMD_WRITE_MATRIX_A, CMD_WRITE_MATRIX_B: begin
                                state <= STATE_RECV_DATA;
                            end
                            CMD_READ_RESULT, CMD_READ_MATRIX_A, CMD_READ_MATRIX_B: begin
                                state <= STATE_READ_MEM;
                            end
                            CMD_GET_STATUS: begin
                                state <= STATE_SEND_STATUS;
                            end
                            default: begin
                                state <= STATE_WAIT_TX;
                            end
                        endcase
                    end
                end
                
                STATE_RECV_DATA: begin
                    if (rx_valid) begin
                        if (data_byte_low) begin
                            // Receive low byte
                            data_buffer[7:0] <= rx_data;
                            data_byte_low <= 1'b0;
                        end else begin
                            // Receive high byte and write to memory
                            data_buffer[15:8] <= rx_data;
                            mem_data_out <= {rx_data, data_buffer[7:0]};
                            mem_addr <= addr_counter[5:0];
                            state <= STATE_WRITE_MEM;
                            data_byte_low <= 1'b1;
                        end
                        byte_count <= byte_count + 1;
                    end
                end
                
                STATE_WRITE_MEM: begin
                    mem_we <= 1'b1;
                    addr_counter <= addr_counter + 1;
                    
                    if (byte_count >= total_bytes) begin
                        state <= STATE_IDLE;
                    end else begin
                        state <= STATE_RECV_DATA;
                    end
                end
                
                STATE_READ_MEM: begin
                    mem_addr <= addr_counter[5:0];
                    state <= STATE_SEND_DATA;
                end
                
                STATE_SEND_DATA: begin
                    if (!tx_busy) begin
                        if (data_byte_low) begin
                            // Send low byte
                            tx_data <= mem_data_in[7:0];
                            tx_start <= 1'b1;
                            data_byte_low <= 1'b0;
                            state <= STATE_WAIT_TX;
                        end else begin
                            // Send high byte
                            tx_data <= mem_data_in[15:8];
                            tx_start <= 1'b1;
                            data_byte_low <= 1'b1;
                            byte_count <= byte_count + 2;
                            addr_counter <= addr_counter + 1;
                            
                            if (byte_count + 2 >= total_bytes) begin
                                state <= STATE_WAIT_TX;
                            end else begin
                                state <= STATE_WAIT_TX;
                            end
                        end
                    end
                end
                
                STATE_SEND_STATUS: begin
                    if (!tx_busy) begin
                        case (byte_count)
                            8'd0: begin
                                // Status byte: [2:error, 1:done, 0:busy]
                                tx_data <= {5'b0, 1'b0, tpu_done, tpu_busy};
                                tx_start <= 1'b1;
                                byte_count <= 8'd1;
                                state <= STATE_WAIT_TX;
                            end
                            8'd1, 8'd2, 8'd3: begin
                                // Cycle count (dummy for now - send zeros)
                                tx_data <= 8'h00;
                                tx_start <= 1'b1;
                                byte_count <= byte_count + 1;
                                if (byte_count == 8'd3) begin
                                    state <= STATE_WAIT_TX;
                                end else begin
                                    state <= STATE_WAIT_TX;
                                end
                            end
                        endcase
                    end
                end
                
                STATE_WAIT_TX: begin
                    if (tx_done) begin
                        if (cmd_reg == CMD_READ_RESULT || 
                            cmd_reg == CMD_READ_MATRIX_A || 
                            cmd_reg == CMD_READ_MATRIX_B) begin
                            if (byte_count >= total_bytes) begin
                                state <= STATE_IDLE;
                            end else begin
                                state <= STATE_READ_MEM;
                            end
                        end else if (cmd_reg == CMD_GET_STATUS) begin
                            if (byte_count >= 8'd4) begin
                                byte_count <= 8'd0;
                                state <= STATE_IDLE;
                            end else begin
                                state <= STATE_SEND_STATUS;
                            end
                        end else begin
                            state <= STATE_IDLE;
                        end
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
            
            // Status LED updates
            status_leds[1] <= tpu_busy;
            status_leds[2] <= tpu_done;
            status_leds[3] <= rx_valid;
            status_leds[4] <= tx_busy;
        end
    end

endmodule
