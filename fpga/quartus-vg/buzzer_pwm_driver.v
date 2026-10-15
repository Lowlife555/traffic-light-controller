module buzzer_pwm_driver (
    input  wire clk,
    input  wire [3:0]  state,
    input  wire [31:0] timer_cnt,
    output reg         pwm_out
);
    reg [31:0] tick_cnt;
    reg [31:0] freq_cnt;
    
    // 节奏控制
    wire is_last_3s = (timer_cnt > 2*50000000); // 假设 PED_WALK 共 5s
    wire [31:0] tempo_limit = is_last_3s ? 16666666 : 50000000; // 0.33s vs 1s
    wire [31:0] freq_limit  = is_last_3s ? 25303    : 47801;    // 高音 vs 中音

    always @(posedge clk) begin
        if (state == 4'b0100) begin // 行人通行
            if (tick_cnt < tempo_limit) tick_cnt <= tick_cnt + 1;
            else tick_cnt <= 0;

            // 在每个节奏周期的前 20% 时间发声
            if (tick_cnt < (tempo_limit / 5)) begin
                if (freq_cnt < freq_limit) freq_cnt <= freq_cnt + 1;
                else begin freq_cnt <= 0; pwm_out <= ~pwm_out; end
            end else pwm_out <= 0;
        end else begin
            pwm_out <= 0; tick_cnt <= 0;
        end
    end
endmodule