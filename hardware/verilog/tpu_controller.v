// TPU Control Unit
// Manages data flow and operation sequencing
// State machine for matrix multiplication operations

module tpu_controller #(
    parameter SIZE = 4,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    
    // Control inputs
    input wire start,                    // Start computation
    input wire [7:0] matrix_size,        // Size of matrices to multiply
    
    // Memory control outputs
    output reg weight_load_enable,
    output reg activation_load_enable,
    output reg weight_read_enable,
    output reg activation_read_enable,
    output reg [7:0] weight_addr,
    output reg [7:0] activation_addr,
    
    // Systolic array control
    output reg array_enable,
    output reg acc_clear,
    
    // Status outputs
    output reg busy,
    output reg done,
    output reg [7:0] cycle_counter
);

    // State machine
    localparam IDLE         = 3'b000;
    localparam LOAD_WEIGHTS = 3'b001;
    localparam LOAD_ACTS    = 3'b010;
    localparam COMPUTE      = 3'b011;
    localparam DRAIN        = 3'b100;
    localparam DONE         = 3'b101;
    
    reg [2:0] state, next_state;
    reg [7:0] load_counter;
    reg [7:0] compute_counter;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_WEIGHTS;
            end
            
            LOAD_WEIGHTS: begin
                if (load_counter >= matrix_size * SIZE - 1)
                    next_state = LOAD_ACTS;
            end
            
            LOAD_ACTS: begin
                if (load_counter >= matrix_size * SIZE - 1)
                    next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (compute_counter >= matrix_size + SIZE - 1)
                    next_state = DRAIN;
            end
            
            DRAIN: begin
                if (cycle_counter >= SIZE)
                    next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Output logic and counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_load_enable <= 1'b0;
            activation_load_enable <= 1'b0;
            weight_read_enable <= 1'b0;
            activation_read_enable <= 1'b0;
            weight_addr <= 8'd0;
            activation_addr <= 8'd0;
            array_enable <= 1'b0;
            acc_clear <= 1'b1;
            busy <= 1'b0;
            done <= 1'b0;
            load_counter <= 8'd0;
            compute_counter <= 8'd0;
            cycle_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    weight_load_enable <= 1'b0;
                    activation_load_enable <= 1'b0;
                    weight_read_enable <= 1'b0;
                    activation_read_enable <= 1'b0;
                    array_enable <= 1'b0;
                    acc_clear <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b0;
                    load_counter <= 8'd0;
                    compute_counter <= 8'd0;
                    cycle_counter <= 8'd0;
                    weight_addr <= 8'd0;
                    activation_addr <= 8'd0;
                end
                
                LOAD_WEIGHTS: begin
                    busy <= 1'b1;
                    weight_load_enable <= 1'b1;
                    load_counter <= load_counter + 1;
                    weight_addr <= weight_addr + 1;
                end
                
                LOAD_ACTS: begin
                    weight_load_enable <= 1'b0;
                    activation_load_enable <= 1'b1;
                    if (state != next_state)
                        load_counter <= 8'd0;
                    else
                        load_counter <= load_counter + 1;
                    activation_addr <= activation_addr + 1;
                end
                
                COMPUTE: begin
                    activation_load_enable <= 1'b0;
                    weight_read_enable <= 1'b1;
                    activation_read_enable <= 1'b1;
                    array_enable <= 1'b1;
                    acc_clear <= (compute_counter == 0) ? 1'b1 : 1'b0;
                    compute_counter <= compute_counter + 1;
                    cycle_counter <= cycle_counter + 1;
                    
                    // Update addresses for sequential access
                    if (compute_counter < matrix_size) begin
                        weight_addr <= compute_counter;
                        activation_addr <= compute_counter;
                    end
                end
                
                DRAIN: begin
                    weight_read_enable <= 1'b0;
                    activation_read_enable <= 1'b0;
                    array_enable <= 1'b0;
                    cycle_counter <= cycle_counter + 1;
                end
                
                DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
