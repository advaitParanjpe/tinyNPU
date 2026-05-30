set clk_port [get_ports clk]

create_clock -name clk -period 10.500 $clk_port

set input_ports [get_ports {rst_n bus_valid bus_we \
  bus_addr[0] bus_addr[1] bus_addr[2] bus_addr[3] \
  bus_addr[4] bus_addr[5] bus_addr[6] bus_addr[7] \
  bus_wdata[0] bus_wdata[1] bus_wdata[2] bus_wdata[3] \
  bus_wdata[4] bus_wdata[5] bus_wdata[6] bus_wdata[7] \
  bus_wdata[8] bus_wdata[9] bus_wdata[10] bus_wdata[11] \
  bus_wdata[12] bus_wdata[13] bus_wdata[14] bus_wdata[15] \
  bus_wdata[16] bus_wdata[17] bus_wdata[18] bus_wdata[19] \
  bus_wdata[20] bus_wdata[21] bus_wdata[22] bus_wdata[23] \
  bus_wdata[24] bus_wdata[25] bus_wdata[26] bus_wdata[27] \
  bus_wdata[28] bus_wdata[29] bus_wdata[30] bus_wdata[31]}]

set_input_delay 2.000 -clock clk $input_ports
set_output_delay 2.000 -clock clk [all_outputs]
