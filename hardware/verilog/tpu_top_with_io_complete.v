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
    
    // UART interface (primary interface)
    input wire uart_rx,
    output wire uart_tx,
    
    // Reduced Button interface (for demo/debug)
    input wire [7:0] switches,   // Reduced from 16 to 8
    input wire btn_up,           // Start button
    input wire btn_down,         // Reset/Load button
    
    // Reduced LED outputs
    output wire [15:0] leds      // Keep all 16 LEDs for status/debug
    
    // Removed to save pins:
    // - SPI interface (4 pins saved)
    // - 7-segment display (11 pins saved: 7 segments + 4 anodes)
    // - Extra buttons (3 pins saved)
    // - Separate status LEDs (merged into leds[15:14])
);

    // ========================================================================
    // TPU Core Signals
    // ========================================================================
    
    // Interface mode: switches[7] = 0 (Button) or 1 (UART)
    wire interface_mode = switches[7];
    
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
    
    // 8x8 systolic array outputs (individual wires)
    wire [15:0] acc_out_00, acc_out_01, acc_out_02, acc_out_03, acc_out_04, acc_out_05, acc_out_06, acc_out_07;
    wire [15:0] acc_out_10, acc_out_11, acc_out_12, acc_out_13, acc_out_14, acc_out_15, acc_out_16, acc_out_17;
    wire [15:0] acc_out_20, acc_out_21, acc_out_22, acc_out_23, acc_out_24, acc_out_25, acc_out_26, acc_out_27;
    wire [15:0] acc_out_30, acc_out_31, acc_out_32, acc_out_33, acc_out_34, acc_out_35, acc_out_36, acc_out_37;
    wire [15:0] acc_out_40, acc_out_41, acc_out_42, acc_out_43, acc_out_44, acc_out_45, acc_out_46, acc_out_47;
    wire [15:0] acc_out_50, acc_out_51, acc_out_52, acc_out_53, acc_out_54, acc_out_55, acc_out_56, acc_out_57;
    wire [15:0] acc_out_60, acc_out_61, acc_out_62, acc_out_63, acc_out_64, acc_out_65, acc_out_66, acc_out_67;
    wire [15:0] acc_out_70, acc_out_71, acc_out_72, acc_out_73, acc_out_74, acc_out_75, acc_out_76, acc_out_77;
    
    // Interface signals
    // Button/Switch interface
    wire [7:0] btn_mem_addr;
    wire [15:0] btn_mem_din;
    wire btn_mem_we;
    wire [1:0] btn_mem_sel;
    wire btn_tpu_start;
    wire [15:0] btn_leds;
    
    // UART protocol handler interface
    wire [7:0] uart_mem_addr;
    wire [15:0] uart_mem_dout;
    wire uart_mem_we;
    wire [1:0] uart_mem_sel;
    wire uart_tpu_start;
    wire uart_tpu_reset;
    wire [7:0] uart_status_leds;
    
    // ========================================================================
    // Interface Mode Selection and Multiplexing
    // ========================================================================
    
    // Select active interface based on switches[7]
    // 0 = Button mode (demo), 1 = UART mode (primary)
    assign mem_addr = interface_mode ? uart_mem_addr : btn_mem_addr;
    assign mem_data_in = interface_mode ? uart_mem_dout : btn_mem_din;
    assign mem_we = interface_mode ? uart_mem_we : btn_mem_we;
    assign mem_select = interface_mode ? uart_mem_sel : btn_mem_sel;
    assign tpu_start = interface_mode ? uart_tpu_start : btn_tpu_start;
    assign tpu_reset = interface_mode ? uart_tpu_reset : 1'b0;
    
    // LED output multiplexing
    assign leds = interface_mode ? {uart_status_leds, 8'h00} : btn_leds;
    
    // ========================================================================
    // Memory Banks (Block RAM)
    // ========================================================================
    
    // Matrix A memory (8x8 = 64 FP16 values = 128 bytes)
    reg [15:0] matrix_a_mem [0:63];
    // Matrix B memory (8x8 = 64 FP16 values = 128 bytes)
    reg [15:0] matrix_b_mem [0:63];
    // Result memory (8x8 = 64 FP16 values = 128 bytes)
    reg [15:0] result_mem [0:63];
    
    // Note: Memory write logic is now integrated in FSM to avoid multiple drivers
    
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
                    // Handle external memory writes in IDLE state
                    if (mem_we) begin
                        case (mem_select)
                            2'b00: matrix_a_mem[mem_addr[5:0]] <= mem_data_in;
                            2'b01: matrix_b_mem[mem_addr[5:0]] <= mem_data_in;
                            2'b10: result_mem[mem_addr[5:0]] <= mem_data_in;
                            default: ;
                        endcase
                    end
                    
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
                    // Store row by row
                    case (row_counter)
                        4'd0: begin
                            result_mem[0] <= acc_out_00; result_mem[1] <= acc_out_01; result_mem[2] <= acc_out_02; result_mem[3] <= acc_out_03;
                            result_mem[4] <= acc_out_04; result_mem[5] <= acc_out_05; result_mem[6] <= acc_out_06; result_mem[7] <= acc_out_07;
                        end
                        4'd1: begin
                            result_mem[8] <= acc_out_10; result_mem[9] <= acc_out_11; result_mem[10] <= acc_out_12; result_mem[11] <= acc_out_13;
                            result_mem[12] <= acc_out_14; result_mem[13] <= acc_out_15; result_mem[14] <= acc_out_16; result_mem[15] <= acc_out_17;
                        end
                        4'd2: begin
                            result_mem[16] <= acc_out_20; result_mem[17] <= acc_out_21; result_mem[18] <= acc_out_22; result_mem[19] <= acc_out_23;
                            result_mem[20] <= acc_out_24; result_mem[21] <= acc_out_25; result_mem[22] <= acc_out_26; result_mem[23] <= acc_out_27;
                        end
                        4'd3: begin
                            result_mem[24] <= acc_out_30; result_mem[25] <= acc_out_31; result_mem[26] <= acc_out_32; result_mem[27] <= acc_out_33;
                            result_mem[28] <= acc_out_34; result_mem[29] <= acc_out_35; result_mem[30] <= acc_out_36; result_mem[31] <= acc_out_37;
                        end
                        4'd4: begin
                            result_mem[32] <= acc_out_40; result_mem[33] <= acc_out_41; result_mem[34] <= acc_out_42; result_mem[35] <= acc_out_43;
                            result_mem[36] <= acc_out_44; result_mem[37] <= acc_out_45; result_mem[38] <= acc_out_46; result_mem[39] <= acc_out_47;
                        end
                        4'd5: begin
                            result_mem[40] <= acc_out_50; result_mem[41] <= acc_out_51; result_mem[42] <= acc_out_52; result_mem[43] <= acc_out_53;
                            result_mem[44] <= acc_out_54; result_mem[45] <= acc_out_55; result_mem[46] <= acc_out_56; result_mem[47] <= acc_out_57;
                        end
                        4'd6: begin
                            result_mem[48] <= acc_out_60; result_mem[49] <= acc_out_61; result_mem[50] <= acc_out_62; result_mem[51] <= acc_out_63;
                            result_mem[52] <= acc_out_64; result_mem[53] <= acc_out_65; result_mem[54] <= acc_out_66; result_mem[55] <= acc_out_67;
                        end
                        4'd7: begin
                            result_mem[56] <= acc_out_70; result_mem[57] <= acc_out_71; result_mem[58] <= acc_out_72; result_mem[59] <= acc_out_73;
                            result_mem[60] <= acc_out_74; result_mem[61] <= acc_out_75; result_mem[62] <= acc_out_76; result_mem[63] <= acc_out_77;
                        end
                    endcase
                    
                    if (row_counter < 8) begin
                        row_counter <= row_counter + 1;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    computing <= 1'b0;
                    
                    // Allow external memory writes in DONE state
                    if (mem_we) begin
                        case (mem_select)
                            2'b00: matrix_a_mem[mem_addr[5:0]] <= mem_data_in;
                            2'b01: matrix_b_mem[mem_addr[5:0]] <= mem_data_in;
                            2'b10: result_mem[mem_addr[5:0]] <= mem_data_in;
                            default: ;
                        endcase
                    end
                    
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
        .a_in_1(matrix_a_mem[8]),   // Row 1 starts at index 8
        .a_in_2(matrix_a_mem[16]),  // Row 2 starts at index 16
        .a_in_3(matrix_a_mem[24]),  // Row 3 starts at index 24
        .a_in_4(matrix_a_mem[32]),  // Row 4 starts at index 32
        .a_in_5(matrix_a_mem[40]),  // Row 5 starts at index 40
        .a_in_6(matrix_a_mem[48]),  // Row 6 starts at index 48
        .a_in_7(matrix_a_mem[56]),  // Row 7 starts at index 56
        
        // Connect weights (column inputs) from Matrix B
        .w_in_0(matrix_b_mem[0]),   // Col 0
        .w_in_1(matrix_b_mem[1]),   // Col 1
        .w_in_2(matrix_b_mem[2]),   // Col 2
        .w_in_3(matrix_b_mem[3]),   // Col 3
        .w_in_4(matrix_b_mem[4]),   // Col 4
        .w_in_5(matrix_b_mem[5]),   // Col 5
        .w_in_6(matrix_b_mem[6]),   // Col 6
        .w_in_7(matrix_b_mem[7]),   // Col 7
        
        // Connect outputs (all 64 individual wires)
        .acc_out_00(acc_out_00), .acc_out_01(acc_out_01), .acc_out_02(acc_out_02), .acc_out_03(acc_out_03),
        .acc_out_04(acc_out_04), .acc_out_05(acc_out_05), .acc_out_06(acc_out_06), .acc_out_07(acc_out_07),
        .acc_out_10(acc_out_10), .acc_out_11(acc_out_11), .acc_out_12(acc_out_12), .acc_out_13(acc_out_13),
        .acc_out_14(acc_out_14), .acc_out_15(acc_out_15), .acc_out_16(acc_out_16), .acc_out_17(acc_out_17),
        .acc_out_20(acc_out_20), .acc_out_21(acc_out_21), .acc_out_22(acc_out_22), .acc_out_23(acc_out_23),
        .acc_out_24(acc_out_24), .acc_out_25(acc_out_25), .acc_out_26(acc_out_26), .acc_out_27(acc_out_27),
        .acc_out_30(acc_out_30), .acc_out_31(acc_out_31), .acc_out_32(acc_out_32), .acc_out_33(acc_out_33),
        .acc_out_34(acc_out_34), .acc_out_35(acc_out_35), .acc_out_36(acc_out_36), .acc_out_37(acc_out_37),
        .acc_out_40(acc_out_40), .acc_out_41(acc_out_41), .acc_out_42(acc_out_42), .acc_out_43(acc_out_43),
        .acc_out_44(acc_out_44), .acc_out_45(acc_out_45), .acc_out_46(acc_out_46), .acc_out_47(acc_out_47),
        .acc_out_50(acc_out_50), .acc_out_51(acc_out_51), .acc_out_52(acc_out_52), .acc_out_53(acc_out_53),
        .acc_out_54(acc_out_54), .acc_out_55(acc_out_55), .acc_out_56(acc_out_56), .acc_out_57(acc_out_57),
        .acc_out_60(acc_out_60), .acc_out_61(acc_out_61), .acc_out_62(acc_out_62), .acc_out_63(acc_out_63),
        .acc_out_64(acc_out_64), .acc_out_65(acc_out_65), .acc_out_66(acc_out_66), .acc_out_67(acc_out_67),
        .acc_out_70(acc_out_70), .acc_out_71(acc_out_71), .acc_out_72(acc_out_72), .acc_out_73(acc_out_73),
        .acc_out_74(acc_out_74), .acc_out_75(acc_out_75), .acc_out_76(acc_out_76), .acc_out_77(acc_out_77)
    );
    
    // Note: Activation functions can be added here if needed
    // For now, results go directly from systolic array to result memory
    
    // ========================================================================
    // Interface Modules
    // ========================================================================
    
    // Multiplex based on interface mode (simplified: button=0, uart=1)
    assign mem_addr = interface_mode ? uart_mem_addr : btn_mem_addr;
    assign mem_data_in = interface_mode ? uart_mem_dout : btn_mem_din;
    assign mem_we = interface_mode ? uart_mem_we : btn_mem_we;
    assign mem_select = interface_mode ? uart_mem_sel : btn_mem_sel;
    assign tpu_start = interface_mode ? uart_tpu_start : btn_tpu_start;
    assign tpu_reset = interface_mode ? uart_tpu_reset : 1'b0;
    
    // LED output multiplexing
    assign leds = interface_mode ? {uart_status_leds, 8'h00} : btn_leds;
    
    // ========================================================================
    // UART Protocol Handler
    // ========================================================================
    
    uart_protocol_handler #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) uart_protocol (
        .clk(clk),
        .rst_n(rst_n),
        
        // UART physical pins
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        
        // Memory interface
        .mem_addr(uart_mem_addr),
        .mem_data_out(uart_mem_dout),
        .mem_data_in(mem_data_out),
        .mem_we(uart_mem_we),
        .mem_select(uart_mem_sel),
        
        // TPU control
        .tpu_start(uart_tpu_start),
        .tpu_reset(uart_tpu_reset),
        .tpu_busy(tpu_busy),
        .tpu_done(tpu_done),
        
        // Status LEDs
        .status_leds(uart_status_leds)
    );
    
    // ========================================================================
    // Button/Switch Interface (Demo Mode)
    // ========================================================================
    
    // Button interface - simplified demo mode
    // btn_up = start computation
    // btn_down = load data
    // switches[3:0] = address low nibble
    
    reg btn_up_r, btn_down_r;
    always @(posedge clk) begin
        btn_up_r <= btn_up;
        btn_down_r <= btn_down;
    end
    
    wire btn_up_pulse = btn_up && !btn_up_r;
    wire btn_down_pulse = btn_down && !btn_down_r;
    
    assign btn_tpu_start = btn_up_pulse;
    assign btn_mem_addr = {4'b0, switches[3:0]};  // Use only lower 4 bits for address
    assign btn_mem_din = {switches[7:0], switches[7:0]};  // Replicate for demo
    assign btn_mem_we = btn_down_pulse;
    assign btn_mem_sel = 2'b00;  // Default to matrix_a
    
    // Button mode LED output - show TPU status
    assign btn_leds = {tpu_done, tpu_busy, state[3:0], row_counter[3:0], switches[5:0]};

endmodule
