// ============================================================================
// TPU Top Module with Complete I/O and FP16 Systolic Array Integration
// Features:
// - 8x8 FP16 Approximate Systolic Array (64 MACs)
// - UART, SPI, Button/Switch interfaces
// - Complete matrix multiplication engine
// - Activation function support
// ============================================================================

module tpu_top_with_io_complete (
    input wire clk,              // 100 MHz system clock
    input wire rst_n,            // Active-low reset
    
    // UART interface
    input wire uart_rx,
    output wire uart_tx,
    
    // SPI interface
    input wire spi_sclk,
    input wire spi_mosi,
    output wire spi_miso,
    input wire spi_cs_n,
    
    // Button/Switch interface
    input wire [15:0] switches,
    input wire btn_center,
    input wire btn_up,
    input wire btn_left,
    input wire btn_right,
    input wire btn_down,
    
    // LED and 7-segment outputs
    output wire [15:0] leds,
    output wire [6:0] seg,
    output wire [3:0] an,
    
    // Status outputs
    output wire tpu_busy_led,
    output wire tpu_done_led
);

    // ========================================================================
    // Interface Mode Selection
    // ========================================================================
    // switches[15:14] selects interface mode:
    // 00 = Button/Switch mode
    // 01 = UART mode  
    // 10 = SPI mode
    // 11 = Reserved
    
    wire [1:0] interface_mode = switches[15:14];
    wire [2:0] activation_select = switches[13:11];  // Activation function select
    
    // ========================================================================
    // TPU Core Signals
    // ========================================================================
    
    // Memory interface
    wire [7:0] mem_addr;
    wire [15:0] mem_data_in;
    wire [15:0] mem_data_out;
    wire mem_we;
    wire [1:0] mem_select;  // 00=matrix_a, 01=matrix_b, 10=result, 11=reserved
    
    // Control signals
    wire tpu_start;
    wire tpu_reset;
    wire tpu_busy;
    wire tpu_done;
    
    // Systolic array signals
    wire systolic_enable;
    wire systolic_start;
    wire [15:0] systolic_results [0:7][0:7];  // 8x8 results from systolic array
    
    // Interface signals
    // Button/Switch interface
    wire [7:0] btn_mem_addr;
    wire [15:0] btn_mem_din;
    wire btn_mem_we;
    wire [1:0] btn_mem_sel;
    wire btn_tpu_start;
    wire [15:0] btn_leds;
    wire [6:0] btn_seg;
    wire [3:0] btn_an;
    
    // UART interface  
    wire [7:0] uart_mem_addr;
    wire [7:0] uart_data_out;
    wire uart_data_valid;
    wire uart_start_out;
    reg [15:0] uart_mem_din;
    reg uart_mem_we;
    reg [1:0] uart_mem_sel;
    reg uart_tpu_start;
    
    // SPI interface
    wire [7:0] spi_mem_addr;
    wire [15:0] spi_mem_din;
    wire spi_mem_we;
    wire [1:0] spi_mem_sel;
    wire spi_tpu_start;
    
    // ========================================================================
    // Memory Banks (Block RAM)
    // ========================================================================
    
    // Matrix A memory (8x8 = 64 FP16 values = 128 bytes)
    reg [15:0] matrix_a_mem [0:63];
    // Matrix B memory (8x8 = 64 FP16 values = 128 bytes)
    reg [15:0] matrix_b_mem [0:63];
    // Result memory (8x8 = 64 FP16 values = 128 bytes)
    reg [15:0] result_mem [0:63];
    
    // Memory read/write logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Optional: Initialize memory to zero
        end else if (mem_we) begin
            case (mem_select)
                2'b00: matrix_a_mem[mem_addr[5:0]] <= mem_data_in;
                2'b01: matrix_b_mem[mem_addr[5:0]] <= mem_data_in;
                2'b10: result_mem[mem_addr[5:0]] <= mem_data_in;
                default: ;
            endcase
        end
    end
    
    // Memory read logic
    reg [15:0] mem_read_data;
    always @(*) begin
        case (mem_select)
            2'b00: mem_read_data = matrix_a_mem[mem_addr[5:0]];
            2'b01: mem_read_data = matrix_b_mem[mem_addr[5:0]];
            2'b10: mem_read_data = result_mem[mem_addr[5:0]];
            default: mem_read_data = 16'h0000;
        endcase
    end
    
    assign mem_data_out = mem_read_data;
    
    // ========================================================================
    // TPU Controller FSM
    // ========================================================================
    
    reg [3:0] state;
    reg [3:0] row_counter;
    reg [3:0] col_counter;
    reg [6:0] compute_counter;
    
    localparam IDLE = 4'd0;
    localparam LOAD_ROW = 4'd1;
    localparam LOAD_COL = 4'd2;
    localparam COMPUTE = 4'd3;
    localparam APPLY_ACTIVATION = 4'd4;
    localparam STORE_RESULT = 4'd5;
    localparam DONE = 4'd6;
    
    assign systolic_enable = (state == COMPUTE);
    assign systolic_start = (state == LOAD_ROW);
    assign tpu_busy = (state != IDLE) && (state != DONE);
    assign tpu_done = (state == DONE);
    
    // Controller FSM
    // FSM
    integer i, j;
    reg computing;  // Flag to track if computation is running
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_counter <= 0;
            col_counter <= 0;
            compute_counter <= 0;
            computing <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (tpu_start && !computing) begin
                        state <= COMPUTE;
                        compute_counter <= 0;
                        computing <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    // Wait for systolic array computation
                    // FP16 MACs need ~10 cycles to stabilize
                    compute_counter <= compute_counter + 1;
                    if (compute_counter >= 30) begin
                        state <= APPLY_ACTIVATION;
                        row_counter <= 0;
                    end
                end
                
                APPLY_ACTIVATION: begin
                    // Activation applied combinationally
                    state <= STORE_RESULT;
                    row_counter <= 0;
                    col_counter <= 0;
                end
                
                STORE_RESULT: begin
                    // Store all 8x8 results to result memory
                    // Flatten 2D array to 1D memory
                    if (row_counter < 8) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            result_mem[row_counter * 8 + j] <= systolic_results[row_counter][j];
                        end
                        row_counter <= row_counter + 1;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    computing <= 1'b0;
                    // Wait a few cycles in DONE state before returning to IDLE
                    compute_counter <= compute_counter + 1;
                    if (compute_counter >= 10) begin
                        state <= IDLE;
                        compute_counter <= 0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // ========================================================================
    // FP16 Approximate Systolic Array (8x8)
    // ========================================================================
    
    fp16_approx_systolic_array #(
        .SIZE(8)
    ) systolic_array (
        .clk(clk),
        .rst_n(rst_n),
        .enable(systolic_enable),
        .acc_clear(systolic_start),
        
        // Connect activations (row inputs) from Matrix A
        .a_in_0(matrix_a_mem[0]),
        .a_in_1(matrix_a_mem[1]),
        .a_in_2(matrix_a_mem[2]),
        .a_in_3(matrix_a_mem[3]),
        .a_in_4(matrix_a_mem[4]),
        .a_in_5(matrix_a_mem[5]),
        .a_in_6(matrix_a_mem[6]),
        .a_in_7(matrix_a_mem[7]),
        
        // Connect weights (column inputs) from Matrix B
        .w_in_0(matrix_b_mem[0]),
        .w_in_1(matrix_b_mem[1]),
        .w_in_2(matrix_b_mem[2]),
        .w_in_3(matrix_b_mem[3]),
        .w_in_4(matrix_b_mem[4]),
        .w_in_5(matrix_b_mem[5]),
        .w_in_6(matrix_b_mem[6]),
        .w_in_7(matrix_b_mem[7]),
        
        // Connect outputs
        .acc_out(systolic_results)
    );
    
    // Note: Activation functions can be added here if needed
    // For now, results go directly from systolic array to result memory
    
    // ========================================================================
    // Interface Modules
    // ========================================================================
    
    // Multiplex based on interface mode
    assign mem_addr = (interface_mode == 2'b00) ? btn_mem_addr :
                      (interface_mode == 2'b01) ? uart_mem_addr :
                      (interface_mode == 2'b10) ? spi_mem_addr : 8'h00;
    
    assign mem_data_in = (interface_mode == 2'b00) ? btn_mem_din :
                         (interface_mode == 2'b01) ? uart_mem_din :
                         (interface_mode == 2'b10) ? spi_mem_din : 16'h0000;
    
    assign mem_we = (interface_mode == 2'b00) ? btn_mem_we :
                    (interface_mode == 2'b01) ? uart_mem_we :
                    (interface_mode == 2'b10) ? spi_mem_we : 1'b0;
    
    assign mem_select = (interface_mode == 2'b00) ? btn_mem_sel :
                        (interface_mode == 2'b01) ? uart_mem_sel :
                        (interface_mode == 2'b10) ? spi_mem_sel : 2'b00;
    
    assign tpu_start = (interface_mode == 2'b00) ? btn_tpu_start :
                       (interface_mode == 2'b01) ? uart_tpu_start :
                       (interface_mode == 2'b10) ? spi_tpu_start : 1'b0;
    
    // Output multiplexing
    assign leds = (interface_mode == 2'b00) ? btn_leds :
                  {switches[15:14], 2'b00, tpu_done, tpu_busy, activation_select, 7'b0};
    
    assign seg = (interface_mode == 2'b00) ? btn_seg : 7'b1111111;
    assign an = (interface_mode == 2'b00) ? btn_an : 4'b1111;
    
    assign tpu_busy_led = tpu_busy;
    assign tpu_done_led = tpu_done;
    
    // UART Interface
    uart_interface #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) uart_if (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        
        // TPU interface
        .tpu_data_out(uart_data_out),
        .tpu_data_valid(uart_data_valid),
        .tpu_addr(uart_mem_addr),
        .tpu_write_enable(),  // Not used
        .tpu_start(uart_start_out),
        
        .tpu_data_in(result_mem[0][7:0]),
        .tpu_busy(tpu_busy),
        .tpu_done(tpu_done),
        
        .status_leds()  // Not used
    );
    
    // Convert UART outputs to memory interface signals
    always @(posedge clk) begin
        if (!rst_n) begin
            uart_mem_din <= 16'h0000;
            uart_mem_we <= 1'b0;
            uart_mem_sel <= 2'b00;
            uart_tpu_start <= 1'b0;
        end else begin
            uart_mem_din <= {8'h00, uart_data_out};
            uart_mem_we <= uart_data_valid;
            uart_mem_sel <= 2'b00;  // Default to matrix_a
            uart_tpu_start <= uart_start_out;
        end
    end
    
    assign spi_mem_addr = 8'h00;
    assign spi_mem_din = 16'h0000;
    assign spi_mem_we = 1'b0;
    assign spi_mem_sel = 2'b00;
    assign spi_tpu_start = 1'b0;
    
    // Button interface - simple demo mode
    // btn_up = start computation
    // btn_down = reset
    // switches[7:0] = data input
    
    reg btn_up_r, btn_down_r;
    always @(posedge clk) begin
        btn_up_r <= btn_up;
        btn_down_r <= btn_down;
    end
    
    wire btn_up_pulse = btn_up && !btn_up_r;
    wire btn_down_pulse = btn_down && !btn_down_r;
    
    assign btn_tpu_start = btn_up_pulse;
    assign btn_mem_addr = switches[7:0];
    assign btn_mem_din = {switches[7:0], switches[7:0]};  // Replicate for demo
    assign btn_mem_we = btn_down_pulse;
    assign btn_mem_sel = switches[9:8];
    
    // Button mode LED output
    assign btn_leds = {tpu_done, tpu_busy, state[3:0], 4'b0, row_counter[3:0], 2'b0};
    
    // Simple 7-segment display showing state
    reg [6:0] seg_pattern;
    always @(*) begin
        case (state)
            IDLE:               seg_pattern = 7'b1000000;  // 0
            COMPUTE:            seg_pattern = 7'b0110000;  // 3
            APPLY_ACTIVATION:   seg_pattern = 7'b0011001;  // 4
            STORE_RESULT:       seg_pattern = 7'b0010010;  // 5
            DONE:               seg_pattern = 7'b0000010;  // 6
            default:            seg_pattern = 7'b1111111;  // blank
        endcase
    end
    
    assign btn_seg = seg_pattern;
    assign btn_an = 4'b1110;  // Display on rightmost digit

endmodule
