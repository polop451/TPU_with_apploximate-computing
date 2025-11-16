`timescale 1ns/1ps

module test_tpu_simple;
    reg clk, rst_n;
    reg [15:0] switches;
    reg [4:0] buttons;
    wire [15:0] leds;
    wire tpu_busy_led, tpu_done_led;
    wire [6:0] seg;
    wire [3:0] an;
    
    // UART (not used)
    wire uart_tx;
    reg uart_rx = 1'b1;
    
    // SPI (not used)
    wire spi_miso;
    reg spi_sclk = 1'b0;
    reg spi_mosi = 1'b0;
    reg spi_cs_n = 1'b1;
    
    // Button assignments
    wire btn_center = buttons[0];
    wire btn_up = buttons[1];
    wire btn_left = buttons[2];
    wire btn_right = buttons[3];
    wire btn_down = buttons[4];
    
    // DUT
    tpu_top_with_io_complete dut (
        .clk(clk),
        .rst_n(rst_n),
        .switches(switches),
        .btn_center(btn_center),
        .btn_up(btn_up),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_down(btn_down),
        .leds(leds),
        .tpu_busy_led(tpu_busy_led),
        .tpu_done_led(tpu_done_led),
        .seg(seg),
        .an(an),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz
    
    // Debug monitoring
    always @(posedge clk) begin
        $display("T=%0t | btn_up=%b | tpu_start=%b | computing=%b | state=%d | busy=%b | done=%b", 
                 $time, btn_up, dut.tpu_start, dut.computing, dut.state, 
                 tpu_busy_led, tpu_done_led);
    end
    
    // Test
    initial begin
        $display("\n=== Simple TPU Test ===\n");
        
        // Initialize
        rst_n = 0;
        switches = 16'h0000;  // Button mode (00), activation=000
        buttons = 5'b00000;
        
        #100;
        rst_n = 1;
        #50;
        
        $display("After reset: state=%d, busy=%b, done=%b", 
                 dut.state, tpu_busy_led, tpu_done_led);
        
        // Write to memory
        $display("\nWriting to Matrix A[0]...");
        switches[9:8] = 2'b00;  // Select Matrix A
        switches[7:0] = 8'h00;  // Address 0
        switches[7:0] = 8'h3C;  // Data = 0x3C00 (1.0 in FP16)
        buttons[4] = 1;  // btn_down = write enable
        #20;
        buttons[4] = 0;
        #20;
        
        $display("Memory write done");
        
        // Start computation
        $display("\nStarting computation...");
        buttons[1] = 1;  // btn_up = start
        #20;
        buttons[1] = 0;
        #20;
        
        $display("After start: state=%d, busy=%b, done=%b", 
                 dut.state, tpu_busy_led, tpu_done_led);
        
        // Wait
        #1000;
        
        $display("\nFinal: state=%d, busy=%b, done=%b", 
                 dut.state, tpu_busy_led, tpu_done_led);
        
        $finish;
    end
endmodule
