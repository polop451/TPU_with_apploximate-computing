// TPU Top Module with Complete I/O Integration
// Supports UART, SPI, and Button/Switch interfaces for Basys3

module tpu_top_with_io (
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
    
    // Mode select (switches[15:14])
    // 00 = Button/Switch mode
    // 01 = UART mode
    // 10 = SPI mode
    // 11 = Reserved
    
    // Status outputs
    output wire tpu_busy_led,
    output wire tpu_done_led
);

    // Interface mode selection
    wire [1:0] interface_mode = switches[15:14];
    
    // TPU internal signals
    wire [7:0] tpu_data_out;
    wire tpu_data_valid;
    wire [7:0] tpu_addr;
    wire tpu_write_enable;
    wire tpu_start;
    wire [7:0] tpu_data_in;
    wire tpu_busy;
    wire tpu_done;
    
    // Interface outputs
    wire [7:0] uart_data_out, spi_data_out, btn_data_out;
    wire uart_valid, spi_valid, btn_valid;
    wire [7:0] uart_addr, spi_addr, btn_addr;
    wire uart_we, spi_we, btn_we;
    wire uart_start, spi_start, btn_start;
    
    wire [15:0] btn_leds;
    wire [6:0] btn_seg;
    wire [3:0] btn_an;
    
    // Multiplex interface signals based on mode
    assign tpu_data_out = (interface_mode == 2'b00) ? btn_data_out :
                         (interface_mode == 2'b01) ? uart_data_out :
                         (interface_mode == 2'b10) ? spi_data_out : 8'h00;
    
    assign tpu_data_valid = (interface_mode == 2'b00) ? btn_valid :
                           (interface_mode == 2'b01) ? uart_valid :
                           (interface_mode == 2'b10) ? spi_valid : 1'b0;
    
    assign tpu_addr = (interface_mode == 2'b00) ? btn_addr :
                     (interface_mode == 2'b01) ? uart_addr :
                     (interface_mode == 2'b10) ? spi_addr : 8'h00;
    
    assign tpu_write_enable = (interface_mode == 2'b00) ? btn_we :
                             (interface_mode == 2'b01) ? uart_we :
                             (interface_mode == 2'b10) ? spi_we : 1'b0;
    
    assign tpu_start = (interface_mode == 2'b00) ? btn_start :
                      (interface_mode == 2'b01) ? uart_start :
                      (interface_mode == 2'b10) ? spi_start : 1'b0;
    
    // Output multiplexing
    assign leds = (interface_mode == 2'b00) ? btn_leds : 
                  {switches[15:14], 6'b0, tpu_done, tpu_busy, 6'b0};
    
    assign seg = (interface_mode == 2'b00) ? btn_seg : 7'b1111111;
    assign an = (interface_mode == 2'b00) ? btn_an : 4'b1111;
    
    assign tpu_busy_led = tpu_busy;
    assign tpu_done_led = tpu_done;
    
    // UART Interface
    uart_interface uart_if (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .tpu_data_out(uart_data_out),
        .tpu_data_valid(uart_valid),
        .tpu_addr(uart_addr),
        .tpu_write_enable(uart_we),
        .tpu_start(uart_start),
        .tpu_data_in(tpu_data_in),
        .tpu_busy(tpu_busy),
        .tpu_done(tpu_done),
        .status_leds()  // Not used in multiplexed mode
    );
    
    // SPI Interface
    spi_interface spi_if (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        .tpu_data_out(spi_data_out),
        .tpu_data_valid(spi_valid),
        .tpu_addr(spi_addr),
        .tpu_write_enable(spi_we),
        .tpu_start(spi_start),
        .tpu_data_in(tpu_data_in),
        .tpu_busy(tpu_busy),
        .tpu_done(tpu_done),
        .status()
    );
    
    // Button/Switch Interface
    button_switch_interface btn_if (
        .clk(clk),
        .rst_n(rst_n),
        .switches(switches),
        .btn_center(btn_center),
        .btn_up(btn_up),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_down(btn_down),
        .leds(btn_leds),
        .seg(btn_seg),
        .an(btn_an),
        .tpu_data_out(btn_data_out),
        .tpu_data_valid(btn_valid),
        .tpu_addr(btn_addr),
        .tpu_write_enable(btn_we),
        .tpu_start(btn_start),
        .tpu_data_in(tpu_data_in),
        .tpu_busy(tpu_busy),
        .tpu_done(tpu_done)
    );
    
    // FP16 TPU Core (8x8 systolic array with approximate computing)
    // Weight memory (512 bytes = 256 FP16 values for 8x8 array with depth 4)
    reg [15:0] weight_mem [0:255];
    // Activation memory (512 bytes = 256 FP16 values)
    reg [15:0] activation_mem [0:255];
    // Result memory (512 bytes = 256 FP16 values for 8x8 output)
    reg [15:0] result_mem [0:255];
    
    // Memory interface
    always @(posedge clk) begin
        if (tpu_write_enable && tpu_data_valid) begin
            if (tpu_addr < 8'd128) begin
                // Write to weight memory (address 0-127, 2 bytes per location)
                if (tpu_addr[0] == 0)
                    weight_mem[tpu_addr[7:1]][7:0] <= tpu_data_out;
                else
                    weight_mem[tpu_addr[7:1]][15:8] <= tpu_data_out;
            end else begin
                // Write to activation memory (address 128-255)
                if (tpu_addr[0] == 0)
                    activation_mem[tpu_addr[7:1] - 64][7:0] <= tpu_data_out;
                else
                    activation_mem[tpu_addr[7:1] - 64][15:8] <= tpu_data_out;
            end
        end
    end
    
    // Read interface (simplified - returns lower 8 bits)
    reg [7:0] read_data;
    always @(*) begin
        if (tpu_addr < 8'd128)
            read_data = weight_mem[tpu_addr[7:1]][7:0];
        else if (tpu_addr < 8'd192)
            read_data = activation_mem[tpu_addr[7:1] - 64][7:0];
        else
            read_data = result_mem[tpu_addr[7:1] - 96][7:0];
    end
    
    assign tpu_data_in = read_data;
    
    // TPU control
    reg [3:0] state;
    localparam IDLE = 4'd0;
    localparam LOAD_WEIGHTS = 4'd1;
    localparam LOAD_ACTIVATIONS = 4'd2;
    localparam COMPUTE = 4'd3;
    localparam STORE_RESULTS = 4'd4;
    localparam DONE = 4'd5;
    
    reg [7:0] load_counter;
    reg compute_enable;
    reg [15:0] weight_data [0:7];
    reg [15:0] activation_data [0:7];
    wire [15:0] result_data [0:7];
    wire computation_done;
    
    assign tpu_busy = (state != IDLE) && (state != DONE);
    assign tpu_done = (state == DONE);
    
    // Simplified 8x8 systolic array (you can replace with fp16_approx_systolic_array)
    // For now, just a placeholder that copies activations to results
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : result_gen
            assign result_data[i] = activation_data[i];  // Placeholder
        end
    endgenerate
    
    assign computation_done = (load_counter == 8'd63);  // 8x8 = 64 cycles
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_counter <= 0;
            compute_enable <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (tpu_start) begin
                        state <= LOAD_WEIGHTS;
                        load_counter <= 0;
                    end
                end
                
                LOAD_WEIGHTS: begin
                    if (load_counter < 8) begin
                        weight_data[load_counter] <= weight_mem[load_counter];
                        load_counter <= load_counter + 1;
                    end else begin
                        state <= LOAD_ACTIVATIONS;
                        load_counter <= 0;
                    end
                end
                
                LOAD_ACTIVATIONS: begin
                    if (load_counter < 8) begin
                        activation_data[load_counter] <= activation_mem[load_counter];
                        load_counter <= load_counter + 1;
                    end else begin
                        state <= COMPUTE;
                        load_counter <= 0;
                        compute_enable <= 1;
                    end
                end
                
                COMPUTE: begin
                    // Simplified: just wait for computation
                    load_counter <= load_counter + 1;
                    if (computation_done) begin
                        state <= STORE_RESULTS;
                        load_counter <= 0;
                        compute_enable <= 0;
                    end
                end
                
                STORE_RESULTS: begin
                    if (load_counter < 8) begin
                        result_mem[load_counter] <= result_data[load_counter];
                        load_counter <= load_counter + 1;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    if (!tpu_start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
