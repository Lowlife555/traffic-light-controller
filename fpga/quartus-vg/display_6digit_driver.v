module display_6digit_driver (
    input  wire clk,
    input  wire [7:0] adc_val,
    input  wire       adc_en,     // 来自顶层的使能信号
    input  wire [7:0] countdown,
    output reg  [7:0] seg_data,
    output reg  [5:0] seg_sel
);
    // 在 display_6digit_driver 内部修改
    wire [7:0] safe_adc = (adc_val > 255) ? 255 : adc_val;
    wire [3:0] bcd_hun = safe_adc / 100;
    wire [3:0] bcd_ten = (safe_adc % 100) / 10;
    wire [3:0] bcd_one = safe_adc % 10;

    reg [16:0] scan_cnt;
    reg [2:0]  idx;
    always @(posedge clk) begin
        if(scan_cnt >= 50000) begin scan_cnt <= 0; idx <= (idx==5)? 0 : idx+1; end
        else scan_cnt <= scan_cnt + 1;
    end

    function [7:0] hex2seg(input [3:0] n);
        case(n)
            0: hex2seg=8'hC0; 1: hex2seg=8'hF9; 2: hex2seg=8'hA4; 3: hex2seg=8'hB0;
            4: hex2seg=8'h99; 5: hex2seg=8'h92; 6: hex2seg=8'h82; 7: hex2seg=8'hF8;
            8: hex2seg=8'h80; 9: hex2seg=8'h90; default: hex2seg=8'hFF;
        endcase
    endfunction

    always @(*) begin
    seg_sel = 6'b111111;
    seg_sel[idx] = 0; // 位选
    case(idx)
        // 左三位：显示车流量 ADC 转换值 (0-255)
        0: seg_data = adc_en ? hex2seg(bcd_hun) : 8'hFF; 
        1: seg_data = adc_en ? hex2seg(bcd_ten) : 8'hFF;
        2: seg_data = adc_en ? hex2seg(bcd_one) : 8'hFF;
        
        // 中间位：作为分隔符，平时可以熄灭，或者显示一个小横杠
        3: seg_data = adc_en ? 8'hBF : 8'hFF; 
        
        // 右两位：显示倒计时
        4: begin
            if (countdown == 8'hFF) seg_data = 8'hFF; // 初始 IDLE 无请求时不显示
            else seg_data = hex2seg(countdown / 10);
        end
        5: begin
            if (countdown == 8'hFF) seg_data = 8'hFF;
            else seg_data = hex2seg(countdown % 10);
        end
        default: seg_data = 8'hFF;
    endcase
end
endmodule