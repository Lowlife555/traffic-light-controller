# ================================================================
# FPGA Pin Assignment Script for EP4CE6E22C8N Board
# Project: traffic_lights_simlulation
# Clean Version: Uses ONLY Extension IO Pins, No Conflicts
# ================================================================

# --------------------------
# 1. System Clock
# --------------------------
set_location_assignment Pin_23 -to clk_50m

# --------------------------
# 2. Extension IO Pins (Debug Only)
# --------------------------
# Inputs
set_location_assignment Pin_31 -to rst_n
set_location_assignment Pin_28 -to key_ped
set_location_assignment Pin_30 -to key_ped2

# Outputs
set_location_assignment Pin_1 -to led_r
set_location_assignment Pin_2 -to led_g
set_location_assignment Pin_3 -to led_y
set_location_assignment Pin_7 -to ped_led_r
set_location_assignment Pin_10 -to ped_led_g
set_location_assignment Pin_11 -to buzzer
set_location_assignment Pin_32 -to tl_state_debug

# ================================================================
# Completion Message
# ================================================================
puts "============================================="
puts "SUCCESS! Pin Assignment Imported."
puts "Please compile the project now."
puts "============================================="