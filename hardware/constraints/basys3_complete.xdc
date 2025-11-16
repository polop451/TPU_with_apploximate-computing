## ============================================================================
## Basys3 Complete Constraints File for TPU with I/O
## Target: Basys3 Board (Artix-7 xc7a35tcpg236-1)
## Clock: 100 MHz
## ============================================================================

## ============================================================================
## Clock and Reset
## ============================================================================

## Clock signal (100 MHz on Basys3)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset button - BTNC (Center button, active low)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst_n]

## ============================================================================
## Switches (SW15-SW0)
## ============================================================================

set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {switches[0]}]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {switches[1]}]
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports {switches[2]}]
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports {switches[3]}]
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports {switches[4]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {switches[5]}]
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports {switches[6]}]
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports {switches[7]}]
set_property -dict { PACKAGE_PIN V2   IOSTANDARD LVCMOS33 } [get_ports {switches[8]}]
set_property -dict { PACKAGE_PIN T3   IOSTANDARD LVCMOS33 } [get_ports {switches[9]}]
set_property -dict { PACKAGE_PIN T2   IOSTANDARD LVCMOS33 } [get_ports {switches[10]}]
set_property -dict { PACKAGE_PIN R3   IOSTANDARD LVCMOS33 } [get_ports {switches[11]}]
set_property -dict { PACKAGE_PIN W2   IOSTANDARD LVCMOS33 } [get_ports {switches[12]}]
set_property -dict { PACKAGE_PIN U1   IOSTANDARD LVCMOS33 } [get_ports {switches[13]}]
set_property -dict { PACKAGE_PIN T1   IOSTANDARD LVCMOS33 } [get_ports {switches[14]}]
set_property -dict { PACKAGE_PIN R2   IOSTANDARD LVCMOS33 } [get_ports {switches[15]}]

## ============================================================================
## LEDs (LED15-LED0)
## ============================================================================

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

## ============================================================================
## 7-Segment Display
## ============================================================================

## Cathodes (segments A-G)
set_property -dict { PACKAGE_PIN W7   IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]  # CA
set_property -dict { PACKAGE_PIN W6   IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]  # CB
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]  # CC
set_property -dict { PACKAGE_PIN V8   IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]  # CD
set_property -dict { PACKAGE_PIN U5   IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]  # CE
set_property -dict { PACKAGE_PIN V5   IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]  # CF
set_property -dict { PACKAGE_PIN U7   IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]  # CG

## Anodes (digit select)
set_property -dict { PACKAGE_PIN U2   IOSTANDARD LVCMOS33 } [get_ports {an[0]}]   # AN0
set_property -dict { PACKAGE_PIN U4   IOSTANDARD LVCMOS33 } [get_ports {an[1]}]   # AN1
set_property -dict { PACKAGE_PIN V4   IOSTANDARD LVCMOS33 } [get_ports {an[2]}]   # AN2
set_property -dict { PACKAGE_PIN W4   IOSTANDARD LVCMOS33 } [get_ports {an[3]}]   # AN3

## ============================================================================
## Push Buttons
## ============================================================================

set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports btn_center]  # BTNC (also reset)
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports btn_up]      # BTNU
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports btn_left]    # BTNL
set_property -dict { PACKAGE_PIN T17  IOSTANDARD LVCMOS33 } [get_ports btn_right]   # BTNR
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports btn_down]    # BTND

## ============================================================================
## USB-UART Interface
## ============================================================================

set_property -dict { PACKAGE_PIN B18  IOSTANDARD LVCMOS33 } [get_ports uart_rx]     # USB_UART_TXD (FPGA RX)
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports uart_tx]     # USB_UART_RXD (FPGA TX)

## ============================================================================
## SPI Interface (Using PMOD JA connector)
## ============================================================================

set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports spi_sclk]    # JA1
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports spi_mosi]    # JA2
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports spi_miso]    # JA3
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports spi_cs_n]    # JA4

## ============================================================================
## Status Outputs (Using LED14 and LED15 - also mapped to leds[14] and leds[15])
## ============================================================================

set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports tpu_busy_led]  # LED14
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports tpu_done_led]  # LED15

## ============================================================================
## Configuration Options
## ============================================================================

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## ============================================================================
## Timing Constraints
## ============================================================================

## Input delays for UART
set_input_delay -clock sys_clk_pin -max 2.0 [get_ports uart_rx]
set_input_delay -clock sys_clk_pin -min 1.0 [get_ports uart_rx]

## Output delays for UART
set_output_delay -clock sys_clk_pin -max 2.0 [get_ports uart_tx]
set_output_delay -clock sys_clk_pin -min 1.0 [get_ports uart_tx]

## Input delays for SPI
set_input_delay -clock sys_clk_pin -max 1.5 [get_ports spi_sclk]
set_input_delay -clock sys_clk_pin -max 1.5 [get_ports spi_mosi]
set_input_delay -clock sys_clk_pin -max 1.5 [get_ports spi_cs_n]

## Output delays for SPI
set_output_delay -clock sys_clk_pin -max 1.5 [get_ports spi_miso]

## ============================================================================
## False Paths (Asynchronous Inputs)
## ============================================================================

## Buttons are asynchronous and need debouncing
set_false_path -from [get_ports btn_center]
set_false_path -from [get_ports btn_up]
set_false_path -from [get_ports btn_down]
set_false_path -from [get_ports btn_left]
set_false_path -from [get_ports btn_right]

## Switches are asynchronous
set_false_path -from [get_ports switches*]

## ============================================================================
## Multi-Cycle Paths
## ============================================================================

## Allow 2 cycles for memory read/write operations
set_multicycle_path -setup 2 -from [get_pins -hierarchical *mem*/CLKARDCLK] -to [get_pins -hierarchical *_reg*/D]
set_multicycle_path -hold 1 -from [get_pins -hierarchical *mem*/CLKARDCLK] -to [get_pins -hierarchical *_reg*/D]

## Allow 3 cycles for systolic array computation (FP16 operations are complex)
set_multicycle_path -setup 3 -from [get_pins -hierarchical *systolic_array*/mac_unit*/acc_reg*/C] -to [get_pins -hierarchical *systolic_array*/result_row_reg*/D]
set_multicycle_path -hold 2 -from [get_pins -hierarchical *systolic_array*/mac_unit*/acc_reg*/C] -to [get_pins -hierarchical *systolic_array*/result_row_reg*/D]

## ============================================================================
## Critical Path Constraints
## ============================================================================

## MAC unit accumulation path
set_max_delay 10.0 -from [get_pins -hierarchical *mac_unit*/acc_reg*/C] -to [get_pins -hierarchical *mac_unit*/acc_reg*/D]

## FP16 multiplier path
set_max_delay 8.0 -from [get_pins -hierarchical *fp16_mult*/a_reg*/C] -to [get_pins -hierarchical *fp16_mult*/result_reg*/D]

## ============================================================================
## End of Constraints
## ============================================================================
