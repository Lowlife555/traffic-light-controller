module traffic_lights_simlulation (
   // System Clock
   input wire clk_50m,    
   
   // Extension IO Inputs
   input wire rst_n,
   input wire key_ped,
   input wire key_ped2,   
   
   // Extension IO Outputs (Debug)
   output wire led_r,      
   output wire led_g,      
   output wire led_y,      
   output wire ped_led_r, 
   output wire ped_led_g,  
   output reg  buzzer,      
   output wire tl_state_debug
);

    // Debug Signal
    assign tl_state_debug = tl_state[0];

    // Simplified for Debug (No DIP Switches)
    wire [4:0] dynamic_wait = 5'd10;

    // FSM States
    localparam IDLE  = 2'd0, FLASH  = 2'd1, YELLOW = 2'd2, PED_CROSS = 2'd3;
    reg [1:0]  tl_state;
    reg [4:0]  tl_sec; 
    reg [25:0] cnt_1hz;
    reg        ped_req;

    // Pedestrian Request
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) 
            ped_req <= 0;
        else if (!key_ped || !key_ped2) 
            ped_req <= 1;
        else if (tl_state == PED_CROSS) 
            ped_req <= 0; 
    end

    // Main Timer and FSM
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin 
            tl_state <= IDLE; 
            tl_sec <= 0; 
            cnt_1hz <= 0; 
        end else begin
            if (cnt_1hz >= 26'd49_999_999) begin
                cnt_1hz <= 0;
                case (tl_state)
                    IDLE: begin
                        if (ped_req) begin
                            if (tl_sec == 0 || tl_sec > dynamic_wait)  
                                tl_sec <= dynamic_wait;
                            else if (tl_sec == 1) begin 
                                tl_state <= FLASH; 
                                tl_sec <= 3; 
                            end else 
                                tl_sec <= tl_sec - 1;
                        end else 
                            tl_sec <= 0;
                    end
                    FLASH: begin
                        if (tl_sec <= 1) begin 
                            tl_state <= YELLOW; 
                            tl_sec <= 2; 
                        end else 
                            tl_sec <= tl_sec - 1;
                    end
                    YELLOW: begin
                        if (tl_sec <= 1) begin 
                            tl_state <= PED_CROSS; 
                            tl_sec <= 5; 
                        end else 
                            tl_sec <= tl_sec - 1;
                    end
                    PED_CROSS: begin
                        if (tl_sec <= 1) begin 
                            tl_state <= IDLE; 
                            tl_sec <= 0; 
                        end else 
                            tl_sec <= tl_sec - 1;
                    end
                endcase
            end else 
                cnt_1hz <= cnt_1hz + 1;
        end
    end

    // LED Outputs
    assign led_r = ~(tl_state == PED_CROSS);
    assign led_y = ~(tl_state == YELLOW);
    assign led_g = ~((tl_state == IDLE) || (tl_state == FLASH && cnt_1hz[24])); 
    assign ped_led_g = (tl_state == PED_CROSS) ? 1'b0 : 1'b1; 
    assign ped_led_r = (tl_state == PED_CROSS) ? 1'b1 : 1'b0;
   
    // Buzzer Control
    reg [24:0] beep_timer;
    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin 
            buzzer <= 0;
            beep_timer <= 0; 
        end
        else if (tl_state == PED_CROSS) begin
            beep_timer <= (beep_timer >= 25'd24_999_999) ? 0 : beep_timer + 1;
            if (tl_sec <= 3) 
                buzzer <= (beep_timer[22]) ? 1'b1 : 1'b0; 
            else 
                buzzer <= (beep_timer[23]) ? 1'b1 : 1'b0; 
        end else begin
            buzzer <= 0; 
            beep_timer <= 0;
        end
    end

endmodule