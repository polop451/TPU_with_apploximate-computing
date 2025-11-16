// SPI Interface for TPU (faster than UART)
// Mode 0: CPOL=0, CPHA=0
// Support up to 25 MHz SPI clock

module spi_interface #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,          // System clock (100 MHz)
    input wire rst_n,
    
    // SPI pins
    input wire spi_sclk,     // SPI clock from master
    input wire spi_mosi,     // Master Out Slave In
    output reg spi_miso,     // Master In Slave Out
    input wire spi_cs_n,     // Chip select (active low)
    
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
    output wire [3:0] status
);

    // Synchronize SPI signals
    reg [2:0] sclk_sync;
    reg [2:0] cs_sync;
    reg [2:0] mosi_sync;
    
    always @(posedge clk) begin
        sclk_sync <= {sclk_sync[1:0], spi_sclk};
        cs_sync <= {cs_sync[1:0], spi_cs_n};
        mosi_sync <= {mosi_sync[1:0], spi_mosi};
    end
    
    wire sclk_rising = (sclk_sync[2:1] == 2'b01);
    wire sclk_falling = (sclk_sync[2:1] == 2'b10);
    wire cs_active = (cs_sync[2] == 1'b0);
    
    // SPI state machine
    reg [2:0] state;
    localparam IDLE = 3'd0;
    localparam RX_CMD = 3'd1;
    localparam RX_ADDR = 3'd2;
    localparam RX_DATA = 3'd3;
    localparam PROCESS = 3'd4;
    localparam TX_DATA = 3'd5;
    
    reg [7:0] rx_shift;
    reg [7:0] tx_shift;
    reg [2:0] bit_count;
    reg [7:0] command;
    reg [7:0] address;
    
    // Commands
    localparam CMD_WRITE = 8'h01;
    localparam CMD_READ = 8'h02;
    localparam CMD_START = 8'h03;
    localparam CMD_STATUS = 8'h04;
    
    assign status = {tpu_done, tpu_busy, state[1:0]};
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_count <= 0;
            tpu_data_valid <= 1'b0;
            tpu_write_enable <= 1'b0;
            tpu_start <= 1'b0;
            spi_miso <= 1'b0;
        end else begin
            tpu_data_valid <= 1'b0;
            tpu_write_enable <= 1'b0;
            tpu_start <= 1'b0;
            
            if (!cs_active) begin
                state <= IDLE;
                bit_count <= 0;
            end else begin
                case (state)
                    IDLE: begin
                        if (cs_active && sclk_rising) begin
                            state <= RX_CMD;
                            bit_count <= 0;
                        end
                    end
                    
                    RX_CMD: begin
                        if (sclk_rising) begin
                            rx_shift <= {rx_shift[6:0], mosi_sync[2]};
                            bit_count <= bit_count + 1;
                            if (bit_count == 7) begin
                                command <= {rx_shift[6:0], mosi_sync[2]};
                                bit_count <= 0;
                                if ({rx_shift[6:0], mosi_sync[2]} == CMD_START) begin
                                    state <= PROCESS;
                                end else if ({rx_shift[6:0], mosi_sync[2]} == CMD_STATUS) begin
                                    state <= TX_DATA;
                                    tx_shift <= {6'b0, tpu_done, tpu_busy};
                                end else begin
                                    state <= RX_ADDR;
                                end
                            end
                        end
                    end
                    
                    RX_ADDR: begin
                        if (sclk_rising) begin
                            rx_shift <= {rx_shift[6:0], mosi_sync[2]};
                            bit_count <= bit_count + 1;
                            if (bit_count == 7) begin
                                address <= {rx_shift[6:0], mosi_sync[2]};
                                tpu_addr <= {rx_shift[6:0], mosi_sync[2]};
                                bit_count <= 0;
                                if (command == CMD_READ) begin
                                    state <= TX_DATA;
                                    tx_shift <= tpu_data_in;
                                end else begin
                                    state <= RX_DATA;
                                end
                            end
                        end
                    end
                    
                    RX_DATA: begin
                        if (sclk_rising) begin
                            rx_shift <= {rx_shift[6:0], mosi_sync[2]};
                            bit_count <= bit_count + 1;
                            if (bit_count == 7) begin
                                tpu_data_out <= {rx_shift[6:0], mosi_sync[2]};
                                state <= PROCESS;
                            end
                        end
                    end
                    
                    PROCESS: begin
                        if (command == CMD_WRITE) begin
                            tpu_data_valid <= 1'b1;
                            tpu_write_enable <= 1'b1;
                        end else if (command == CMD_START) begin
                            tpu_start <= 1'b1;
                        end
                        state <= IDLE;
                    end
                    
                    TX_DATA: begin
                        if (sclk_falling) begin
                            spi_miso <= tx_shift[7];
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            bit_count <= bit_count + 1;
                            if (bit_count == 7) begin
                                state <= IDLE;
                            end
                        end
                    end
                endcase
            end
        end
    end

endmodule
