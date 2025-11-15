## Basys3 Constraints File for TPU Design
## Clock signal (100 MHz on Basys3)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset button (active low) - using BTNC (center button)
set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports rst_n]

## Start button - using BTNU (up button)
set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports start]

## Load control buttons
set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 } [get_ports load_weight]
set_property -dict { PACKAGE_PIN T17   IOSTANDARD LVCMOS33 } [get_ports load_activation]

## Matrix size input - using switches SW7-SW0
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports {matrix_size[0]}]
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports {matrix_size[1]}]
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports {matrix_size[2]}]
set_property -dict { PACKAGE_PIN W17   IOSTANDARD LVCMOS33 } [get_ports {matrix_size[3]}]
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports {matrix_size[4]}]
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports {matrix_size[5]}]
set_property -dict { PACKAGE_PIN W14   IOSTANDARD LVCMOS33 } [get_ports {matrix_size[6]}]
set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports {matrix_size[7]}]

## Load address input - using switches SW15-SW8
set_property -dict { PACKAGE_PIN V2    IOSTANDARD LVCMOS33 } [get_ports {load_addr[0]}]
set_property -dict { PACKAGE_PIN T3    IOSTANDARD LVCMOS33 } [get_ports {load_addr[1]}]
set_property -dict { PACKAGE_PIN T2    IOSTANDARD LVCMOS33 } [get_ports {load_addr[2]}]
set_property -dict { PACKAGE_PIN R3    IOSTANDARD LVCMOS33 } [get_ports {load_addr[3]}]
set_property -dict { PACKAGE_PIN W2    IOSTANDARD LVCMOS33 } [get_ports {load_addr[4]}]
set_property -dict { PACKAGE_PIN U1    IOSTANDARD LVCMOS33 } [get_ports {load_addr[5]}]
set_property -dict { PACKAGE_PIN T1    IOSTANDARD LVCMOS33 } [get_ports {load_addr[6]}]
set_property -dict { PACKAGE_PIN R2    IOSTANDARD LVCMOS33 } [get_ports {load_addr[7]}]

## Load data input - using PMOD headers JA (upper 8 pins)
## Note: In real design, use UART or other interface for data loading
set_property -dict { PACKAGE_PIN J1    IOSTANDARD LVCMOS33 } [get_ports {load_data[0]}]
set_property -dict { PACKAGE_PIN L2    IOSTANDARD LVCMOS33 } [get_ports {load_data[1]}]
set_property -dict { PACKAGE_PIN J2    IOSTANDARD LVCMOS33 } [get_ports {load_data[2]}]
set_property -dict { PACKAGE_PIN G2    IOSTANDARD LVCMOS33 } [get_ports {load_data[3]}]
set_property -dict { PACKAGE_PIN H1    IOSTANDARD LVCMOS33 } [get_ports {load_data[4]}]
set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports {load_data[5]}]
set_property -dict { PACKAGE_PIN H2    IOSTANDARD LVCMOS33 } [get_ports {load_data[6]}]
set_property -dict { PACKAGE_PIN G3    IOSTANDARD LVCMOS33 } [get_ports {load_data[7]}]

## LEDs - Status and Debug outputs
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19   IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18   IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15   IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3    IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN W3    IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN U3    IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P3    IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN N3    IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN P1    IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN L1    IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## Status outputs
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports busy]
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports done]

## Result outputs - First 4 results (using PMOD JB for demonstration)
## Note: In production, use UART or other communication protocol
set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports {result_0[0]}]
set_property -dict { PACKAGE_PIN A16   IOSTANDARD LVCMOS33 } [get_ports {result_0[1]}]
set_property -dict { PACKAGE_PIN B15   IOSTANDARD LVCMOS33 } [get_ports {result_0[2]}]
set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33 } [get_ports {result_0[3]}]

## Timing Constraints for High Performance

## Clock groups and timing exceptions
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rst_n_IBUF]

## Input/Output delays relative to clock
set_input_delay -clock [get_clocks sys_clk_pin] -min 2.0 [get_ports {matrix_size[*]}]
set_input_delay -clock [get_clocks sys_clk_pin] -max 5.0 [get_ports {matrix_size[*]}]
set_input_delay -clock [get_clocks sys_clk_pin] -min 2.0 [get_ports {load_addr[*]}]
set_input_delay -clock [get_clocks sys_clk_pin] -max 5.0 [get_ports {load_addr[*]}]
set_input_delay -clock [get_clocks sys_clk_pin] -min 2.0 [get_ports {load_data[*]}]
set_input_delay -clock [get_clocks sys_clk_pin] -max 5.0 [get_ports {load_data[*]}]

set_output_delay -clock [get_clocks sys_clk_pin] -min 1.0 [get_ports {led[*]}]
set_output_delay -clock [get_clocks sys_clk_pin] -max 4.0 [get_ports {led[*]}]

## False paths for asynchronous inputs (buttons)
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports start]
set_false_path -from [get_ports load_weight]
set_false_path -from [get_ports load_activation]

## Multi-cycle paths for memory access (if needed)
## Uncomment if timing is tight
# set_multicycle_path -setup 2 -from [get_pins -hierarchical *weight_mem*/C] -to [get_pins -hierarchical *weight_data*/D]
# set_multicycle_path -hold 1 -from [get_pins -hierarchical *weight_mem*/C] -to [get_pins -hierarchical *weight_data*/D]

## Configuration settings for better performance
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

## Power optimization
set_property POWER_OPT.PAR_HIGH_EFFORT TRUE [current_design]

## Placement optimization for systolic array
## Force systolic array PEs to be placed close together
# set_property LOC SLICE_X50Y50 [get_cells {sa/gen_row[0].gen_col[0].pe}]
# (Add more placement constraints as needed for optimal routing)

## Timing optimization
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
