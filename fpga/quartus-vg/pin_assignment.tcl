# ADC SPI Pins
set_location_assignment PIN_104 -to ad_cs
set_location_assignment PIN_105 -to ad_miso
set_location_assignment PIN_106 -to ad_sclk

# Passive Buzzer
set_location_assignment PIN_72 -to beep_pwm

# 6-Digit 7-Segment (Full Pins)
set_location_assignment PIN_51 -to seg_data[0]; # a
set_location_assignment PIN_55 -to seg_data[1]; # b
set_location_assignment PIN_54 -to seg_data[2]; # c
set_location_assignment PIN_59 -to seg_data[3]; # d
set_location_assignment PIN_65 -to seg_data[4]; # e
set_location_assignment PIN_50 -to seg_data[5]; # f
set_location_assignment PIN_53 -to seg_data[6]; # g
set_location_assignment PIN_58 -to seg_data[7]; # h (DP)

set_location_assignment PIN_66 -to seg_sel[0]; # DIG1
set_location_assignment PIN_64 -to seg_sel[1]; # DIG2
set_location_assignment PIN_60 -to seg_sel[2]; # DIG3
set_location_assignment PIN_52 -to seg_sel[3]; # DIG4
set_location_assignment PIN_49 -to seg_sel[4]; # DIG5
set_location_assignment PIN_46 -to seg_sel[5]; # DIG6