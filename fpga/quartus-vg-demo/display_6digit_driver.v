module display_6digit_driver (
    input  wire clk,
    input  wire [7:0] adc_val,
    input  wire       adc_en,     
    input  wire [7:0] countdown,
    output reg  [7:0] seg_data,
    output reg  [5:0] seg_sel
);

    // --- 改进的 BCD 转换逻辑 ---
    // 直接使用 8 位宽，避免编译器误判
    wire [3:0] bcd_hun = adc_val / 8'd100;           // 百位
    wire [3:0] bcd_ten = (adc_val % 8'd100) / 8'd10; // 十位
    wire [3:0] bcd_one = adc_val % 8'd10;            // 个位

    reg [16:0] scan_cnt;
    reg [2:0]  idx;

    // 数码管扫描时钟 (约 1kHz)
    always @(posedge clk) begin
        if(scan_cnt >= 17'd50000) begin 
            scan_cnt <= 0; 
            idx <= (idx == 3'd5) ? 3'd0 : idx + 3'd1; 
        end
        else scan_cnt <= scan_cnt + 1;
    end

    // 共阳极数码管编码函数
    function [7:0] hex2seg(input [3:0] n);
        case(n)
            4'h0: hex2seg=8'hC0; 4'h1: hex2seg=8'hF9; 4'h2: hex2seg=8'hA4; 4'h3: hex2seg=8'hB0;
            4'h4: hex2seg=8'h99; 4'h5: hex2seg=8'h92; 4'h6: hex2seg=8'h82; 4'h7: hex2seg=8'hF8;
            4'h8: hex2seg=8'h80; 4'h9: hex2seg=8'h90; 4'hA: hex2seg=8'h88; 4'hB: hex2seg=8'h83;
            default: hex2seg=8'hFF;
        endcase
    endfunction

    always @(*) begin
        seg_sel = 6'b111111;
        seg_sel[idx] = 0; // 选通当前位
        
        case(idx)
            // 左三位显示 ADC 原始值
            0: seg_data = adc_en ? hex2seg(bcd_hun) : 8'hFF;
            1: seg_data = adc_en ? hex2seg(bcd_ten) : 8'hFF;
            2: seg_data = adc_en ? hex2seg(bcd_one) : 8'hFF;
            
            // 中间分隔符
            3: seg_data = adc_en ? 8'hBF : 8'hFF; 
            
            // 右两位显示倒计时
            4: begin
                if (countdown == 8'hFF) seg_data = 8'hFF;
                else seg_data = hex2seg(countdown / 8'd10);
            end
            5: begin
                if (countdown == 8'hFF) seg_data = 8'hFF;
                else seg_data = hex2seg(countdown % 8'd10);
            end
            default: seg_data = 8'hFF;
        endcase
    end
endmodule