/**
 * 模块名称：traffic_lights_VG
 * 描述：基于 FPGA 的智能交通灯控制系统
 * 功能：
 * 1. 自动/行人请求双模式控制。
 * 2. 通过电位器（ADC）调节基础车流绿灯时长。
 * 3. 车流传感器（按键模拟）动态补偿绿灯时间。
 * 4. 数码管实时切换：平时显示倒计时，拧动电位器时显示车流原始数据。
 */

module traffic_lights_VG (
    input  wire        clk, rst_n,      // 50MHz 系统时钟及异步复位（低电平有效）
    input  wire        btn_ped1,        // 行人请求按钮 1
    input  wire        btn_ped2,        // 行人请求按钮 2 (绑定到 PIN_111)
    input  wire        btn_veh_sensor,  // 车辆检测传感器 (绑定到 PIN_142，按下表示车流大)
    output wire [2:0]  motor_led,       // 机动车信号灯 (红黄绿)
    output wire [1:0]  ped_led,         // 行人信号灯 (红绿)
    output wire        ad_cs, ad_sclk,  // ADC 081S021 SPI 总线信号
    input  wire        ad_miso,         // ADC 串行数据输入
    output wire [7:0]  seg_data,        // 数码管段码
    output wire [5:0]  seg_sel,         // 数码管位选
    output wire        beep_pwm         // 蜂鸣器 PWM 输出
);

    // --- 参数与状态定义 ---
    parameter CLK_FREQ = 50_000_000;    // 50MHz 时钟频率
    // 使用 One-Hot 编码定义状态机状态
    localparam IDLE     = 4'b0001,      // 车道绿灯状态（初始/空闲）
               YELLOW_1 = 4'b0010,      // 车道黄灯（准备切换给行人）
               PED_WALK = 4'b0100,      // 行人通行状态（行人绿灯）
               YELLOW_2 = 4'b1000;      // 车道黄灯（准备切换回车道）

    reg [3:0]  curr_state, next_state;  // 状态寄存器
    reg [31:0] timer_cnt;               // 状态计时器（以时钟周期为单位）
    wire [7:0] adc_value;               // 从驱动获取的 8 位 ADC 数值 (0-255)
    reg        ped_request_latched;     // 行人请求锁存标志
    wire       adc_show_en;             // 数码管显示 ADC 信息的使能信号

    // ============================================================
    // 1. ADC 变化检测逻辑（交互优化）
    // ============================================================
    reg [7:0]  adc_old;                 // 存储上一次稳定的 ADC 值
    reg [31:0] adc_active_timer;        // 触发显示计时器（控制显示持续时间）
    wire [7:0] adc_diff;                // 两次采样间的绝对差值

    // 计算当前 ADC 值与旧值的偏差，判断用户是否正在拧动电位器
    assign adc_diff = (adc_value > adc_old) ? (adc_value - adc_old) : (adc_old - adc_value);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adc_old <= 8'd0;
            adc_active_timer <= 0;
        end else begin
            // 阈值过滤：只有变化量 >= 3 时才认为是有意图的调节，防止末位抖动触发显示
            if (adc_diff >= 8'd3) begin
                adc_old <= adc_value;
                adc_active_timer <= CLK_FREQ * 3; // 触发后保持 3 秒的显示时间
            end else if (adc_active_timer > 0) begin
                adc_active_timer <= adc_active_timer - 1;
            end
        end
    end

    // 如果 3 秒计时未结束，adc_show_en 为高，通知驱动器切换显示内容
    assign adc_show_en = (adc_active_timer > 0);

    // ============================================================
    // 2. 车流量映射逻辑：ADC 值 -> 绿灯时长
    // ============================================================
    reg [7:0]  base_green_time;         // 根据 ADC 确定的基础绿灯秒数
    wire [7:0] final_min_green;         // 最终决定的最小绿灯时长

    // 将 0-255 的 ADC 空间划分为 5 个等级，对应不同的车流量负载
    always @(*) begin
        if      (adc_value < 51)  base_green_time = 8'd0;  // 极低流量
        else if (adc_value < 102) base_green_time = 8'd5;
        else if (adc_value < 153) base_green_time = 8'd10;
        else if (adc_value < 204) base_green_time = 8'd15;
        else                      base_green_time = 8'd20; // 极高流量
    end

    // 传感器补偿：如果物理传感器检测到车辆堆积（低电平有效），在基础时间上额外奖励 10 秒
    assign final_min_green = (!btn_veh_sensor) ? (base_green_time + 8'd10) : base_green_time;

    // ============================================================
    // 3. 数码管倒计时数值计算
    // ============================================================
    reg [7:0] display_countdown;
    always @(*) begin
        case(curr_state)
            IDLE: begin
                if (ped_request_latched) begin
                    // 如果行人已按下按钮，显示车道绿灯还需要坚持多久才能切换
                    if (timer_cnt < final_min_green * CLK_FREQ)
                        display_countdown = final_min_green - (timer_cnt / CLK_FREQ);
                    else 
                        display_countdown = 0;
                end else begin
                    display_countdown = 8'hFF; // 无请求时，数码管右侧熄灭
                end
            end
            YELLOW_1: display_countdown = 1 - (timer_cnt / CLK_FREQ); // 黄灯 1 秒
            PED_WALK: display_countdown = 5 - (timer_cnt / CLK_FREQ); // 行人通行 5 秒
            YELLOW_2: display_countdown = 1 - (timer_cnt / CLK_FREQ); // 回切黄灯 1 秒
            default:  display_countdown = 0;
        endcase
    end

    // ============================================================
    // 4. 行人请求锁存（防止行人松开按键后请求丢失）
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            ped_request_latched <= 0;
        else if (!btn_ped1 || !btn_ped2) // 任意按钮按下即锁存请求
            ped_request_latched <= 1;
        else if (curr_state == PED_WALK) // 进入行人通行状态后清除请求
            ped_request_latched <= 0;
    end

    // ============================================================
    // 5. 有限状态机 (FSM) 核心逻辑
    // ============================================================
    
    // 状态切换与计时器重置
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= IDLE;
            timer_cnt <= 0;
        end else if (curr_state != next_state) begin
            curr_state <= next_state;
            timer_cnt  <= 0; // 状态转换时计时器清零
        end else begin
            timer_cnt <= timer_cnt + 1;
        end
    end

    // 下一状态决策
    always @(*) begin
        next_state = curr_state;
        case (curr_state)
            // 只有当有行人请求 且 车道绿灯时间已满足最小通行时间时，才切到黄灯
            IDLE:     if (ped_request_latched && timer_cnt >= final_min_green * CLK_FREQ) next_state = YELLOW_1;
            YELLOW_1: if (timer_cnt >= 1 * CLK_FREQ) next_state = PED_WALK;
            PED_WALK: if (timer_cnt >= 5 * CLK_FREQ) next_state = YELLOW_2;
            YELLOW_2: if (timer_cnt >= 1 * CLK_FREQ) next_state = IDLE;
        endcase
    end

    // ============================================================
    // 6. 底层驱动实例化
    // ============================================================
    
    // ADC 采集驱动 (SPI 协议)
    adc_081s021_driver u_adc (
        .clk(clk), .rst_n(rst_n), 
        .ad_cs(ad_cs), .ad_sclk(ad_sclk), .ad_miso(ad_miso), 
        .adc_data(adc_value) 
    );

    // 六位数码管动态扫描驱动
    display_6digit_driver u_disp (
        .clk(clk), 
        .adc_val(adc_value),      // 左侧三位显示：ADC 原始值/车流量信息
        .adc_en(adc_show_en),     // 仅在拧动电位器时显示左侧内容
        .countdown(display_countdown), // 右侧三位显示：倒计时秒数
        .seg_data(seg_data), 
        .seg_sel(seg_sel)
    );

    // 蜂鸣器提醒驱动（根据状态改变频率或节奏）
    buzzer_pwm_driver u_beep (
        .clk(clk), .state(curr_state), .timer_cnt(timer_cnt), .pwm_out(beep_pwm)
    );

    // --- 输出引脚分配 ---
    // 车道灯：IDLE(绿灯亮), PED_WALK(红灯亮), 黄灯状态(黄灯亮)
    assign motor_led = (curr_state==IDLE)? 3'b110 : (curr_state==PED_WALK? 3'b011 : 3'b101);
    // 行人灯：PED_WALK(绿灯亮), 其他状态(红灯亮)
    assign ped_led   = (curr_state==PED_WALK)? 2'b10 : 2'b01;

endmodule