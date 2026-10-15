module adc_081s021_driver (
    input  wire clk, rst_n,
    output reg  ad_cs, ad_sclk,
    input  wire ad_miso,
    output reg [7:0] adc_data
);
    reg [11:0] clk_div;
    reg [5:0]  state_cnt;
    reg [15:0] shift_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= 0; state_cnt <= 0; ad_cs <= 1; ad_sclk <= 1; 
            adc_data <= 0; shift_in <= 0;
        end else begin
            // 分频产生约 250kHz 的 SCLK (50MHz / 200)
            if (clk_div < 100) clk_div <= clk_div + 1;
            else begin
                clk_div <= 0;
                if (state_cnt < 35) state_cnt <= state_cnt + 1;
                else state_cnt <= 0;

                case (state_cnt)
                    0:  begin ad_cs <= 1; ad_sclk <= 1; shift_in <= 0; end 
                    1:  begin ad_cs <= 0; end  // 开始转换
                    
                    // 2-33 状态：16个时钟周期
                    2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32: ad_sclk <= 0;
                    3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33: begin 
                        ad_sclk <= 1; 
                        shift_in <= {shift_in[14:0], ad_miso}; // 在上升样采样
                    end

                    34: begin 
                        ad_cs <= 1;
                        // 【关键修正】：针对 ADC081S021 (8位)
                        // 数据帧：000 [D7-D0] 00000
                        // 截取 shift_in 的第 12 位到第 5 位
                        adc_data <= shift_in[12:5]; 
                    end
                endcase
            end
        end
    end
endmodule