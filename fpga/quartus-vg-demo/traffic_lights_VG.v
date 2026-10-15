module traffic_lights_VG (
    input  wire        clk, rst_n,      
    input  wire        btn_ped1,        // PIN_114
    input  wire        btn_ped2,        // PIN_111
    input  wire        btn_veh_sensor,  // PIN_142
    input  wire        btn_show_adc,    // PIN_133
    
    output wire [2:0]  motor_led,       // [2]:红110, [1]:黄119, [0]:绿113
    output wire [1:0]  ped_led,         // [1]:红127, [0]:绿132
    output wire        ad_cs, ad_sclk,  // PIN_104, PIN_106
    input  wire        ad_miso,         // PIN_105
    output wire [7:0]  seg_data,        
    output wire [5:0]  seg_sel,         
    output wire        beep_pwm         // PIN_72
);

    parameter MS_COUNT = 50_000; // 50MHz 下的 1ms 时钟周期

    localparam STATE_IDLE  = 4'b0001,
               STATE_WAIT  = 4'b0010,
               STATE_FLASH = 4'b0100,
               STATE_YEL1  = 4'b1000,
               STATE_PED   = 4'b0101;

    reg [3:0]  curr_state;
    reg [31:0] timer_ms;                
    reg [31:0] ms_tick_cnt;             
    wire [7:0] adc_value;               
    
    reg [7:0]  display_sec_reg;         
    reg [31:0] current_wait_limit;      
    reg [2:0]  m_led_reg; 
    reg [1:0]  p_led_reg;

    // ============================================================
    // 1. 工业级按键消抖与边沿检测 (彻底杜绝幽灵跳转)
    // ============================================================
    reg [19:0] btn_filter;
    reg btn_sync_1, btn_sync_2;
    reg btn_stable, btn_prev;
    reg ped_req_flag;

    // 将两个按键合并，低电平有效
    wire ped_btn_in = btn_ped1 & btn_ped2; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_filter <= 0;
            btn_sync_1 <= 1'b1;
            btn_sync_2 <= 1'b1;
            btn_stable <= 1'b1;
            btn_prev   <= 1'b1;
            ped_req_flag <= 1'b0;
        end else begin
            // 消除亚稳态
            btn_sync_1 <= ped_btn_in;
            btn_sync_2 <= btn_sync_1;

            // 软件滤波 20ms
            if (btn_sync_2 == btn_stable) begin
                btn_filter <= 0;
            end else begin
                if (btn_filter >= 20 * MS_COUNT) begin
                    btn_stable <= btn_sync_2;
                    btn_filter <= 0;
                end else begin
                    btn_filter <= btn_filter + 1'b1;
                end
            end

            // 边沿检测：仅当识别到真实的下降沿 (未按->按下) 时触发
            btn_prev <= btn_stable;
            if (btn_prev == 1'b1 && btn_stable == 1'b0) begin
                ped_req_flag <= 1'b1;
            end else if (curr_state == STATE_WAIT) begin
                ped_req_flag <= 1'b0; // 进入等待状态后清零标志
            end
        end
    end

    // 毫秒节拍器
    wire ms_pulse = (ms_tick_cnt == MS_COUNT - 1);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ms_tick_cnt <= 0;
        else if (ms_pulse) ms_tick_cnt <= 0;
        else ms_tick_cnt <= ms_tick_cnt + 1'b1;
    end

    // ============================================================
    // 2. 自适应时长计算 (稳定乘法逻辑)
    // ============================================================
    always @(*) begin
        // 基础 5000ms + (adc * 59)ms
        current_wait_limit = 32'd5000 + (adc_value * 32'd59);
        
        // 如果车辆传感器触发 (低电平有效)，加 10秒
        if (!btn_veh_sensor) begin
            current_wait_limit = current_wait_limit + 32'd10000;
        end
    end

    // ============================================================
    // 3. 全同步状态机 (杜绝组合逻辑跑飞)
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= STATE_IDLE;
            timer_ms   <= 0;
        end else if (ms_pulse) begin
            timer_ms <= timer_ms + 1'b1; // 默认累加
            
            case (curr_state)
                STATE_IDLE: begin
                    if (ped_req_flag) begin
                        curr_state <= STATE_WAIT;
                        timer_ms <= 0;
                    end
                end
                STATE_WAIT: begin
                    if (timer_ms >= current_wait_limit) begin
                        curr_state <= STATE_FLASH;
                        timer_ms <= 0;
                    end
                end
                STATE_FLASH: begin
                    if (timer_ms >= 32'd2000) begin
                        curr_state <= STATE_YEL1;
                        timer_ms <= 0;
                    end
                end
                STATE_YEL1: begin
                    if (timer_ms >= 32'd2000) begin
                        curr_state <= STATE_PED;
                        timer_ms <= 0;
                    end
                end
                STATE_PED: begin
                    if (timer_ms >= 32'd5000) begin
                        curr_state <= STATE_IDLE;
                        timer_ms <= 0;
                    end
                end
                default: curr_state <= STATE_IDLE;
            endcase
        end
    end

    // ============================================================
    // 4. 灯光、蜂鸣器与数码管显示逻辑
    // ============================================================
    wire flash_bit = (timer_ms % 500 < 250); 

    always @(*) begin
        m_led_reg = 3'b110; 
        p_led_reg = 2'b01;  
        case (curr_state)
            STATE_IDLE, STATE_WAIT: begin m_led_reg = 3'b110; p_led_reg = 2'b01; end
            STATE_FLASH: begin m_led_reg = flash_bit ? 3'b110 : 3'b111; p_led_reg = 2'b01; end
            STATE_YEL1:  begin m_led_reg = 3'b101; p_led_reg = 2'b01; end
            STATE_PED:   begin m_led_reg = 3'b011; p_led_reg = 2'b10; end
        endcase
    end

    assign motor_led = m_led_reg;
    assign ped_led   = p_led_reg;

    wire buzzer_gate = (curr_state == STATE_PED) ? 
                       ((timer_ms >= 2000) ? (timer_ms % 250 < 50) : (timer_ms % 500 < 100)) 
                       : 1'b0;

    always @(*) begin
        case (curr_state)
            // 取消了 +1，使得倒计时完美呈现 5 -> 4 -> 3 -> 2 -> 1 -> 0
            STATE_WAIT:  display_sec_reg = (current_wait_limit > timer_ms) ? (current_wait_limit - timer_ms) / 1000 : 0;
            STATE_FLASH, STATE_YEL1: display_sec_reg = (32'd2000 > timer_ms) ? (32'd2000 - timer_ms) / 1000 : 0;
            STATE_PED:   display_sec_reg = (32'd5000 > timer_ms) ? (32'd5000 - timer_ms) / 1000 : 0;
            default:     display_sec_reg = 8'hFF;
        endcase
    end

    // ============================================================
    // 5. 模块实例化
    // ============================================================
    adc_081s021_driver u_adc (
        .clk(clk), .rst_n(rst_n), 
        .ad_cs(ad_cs), .ad_sclk(ad_sclk), .ad_miso(ad_miso), 
        .adc_data(adc_value) 
    );

    display_6digit_driver u_disp (
        .clk(clk), 
        .adc_val(adc_value),      
        .adc_en(!btn_show_adc),   
        .countdown(display_sec_reg), 
        .seg_data(seg_data), 
        .seg_sel(seg_sel)
    );

    buzzer_pwm_driver u_beep (
        .clk(clk), 
        .enable(buzzer_gate),  
        .pwm_out(beep_pwm) 
    );

endmodule