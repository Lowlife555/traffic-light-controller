# =============================================================
# 交通灯系统 V2 修正版 - 引脚分配脚本
# 变更：移除 ADC 接口，增加 8 位拨动开关 (sw_flow)
# =============================================================

# 1. 基础系统 (时钟与复位)
set_location_assignment PIN_23 -to clk_50m
set_location_assignment PIN_25 -to rst_n

# 2. 主路交通灯 LED (低电平点亮)
set_location_assignment PIN_110 -to led_r
set_location_assignment PIN_119 -to led_y
set_location_assignment PIN_113 -to led_g

# 3. 行人路灯 LED
set_location_assignment PIN_127 -to ped_led_r
set_location_assignment PIN_132 -to ped_led_g

# 4. 输入按钮 (行人请求)
set_location_assignment PIN_111 -to key_ped
set_location_assignment PIN_142 -to key_ped2

# 5. 8位拨动开关 (车流量模拟输入)
# 对应代码：input wire [7:0] sw_flow
set_location_assignment PIN_112 -to sw_flow[0]
set_location_assignment PIN_115 -to sw_flow[1]
set_location_assignment PIN_121 -to sw_flow[2]
set_location_assignment PIN_126 -to sw_flow[3]
set_location_assignment PIN_129 -to sw_flow[4]
set_location_assignment PIN_135 -to sw_flow[5]
set_location_assignment PIN_138 -to sw_flow[6]
set_location_assignment PIN_143 -to sw_flow[7]

# 6. 蜂鸣器 (高电平触发)
set_location_assignment PIN_71  -to buzzer

# 7. OLED I2C 接口
set_location_assignment PIN_33 -to oled_scl
set_location_assignment PIN_34 -to oled_sda

# -------------------------------------------------------------
# 电气特性配置 (IO Standard & Pull-up)
# -------------------------------------------------------------

# 为 I2C 引脚、按钮和开关设置弱上拉
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to oled_scl
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to oled_sda
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to key_ped
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to key_ped2
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to sw_flow[*]

# 设置所有引脚为 3.3V LVTTL 标准
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk_50m
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to rst_n
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to led_r
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to led_y
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to led_g
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ped_led_r
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ped_led_g
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to buzzer
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to key_ped
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to key_ped2
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sw_flow[*]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to oled_scl
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to oled_sda

# 未使用引脚保护
set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED WITH WEAK PULL-UP"