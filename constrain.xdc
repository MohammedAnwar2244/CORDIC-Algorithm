## This file is a general .xdc for the Basys3 rev B board
## To use it in a project: CORDIC_DESIGN 
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock input 100 MHz on pin R4
set_property -dict { PACKAGE_PIN R4   IOSTANDARD LVCMOS33 } [get_ports { clk }]

## Create 100 MHz clock constraint
create_clock -add -name sys_clk -period 10.000 -waveform {0 5} [get_ports { clk }]


