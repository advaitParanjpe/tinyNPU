set clk_port [get_ports clk]

create_clock -name clk -period 10.000 $clk_port

set_input_delay 2.000 -clock clk [remove_from_collection [all_inputs] $clk_port]
set_output_delay 2.000 -clock clk [all_outputs]

