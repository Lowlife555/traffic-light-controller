module adc_081s021_driver (
    input  wire clk, rst_n,
    output reg  ad_cs, ad_sclk,
    input  wire ad_miso,
    output reg [7:0] adc_data
);
    reg [9:0] clk_div;
    reg [5:0] state_cnt;
    reg [15:0] shift_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= 0; state_cnt <= 0; ad_cs <= 1; ad_sclk <= 1;
            adc_data <= 8'd0; shift_in <= 0;
        end else begin
            // 降低到 1MHz 的时钟频率，避免高速走线串扰
            if (clk_div < 10'd49) clk_div <= clk_div + 1'b1; 
            else begin
                clk_div <= 0;
                case (state_cnt)
                    0:  begin ad_cs <= 1; ad_sclk <= 1; state_cnt <= 1; end
                    1:  begin ad_cs <= 0; state_cnt <= 2; shift_in <= 0; end
                    
                    // 偶数态拉低 SCLK
                    2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32: 
                        begin ad_sclk <= 0; state_cnt <= state_cnt + 1'b1; end
                        
                    // 奇数态拉高 SCLK，并在上升沿读取 MISO
                    3,5,7,9,11,13,15,17,19,21,23,25,27,29,31,33: 
                        begin
                            ad_sclk <= 1;
                            shift_in <= {shift_in[14:0], ad_miso};
                            state_cnt <= state_cnt + 1'b1;
                        end
                        
                    34: begin
                            ad_cs <= 1;
                            // ADC081S021帧格式：3位前导0 + 8位数据 + 5位后置尾巴
                            adc_data <= shift_in[12:5]; 
                            state_cnt <= 0;
                        end
                    default: state_cnt <= 0;
                endcase
            end
        end
    end
endmodule