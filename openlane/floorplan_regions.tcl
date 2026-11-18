# ============================================================
# Soft hierarchical floorplan guidance for soc_top
# Die: 3000 x 3000 um, core ~ 180..2820
#
# Target regions (microns):
#   CPU   : top        y = 2000 .. 2800
#   AXI   : mid-top    y = 1700 .. 2000
#   DSE   : mid-left   x = 200  .. 1400 , y = 900 .. 1700
#   SRAM  : bot-left   x = 200  .. 1400 , y = 200  .. 900
#   CNN   : right      x = 1500 .. 2800 , y = 200  .. 1700
#
# OpenLane 1.0.2 does not always expose full region APIs in-flow.
# Use this script in interactive OpenROAD after floorplan, or as
# EXTRA_OPENROAD_TCL if your build supports it.
# ============================================================

puts "INFO: soc_top hierarchical region guidance loaded"

# Example (uncomment if your OpenROAD build supports these commands):
#
# set core_llx 180
# set core_lly 180
# set core_urx 2820
# set core_ury 2820
#
# # Density screens / soft fences help spread modules
# # Exact command names vary by OpenROAD version.
#
# puts "CPU   region: x=200:2800  y=2000:2800"
# puts "AXI   region: x=200:2800  y=1700:2000"
# puts "DSE   region: x=200:1400  y=900:1700"
# puts "SRAM  region: x=200:1400  y=200:900"
# puts "CNN   region: x=1500:2800 y=200:1700"
