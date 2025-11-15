## Basys3 Constraints File for TPU with Complete I/O
## Target: Basys3 Board (xc7a35tcpg236-1)

## Clock signal
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset (Using BTNC for reset in some modes)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst_n]

## Switches
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

## LEDs
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

## 7-Segment Display
set_property -dict { PACKAGE_PIN W7   IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]  # CA
set_property -dict { PACKAGE_PIN W6   IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]  # CB
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]  # CC
set_property -dict { PACKAGE_PIN V8   IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]  # CD
set_property -dict { PACKAGE_PIN U5   IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]  # CE
set_property -dict { PACKAGE_PIN V5   IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]  # CF
set_property -dict { PACKAGE_PIN U7   IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]  # CG

set_property -dict { PACKAGE_PIN U2   IOSTANDARD LVCMOS33 } [get_ports {an[0]}]   # AN0
set_property -dict { PACKAGE_PIN U4   IOSTANDARD LVCMOS33 } [get_ports {an[1]}]   # AN1
set_property -dict { PACKAGE_PIN V4   IOSTANDARD LVCMOS33 } [get_ports {an[2]}]   # AN2
set_property -dict { PACKAGE_PIN W4   IOSTANDARD LVCMOS33 } [get_ports {an[3]}]   # AN3

## Buttons
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports btn_center]  # BTNC
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports btn_up]      # BTNU
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports btn_left]    # BTNL
set_property -dict { PACKAGE_PIN T17  IOSTANDARD LVCMOS33 } [get_ports btn_right]   # BTNR
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports btn_down]    # BTND

## USB-UART Interface
set_property -dict { PACKAGE_PIN B18  IOSTANDARD LVCMOS33 } [get_ports uart_rx]     # USB_UART_TXD (FPGA RX)
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports uart_tx]     # USB_UART_RXD (FPGA TX)

## SPI Interface (Using PMOD JA)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports spi_sclk]    # JA1
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports spi_mosi]    # JA2
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports spi_miso]    # JA3
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports spi_cs_n]    # JA4

## Status LEDs (optional - can use LED14 and LED15)
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports tpu_busy_led]  # LED14
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports tpu_done_led]  # LED15

## Configuration options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## Timing Constraints
## Critical paths in systolic array
set_max_delay -from [get_pins -hierarchical *mac_unit*/acc_reg*/C] -to [get_pins -hierarchical *mac_unit*/acc_reg*/D] 10.0

## I/O timing
set_input_delay -clock sys_clk_pin 2.0 [get_ports uart_rx]
set_output_delay -clock sys_clk_pin 2.0 [get_ports uart_tx]
set_input_delay -clock sys_clk_pin 1.0 [get_ports spi_*]

## False paths (button inputs are asynchronous)
set_false_path -from [get_ports btn_*]
set_false_path -from [get_ports switches*]

## Multi-cycle paths for memory operations
set_multicycle_path -setup 2 -from [get_pins -hierarchical *mem*/CLKARDCLK] -to [get_pins -hierarchical *_reg*/D]
set_multicycle_path -hold 1 -from [get_pins -hierarchical *mem*/CLKARDCLK] -to [get_pins -hierarchical *_reg*/D]
