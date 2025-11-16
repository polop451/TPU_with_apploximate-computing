// Simple parallel interface using buttons and switches
module button_switch_interface (
    input wire clk,
    input wire rst_n,
    
    // Basys3 inputs
    input wire [15:0] switches,      // SW15-SW0
    input wire btn_center,           // BTNC - load data
    input wire btn_up,               // BTNU - start computation
    input wire btn_left,             // BTNL - previous result
    input wire btn_right,            // BTNR - next result
    input wire btn_down,             // BTND - reset
    
    // Basys3 outputs
    output reg [15:0] leds,          // LED15-LED0
    output reg [6:0] seg,            // 7-segment display
    output reg [3:0] an,             // 7-segment anodes
    
    // TPU interface
    output reg [7:0] tpu_data_out,
    output reg tpu_data_valid,
    output reg [7:0] tpu_addr,
    output reg tpu_write_enable,
    output reg tpu_start,
    
    input wire [7:0] tpu_data_in,
    input wire tpu_busy,
    input wire tpu_done
);

    // Button debouncing
    reg [19:0] debounce_counter;
    reg [4:0] btn_stable;
    reg [4:0] btn_prev;
    reg [4:0] btn_pulse;
    
    wire [4:0] buttons = {btn_down, btn_right, btn_left, btn_up, btn_center};
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_counter <= 0;
            btn_stable <= 5'b0;
            btn_prev <= 5'b0;
            btn_pulse <= 5'b0;
        end else begin
            if (debounce_counter == 20'd1000000) begin  // ~10ms @ 100MHz
                btn_stable <= buttons;
                btn_prev <= btn_stable;
                btn_pulse <= btn_stable & ~btn_prev;  // Rising edge
                debounce_counter <= 0;
            end else begin
                debounce_counter <= debounce_counter + 1;
                btn_pulse <= 5'b0;
            end
        end
    end
    
    // Address counter
    reg [7:0] addr_counter;
    reg [7:0] result_index;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tpu_data_valid <= 1'b0;
            tpu_write_enable <= 1'b0;
            tpu_start <= 1'b0;
            addr_counter <= 8'd0;
            result_index <= 8'd0;
            leds <= 16'h0000;
        end else begin
            tpu_data_valid <= 1'b0;
            tpu_write_enable <= 1'b0;
            tpu_start <= 1'b0;
            
            // Load data button
            if (btn_pulse[0]) begin  // Center button
                tpu_addr <= addr_counter;
                tpu_data_out <= switches[7:0];
                tpu_data_valid <= 1'b1;
                tpu_write_enable <= 1'b1;
                addr_counter <= addr_counter + 1;
            end
            
            // Start computation
            if (btn_pulse[1]) begin  // Up button
                tpu_start <= 1'b1;
                result_index <= 8'd0;
            end
            
            // Navigate results
            if (btn_pulse[2]) begin  // Left button
                if (result_index > 0)
                    result_index <= result_index - 1;
            end
            
            if (btn_pulse[3]) begin  // Right button
                if (result_index < 63)  // 8x8 = 64 results
                    result_index <= result_index + 1;
            end
            
            // Reset
            if (btn_pulse[4]) begin  // Down button
                addr_counter <= 8'd0;
                result_index <= 8'd0;
            end
            
            // Display on LEDs
            leds[15] <= tpu_done;
            leds[14] <= tpu_busy;
            leds[13:8] <= result_index[5:0];
            leds[7:0] <= tpu_data_in;
        end
    end
    
    // 7-segment display (show result_index and addr_counter)
    reg [15:0] display_value;
    reg [16:0] refresh_counter;
    reg [1:0] digit_select;
    
    always @(posedge clk) begin
        refresh_counter <= refresh_counter + 1;
        if (refresh_counter[16:15] != digit_select) begin
            digit_select <= refresh_counter[16:15];
        end
    end
    
    always @(*) begin
        if (tpu_busy)
            display_value = {8'hBB, addr_counter};  // Show "busy" + counter
        else
            display_value = {result_index, tpu_data_in};
    end
    
    // 7-segment decoder
    function [6:0] hex_to_7seg;
        input [3:0] hex;
        begin
            case (hex)
                4'h0: hex_to_7seg = 7'b1000000;
                4'h1: hex_to_7seg = 7'b1111001;
                4'h2: hex_to_7seg = 7'b0100100;
                4'h3: hex_to_7seg = 7'b0110000;
                4'h4: hex_to_7seg = 7'b0011001;
                4'h5: hex_to_7seg = 7'b0010010;
                4'h6: hex_to_7seg = 7'b0000010;
                4'h7: hex_to_7seg = 7'b1111000;
                4'h8: hex_to_7seg = 7'b0000000;
                4'h9: hex_to_7seg = 7'b0010000;
                4'hA: hex_to_7seg = 7'b0001000;
                4'hB: hex_to_7seg = 7'b0000011;
                4'hC: hex_to_7seg = 7'b1000110;
                4'hD: hex_to_7seg = 7'b0100001;
                4'hE: hex_to_7seg = 7'b0000110;
                4'hF: hex_to_7seg = 7'b0001110;
            endcase
        end
    endfunction
    
    always @(*) begin
        case (digit_select)
            2'b00: begin
                an = 4'b1110;
                seg = hex_to_7seg(display_value[3:0]);
            end
            2'b01: begin
                an = 4'b1101;
                seg = hex_to_7seg(display_value[7:4]);
            end
            2'b10: begin
                an = 4'b1011;
                seg = hex_to_7seg(display_value[11:8]);
            end
            2'b11: begin
                an = 4'b0111;
                seg = hex_to_7seg(display_value[15:12]);
            end
        endcase
    end

endmodule
