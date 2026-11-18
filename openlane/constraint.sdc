create_clock -name core_clk -period 20.000 [get_ports clk]
set_clock_uncertainty 0.5 [get_clocks core_clk]
set_clock_transition 0.2 [get_clocks core_clk]
