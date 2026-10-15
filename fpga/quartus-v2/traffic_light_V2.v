module traffic_light_V2 #(
  parameter I2C_SLAVE_ADDR = 8'h78 
)(
   input wire clk_50m,    
   input wire rst_n,      
   
// ped btns
  input wire key_ped,
   input wire key_ped2,   
   
    // dip switches for flow
   input wire [7:0] sw_flow,
   
  // traffic lights
   output wire led_r,      
 output wire led_g,      
   output wire led_y,      
   
   // ped lights
  output wire ped_led_r, 
   output wire ped_led_g,  
   
   // high active
  output reg  buzzer,      
   
  (* altera_attribute = "-name WEAK_PULL_UP_RESISTOR ON" *) output wire oled_scl,
    (* altera_attribute = "-name WEAK_PULL_UP_RESISTOR ON" *) inout  wire oled_sda
);

    // sw active low
  wire [7:0] sw_active = ~sw_flow; 
   
   // sum switches
  wire [3:0] sw_count = sw_active[0] + sw_active[1] + sw_active[2] + sw_active[3] + 
                        sw_active[4] + sw_active[5] + sw_active[6] + sw_active[7];

   // flow percent approx
  wire [7:0] flow_val = sw_count * 4'd12; 

   // calc wait time (5~20s)
  wire [4:0] dynamic_wait = 5 + ((sw_count * 4'd15) >> 3);

   
   // FSM
   localparam IDLE  = 2'd0, FLASH  = 2'd1, YELLOW = 2'd2, PED_CROSS    = 2'd3;
 reg [1:0]  tl_state;
   reg [4:0]  tl_sec; 
  reg [25:0] cnt_1hz;
    reg        ped_req;

  always @(posedge clk_50m or negedge rst_n) begin
      if (!rst_n) ped_req <= 0;
       else if (!key_ped || !key_ped2) ped_req <= 1;
      else if (tl_state == PED_CROSS) ped_req <= 0; 
    end

   always @(posedge clk_50m or negedge rst_n) begin
      if (!rst_n) begin 
          tl_state <= IDLE; tl_sec <= 0; cnt_1hz <= 0; 
      end else begin
           if (cnt_1hz >= 26'd49_999_999) begin
               cnt_1hz <= 0;
              case (tl_state)
                   IDLE: begin
                      if (ped_req) begin
                         // reload time if first press or counting down
                         if (tl_sec == 0 || tl_sec > dynamic_wait)  
                                tl_sec <= dynamic_wait;
                          else if (tl_sec == 1) begin 
                                tl_state <= FLASH; tl_sec <= 3; 
                          end else 
                             tl_sec <= tl_sec - 1;
                        end else tl_sec <= 0;
                 end
                    FLASH: begin
                        if (tl_sec <= 1) begin tl_state <= YELLOW; tl_sec <= 2; end 
                       else tl_sec <= tl_sec - 1;
                    end
                 YELLOW: begin
                       if (tl_sec <= 1) begin tl_state <= PED_CROSS; tl_sec <= 5; end 
                        else tl_sec <= tl_sec - 1;
                 end
                    PED_CROSS: begin
                        if (tl_sec <= 1) begin tl_state <= IDLE; tl_sec <= 0; end
                      else tl_sec <= tl_sec - 1;
                  end
               endcase
          end else cnt_1hz <= cnt_1hz + 1;
       end
  end

    assign led_r = ~(tl_state == PED_CROSS);
   assign led_y = ~(tl_state == YELLOW);
 assign led_g = ~((tl_state == IDLE) || (tl_state == FLASH && cnt_1hz[24])); 
    assign ped_led_g = (tl_state == PED_CROSS) ? 1'b0 : 1'b1; 
  assign ped_led_r = (tl_state == PED_CROSS) ? 1'b1 : 1'b0;
   
    // buzzer ctrl
    reg [24:0] beep_timer;
   always @(posedge clk_50m or negedge rst_n) begin
       if (!rst_n) begin 
            buzzer <= 0;
           beep_timer <= 0; 
       end
       else if (tl_state == PED_CROSS) begin
            beep_timer <= (beep_timer >= 25'd24_999_999) ? 0 : beep_timer + 1;
            // fast beep when timeout <3s
           if (tl_sec <= 3) begin
               buzzer <= (beep_timer[22]) ? 1'b1 : 1'b0; 
          end else begin
             buzzer <= (beep_timer[23]) ? 1'b1 : 1'b0; 
          end
      end else begin
          buzzer <= 0; 
         beep_timer <= 0;
       end
 end

   // i2c driver
    reg [8:0] i2c_clk_cnt;
  reg [1:0] i2c_phase;
 always @(posedge clk_50m or negedge rst_n) begin
       if (!rst_n) begin i2c_clk_cnt <= 0; i2c_phase <= 0; end
      else if (i2c_clk_cnt == 124) begin i2c_clk_cnt <= 0; i2c_phase <= i2c_phase + 1; end
     else i2c_clk_cnt <= i2c_clk_cnt + 1;
  end

   reg i2c_req, i2c_is_data, i2c_done;
    reg [7:0] i2c_data_in, shift_reg;
    reg [3:0] i2c_state;
 reg [2:0] bit_cnt;
   reg sda_dir, sda_out, scl_out;
    assign oled_scl = scl_out;
   assign oled_sda = sda_dir ? sda_out : 1'bz;

 localparam I2C_IDLE=0, I2C_START=1, I2C_SEND_ADDR=2, I2C_ACK_ADDR=3, I2C_SEND_CTRL=4, I2C_ACK_CTRL=5, I2C_SEND_DATA=6, I2C_ACK_DATA=7, I2C_STOP=8;

    always @(posedge clk_50m or negedge rst_n) begin
       if (!rst_n) begin i2c_state <= I2C_IDLE; scl_out <= 1; sda_out <= 1; sda_dir <= 1; i2c_done <= 0; end
       else if (i2c_clk_cnt == 124) begin
          case (i2c_state)
                I2C_IDLE: begin scl_out <= 1; sda_out <= 1; sda_dir <= 1; if (i2c_req && !i2c_done) begin i2c_state <= I2C_START; shift_reg <= I2C_SLAVE_ADDR; end end
               I2C_START: case(i2c_phase) 2'd1: sda_out<=0; 2'd3: begin scl_out<=0; bit_cnt<=7; i2c_state<=I2C_SEND_ADDR; end endcase
              I2C_SEND_ADDR, I2C_SEND_CTRL, I2C_SEND_DATA: case(i2c_phase) 2'd0: begin scl_out<=0; sda_out<=shift_reg[bit_cnt]; sda_dir<=1; end 2'd1,2'd2: scl_out<=1; 2'd3: begin scl_out<=0; if(bit_cnt==0) begin if(i2c_state==I2C_SEND_ADDR) i2c_state<=I2C_ACK_ADDR; else if(i2c_state==I2C_SEND_CTRL) i2c_state<=I2C_ACK_CTRL; else i2c_state<=I2C_ACK_DATA; end else bit_cnt<=bit_cnt-1; end endcase
              I2C_ACK_ADDR, I2C_ACK_CTRL, I2C_ACK_DATA: case(i2c_phase) 2'd0: begin scl_out<=0; sda_dir<=0; end 2'd1,2'd2: scl_out<=1; 2'd3: begin scl_out<=0; if(i2c_state==I2C_ACK_ADDR) begin i2c_state<=I2C_SEND_CTRL; shift_reg<=i2c_is_data?8'h40:8'h00; bit_cnt<=7; end else if(i2c_state==I2C_ACK_CTRL) begin i2c_state<=I2C_SEND_DATA; shift_reg<=i2c_data_in; bit_cnt<=7; end else i2c_state<=I2C_STOP; end endcase
             I2C_STOP: case(i2c_phase) 2'd0: begin scl_out<=0; sda_out<=0; sda_dir<=1; end 2'd1,2'd2: scl_out<=1; 2'd3: begin sda_out<=1; i2c_done<=1; i2c_state <= I2C_IDLE; end endcase
               default: i2c_state <= I2C_IDLE;
         endcase
        end else if (i2c_done && !i2c_req) i2c_done <= 0;
   end

 // oled map
   function [39:0] get_char;
        input [7:0] ascii;
      case(ascii)
           "A": get_char = 40'h7E0909097E; "B": get_char = 40'h7F49494936; "C": get_char = 40'h3E41414122;
          "D": get_char = 40'h7F4141221C; "E": get_char = 40'h7F49494941; "F": get_char = 40'h7F09090901;
         "G": get_char = 40'h3E4149493A; "H": get_char = 40'h7F0808087F; "I": get_char = 40'h417F410000;
           "L": get_char = 40'h7F40404040; "M": get_char = 40'h7F020C027F; "N": get_char = 40'h7F0408107F; 
          "O": get_char = 40'h3E4141413E; "R": get_char = 40'h7F09192946; "S": get_char = 40'h2649494932; 
           "T": get_char = 40'h01017F0101; "U": get_char = 40'h3F4040403F; "W": get_char = 40'h3F4038403F; 
           "Y": get_char = 40'h0304780403; "0": get_char = 40'h3E5149453E; "1": get_char = 40'h00427F4000; 
          "2": get_char = 40'h4261514946; "3": get_char = 40'h2141454B31; "4": get_char = 40'h1814127F10; 
         "5": get_char = 40'h2745454539; "6": get_char = 40'h3E49494926; "7": get_char = 40'h010101017F;
          "8": get_char = 40'h3649494936; "9": get_char = 40'h064949493E; ":": get_char = 40'h0000360000; 
         "[": get_char = 40'h007F414100; "]": get_char = 40'h0041417F00; "*": get_char = 40'h7F7F7F7F7F; 
         "-": get_char = 40'h0808080808; " ": get_char = 40'h0000000000;
           default: get_char = 40'h0000000000;
        endcase
   endfunction

    reg [7:0] char_to_draw;
  reg [1:0] line_idx;
   reg [4:0] char_idx;

  always @(*) begin
      char_to_draw = " "; 
        case(line_idx)
           2'd0: // title
                case(char_idx)
                   0: char_to_draw = "T"; 1: char_to_draw = "R"; 2: char_to_draw = "A"; 3: char_to_draw = "F"; 4: char_to_draw = "F"; 5: char_to_draw = "I"; 6: char_to_draw = "C"; 8: char_to_draw = "S"; 9: char_to_draw = "Y"; 10: char_to_draw = "S"; 11: char_to_draw = "T"; 12: char_to_draw = "E"; 13: char_to_draw = "M"; default: char_to_draw = " ";
               endcase
          2'd1: // time
              case(char_idx)
                  0: char_to_draw = "T"; 1: char_to_draw = "I"; 2: char_to_draw = "M"; 3: char_to_draw = "E"; 4: char_to_draw = ":"; 
                   5: char_to_draw = (tl_sec >= 10) ? ("0" + (tl_sec/10)) : "0"; 
                  6: char_to_draw = "0" + (tl_sec % 10); 
                    8: char_to_draw = "S"; 9: char_to_draw = "E"; 10: char_to_draw = "C"; default: char_to_draw = " ";
                endcase
         2'd2: // state
              case(char_idx)
                   0: char_to_draw = "S"; 1: char_to_draw = "T"; 2: char_to_draw = "A"; 3: char_to_draw = "T"; 4: char_to_draw = "E"; 5: char_to_draw = ":";
                 6: case(tl_state) IDLE: char_to_draw="G"; FLASH: char_to_draw="F"; YELLOW: char_to_draw="W"; PED_CROSS: char_to_draw="C"; endcase
                   7: case(tl_state) IDLE: char_to_draw="R"; FLASH: char_to_draw="L"; YELLOW: char_to_draw="A"; PED_CROSS: char_to_draw="R"; endcase
                 8: case(tl_state) IDLE: char_to_draw="N"; FLASH: char_to_draw="S"; YELLOW: char_to_draw="I"; PED_CROSS: char_to_draw="O"; endcase
                  9: case(tl_state) IDLE: char_to_draw=" "; FLASH: char_to_draw="H"; YELLOW: char_to_draw="T"; PED_CROSS: char_to_draw="S"; endcase
                  10:case(tl_state) IDLE: char_to_draw=" "; FLASH: char_to_draw=" "; YELLOW: char_to_draw=" "; PED_CROSS: char_to_draw="S"; endcase
                 default: char_to_draw = " ";
             endcase
           2'd3: // flow
              case(char_idx)
                  0: char_to_draw = "F"; 
                 1: char_to_draw = (flow_val==100)?"1":((flow_val>=10)?("0"+(flow_val/10)):" "); 
                   2: char_to_draw = (flow_val==100)?"0":("0"+(flow_val%10)); 
                    3: char_to_draw = (flow_val==100)?"0":" ";
                 4: char_to_draw = "["; 
                  15: char_to_draw = "]";
                 5,6,7,8,9,10,11,12,13,14: char_to_draw = ((char_idx-5) < (flow_val/10)) ? "*" : "-";
                 default: char_to_draw = " ";
               endcase
      endcase
   end

  // oled fsm
    localparam M_INIT=0, M_CLEAR_POS=1, M_CLEAR_DATA=2, M_POS=3, M_DRAW=4, M_IDLE=5;
 reg [2:0]  m_state;
   reg [12:0] clear_cnt;
   reg [7:0]  init_idx;
 reg [23:0] frame_timer;
    reg [2:0]  pixel_idx;
   reg [39:0] v_dots;

 wire [7:0] init_cmds [0:23];
   assign init_cmds[0]=8'hAE; assign init_cmds[1]=8'h20; assign init_cmds[2]=8'h02; 
  assign init_cmds[3]=8'h8D; assign init_cmds[4]=8'h14; assign init_cmds[5]=8'hAF;
  assign init_cmds[6]=8'hB0; assign init_cmds[7]=8'hC8; assign init_cmds[8]=8'hA1; 
  assign init_cmds[9]=8'h00; assign init_cmds[10]=8'h10; assign init_cmds[11]=8'h40; 
  assign init_cmds[12]=8'h81; assign init_cmds[13]=8'h7F; assign init_cmds[14]=8'hA6; 
   assign init_cmds[15]=8'hA4; assign init_cmds[16]=8'hD5; assign init_cmds[17]=8'h80;
   assign init_cmds[18]=8'hD9; assign init_cmds[19]=8'hF1; assign init_cmds[20]=8'hDA; 
   assign init_cmds[21]=8'h12; assign init_cmds[22]=8'hDB; assign init_cmds[23]=8'h40;

   always @(posedge clk_50m or negedge rst_n) begin
      if (!rst_n) begin
         m_state <= M_INIT; init_idx <= 0; clear_cnt <= 0; i2c_req <= 0; frame_timer <= 0;
             line_idx <= 0; char_idx <= 0; pixel_idx <= 0;
     end else begin
           case (m_state)
             M_INIT: begin
                  if (!i2c_req) begin i2c_req <= 1; i2c_is_data <= 0; i2c_data_in <= init_cmds[init_idx]; end
                   else if (i2c_done) begin i2c_req <= 0; if (init_idx == 23) m_state <= M_CLEAR_POS; else init_idx <= init_idx + 1; end
               end
             M_CLEAR_POS: begin
                   if (!i2c_req) begin
                      i2c_req <= 1; i2c_is_data <= 0;
                       case(pixel_idx[1:0])
                         2'd0: i2c_data_in <= 8'hB0 + clear_cnt[10:7];
                           2'd1: i2c_data_in <= 8'h00;
                            2'd2: i2c_data_in <= 8'h10;
                          default: i2c_data_in <= 8'hB0;
                       endcase
                   end else if (i2c_done) begin
                      i2c_req <= 0;
                       if (pixel_idx[1:0] == 2'd2) begin pixel_idx <= 0; m_state <= M_CLEAR_DATA; end
                      else pixel_idx[1:0] <= pixel_idx[1:0] + 1;
                 end
               end
              M_CLEAR_DATA: begin 
                   if (!i2c_req) begin i2c_req <= 1; i2c_is_data <= 1; i2c_data_in <= 8'h00; end
                    else if (i2c_done) begin 
                      i2c_req <= 0; 
                       if (clear_cnt[6:0] == 127) begin 
                          if (clear_cnt[10:7] == 7) begin m_state <= M_POS; clear_cnt <= 0; end
                          else begin clear_cnt <= {clear_cnt[10:7] + 1'b1, 7'd0}; m_state <= M_CLEAR_POS; end
                      end else clear_cnt <= clear_cnt + 1; 
                 end
               end
               M_POS: begin 
                 if (!i2c_req) begin
                        i2c_req <= 1; i2c_is_data <= 0;
                      case(pixel_idx[1:0])
                           2'd0: case(line_idx) 2'd0: i2c_data_in<=8'hB0; 2'd1: i2c_data_in<=8'hB2; 2'd2: i2c_data_in<=8'hB4; 2'd3: i2c_data_in<=8'hB6; endcase
                          2'd1: i2c_data_in <= 8'h00; 
                          2'd2: i2c_data_in <= 8'h10; 
                          default: i2c_data_in <= 8'hB0;
                     endcase
                   end else if (i2c_done) begin
                        i2c_req <= 0;
                      if (pixel_idx[1:0] == 2'd2) begin pixel_idx <= 0; m_state <= M_DRAW; end
                       else pixel_idx[1:0] <= pixel_idx[1:0] + 1;
                 end
              end
               M_DRAW: begin
                   if (!i2c_req) begin
                      i2c_req <= 1; i2c_is_data <= 1;
                        v_dots = get_char(char_to_draw);
                        case(pixel_idx)
                         3'd0: i2c_data_in <= v_dots[39:32];
                           3'd1: i2c_data_in <= v_dots[31:24];
                          3'd2: i2c_data_in <= v_dots[23:16];
                            3'd3: i2c_data_in <= v_dots[15:8];
                           3'd4: i2c_data_in <= v_dots[7:0];
                           default: i2c_data_in <= 8'h00;
                        endcase
                 end else if (i2c_done) begin
                     i2c_req <= 0;
                       if (pixel_idx == 3'd5) begin
                            pixel_idx <= 0;
                           if (char_idx == 5'd20) begin 
                              char_idx <= 0;
                               if (line_idx == 2'd3) begin line_idx <= 0; m_state <= M_IDLE; end
                              else begin line_idx <= line_idx + 1; m_state <= M_POS; end
                            end else char_idx <= char_idx + 1;
                      end else pixel_idx <= pixel_idx + 1;
                   end
                end
              M_IDLE: begin
                  if (frame_timer == 24'd1_000_000) begin frame_timer <= 0; m_state <= M_POS; end
                    else frame_timer <= frame_timer + 1;
               end
               default: m_state <= M_IDLE;
          endcase
       end
 end
endmodule