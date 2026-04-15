vlib work
vlog CORDIC_TB.v
vsim -voptargs=+acc work.CORDIC_tb
add wave *
run -all
#quit -sim