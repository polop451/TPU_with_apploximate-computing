## Basys3 Simplified Constraints File for TPU with Reduced I/O (30 pins)
## Target: Basys3 Board (xc7a35tcpg236-1)
## Modified: Removed SPI, 7-segment, extra buttons, and switches[15:8]

## Clock signal
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset (Using BTNC for reset)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst_n]

## Switches (8 switches only: switches[7:0])
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {switches[0]}]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {switches[1]}]
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports {switches[2]}]
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports {switches[3]}]
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports {switches[4]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {switches[5]}]
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports {switches[6]}]
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports {switches[7]}]

## LEDs (All 16 LEDs)
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {leds[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {leds[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {leds[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {leds[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {leds[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {leds[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {leds[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {leds[7]}]
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports {leds[8]}]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports {leds[9]}]
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports {leds[10]}]
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports {leds[11]}]
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports {leds[12]}]
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports {leds[13]}]
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports {leds[14]}]
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports {leds[15]}]

## Buttons (Only 2 buttons: btn_up and btn_down)
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports btn_up]      # BTNU
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports btn_down]    # BTND

## USB-UART Interface
set_property -dict { PACKAGE_PIN B18  IOSTANDARD LVCMOS33 } [get_ports uart_rx]     # USB_UART_TXD (FPGA RX)
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports uart_tx]     # USB_UART_RXD (FPGA TX)

## Configuration options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## Synthesis Strategy for Timing Optimization
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AlternateRoutability [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]

## Implementation Strategy for Timing Optimization
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraTimingOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

## Timing Constraints
## Critical paths in systolic array - allow 2 cycles for MAC operation
set_multicycle_path -setup 2 -from [get_pins -hierarchical *mac_unit*/mult_result_reg*/C] -to [get_pins -hierarchical *mac_unit*/accumulator*/D]
set_multicycle_path -hold 1 -from [get_pins -hierarchical *mac_unit*/mult_result_reg*/C] -to [get_pins -hierarchical *mac_unit*/accumulator*/D]

## Relaxed timing for FP16 multiplier (combinational logic)
set_max_delay -from [get_pins -hierarchical *mult*/a*] -to [get_pins -hierarchical *mac_unit*/mult_result_reg*/D] 9.5

## I/O timing - relaxed for UART
set_input_delay -clock sys_clk_pin 3.0 [get_ports uart_rx]
set_output_delay -clock sys_clk_pin 3.0 [get_ports uart_tx]

## False paths (button and switch inputs are asynchronous)
set_false_path -from [get_ports btn_*]
set_false_path -from [get_ports switches*]
set_false_path -from [get_ports rst_n]

## Multi-cycle paths for memory operations (Block RAM has 2-cycle latency)
set_multicycle_path -setup 2 -from [get_pins -hierarchical *mem*/CLKARDCLK] -to [get_pins -hierarchical *_reg*/D]
set_multicycle_path -hold 1 -from [get_pins -hierarchical *mem*/CLKARDCLK] -to [get_pins -hierarchical *_reg*/D]

## Multi-cycle for controller FSM (state transitions can take 2 cycles)
set_multicycle_path -setup 2 -from [get_pins -hierarchical state_reg*/C] -to [get_pins -hierarchical *counter*/D]

## I/O Summary:
## Inputs (12): clk, rst_n, uart_rx, switches[7:0], btn_up, btn_down
## Outputs (18): uart_tx, leds[15:0]
## Total: 30 I/O pins
