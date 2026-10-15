# ============================================================
# 基础时钟与复位
# ============================================================
set_location_assignment PIN_23 -to clk
set_location_assignment PIN_25 -to rst_n

# ============================================================
# 输入按键 (根据代码注释适配)
# ============================================================
set_location_assignment PIN_114 -to btn_ped1
set_location_assignment PIN_111 -to btn_ped2
set_location_assignment PIN_142 -to btn_veh_sensor
set_location_assignment PIN_133 -to btn_show_adc

# ============================================================
# 机动车灯 (motor_led [2]:红, [1]:黄, [0]:绿)
# ============================================================
set_location_assignment PIN_110 -to motor_led[2]
set_location_assignment PIN_119 -to motor_led[1]
set_location_assignment PIN_113 -to motor_led[0]

# ============================================================
# 行人灯 (ped_led [1]:红, [0]:绿)
# ============================================================
set_location_assignment PIN_127 -to ped_led[1]
set_location_assignment PIN_132 -to ped_led[0]

# ============================================================
# ADC 081S021 接口 (PIN_104, 106, 105)
# ============================================================
set_location_assignment PIN_104 -to ad_cs
set_location_assignment PIN_106 -to ad_sclk
set_location_assignment PIN_105 -to ad_miso

# ============================================================
# 6位数码管 (根据硬件电路修正)
# ============================================================
# 段线 (a,b,c,d,e,f,g,dp)
set_location_assignment PIN_51 -to seg_data[0]
set_location_assignment PIN_55 -to seg_data[1]
set_location_assignment PIN_54 -to seg_data[2]
set_location_assignment PIN_59 -to seg_data[3]
set_location_assignment PIN_65 -to seg_data[4]
set_location_assignment PIN_50 -to seg_data[5]
set_location_assignment PIN_53 -to seg_data[6]
set_location_assignment PIN_58 -to seg_data[7]

# 位选 (DIG1-6)
set_location_assignment PIN_66 -to seg_sel[0]
set_location_assignment PIN_64 -to seg_sel[1]
set_location_assignment PIN_60 -to seg_sel[2]
set_location_assignment PIN_69 -to seg_sel[3]
set_location_assignment PIN_68 -to seg_sel[4]
set_location_assignment PIN_67 -to seg_sel[5]

# ============================================================
# 蜂鸣器 (PIN_72)
# ============================================================
set_location_assignment PIN_72 -to beep_pwm