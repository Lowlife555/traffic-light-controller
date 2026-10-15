module buzzer_pwm_driver (
    input  wire clk,
    input  wire enable,  // 来自顶层的 buzzer_gate
    output reg  pwm_out
);
    reg [15:0] freq_cnt;
    // 产生约 2.7kHz 的声音 (50MHz / 2700 / 2)
    always @(posedge clk) begin
        if (enable) begin
            if (freq_cnt >= 16'd9259) begin
                freq_cnt <= 0;
                pwm_out <= ~pwm_out;
            end else freq_cnt <= freq_cnt + 1'b1;
        end else begin
            freq_cnt <= 0;
            pwm_out <= 1'b1; // 低电平有效，所以不响时保持高电平
        end
    end
endmodule