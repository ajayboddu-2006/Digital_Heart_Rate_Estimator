module preprocessing_stage (
 input clk,
 input rst,
 input signed [7:0] Xin,
 output signed [12:0] Yout
);

 // Stage 1: Differentiation (5-point filter)
 reg signed [7:0] Xin_delay [4:0];  // delay line
 integer k;

 always @(posedge clk or posedge rst) begin
   if (rst) begin
     for (k = 0; k < 5; k = k + 1)
       Xin_delay[k] <= 8'sd0;
   end else begin
     Xin_delay[4] <= Xin_delay[3];
     Xin_delay[3] <= Xin_delay[2];
     Xin_delay[2] <= Xin_delay[1];
     Xin_delay[1] <= Xin_delay[0];
     Xin_delay[0] <= Xin;
   end
 end

 wire signed [12:0] diff_out;
 assign diff_out = ( -Xin_delay[2]
                     - (Xin_delay[1] <<< 1)
                     + (Xin_delay[3] <<< 1)
                     + Xin_delay[4] ) >>> 3;


 // Stage 2: Rectification
 reg signed [8:0] rect_out;
 always @(posedge clk or posedge rst) begin
   if (rst)
     rect_out <= 9'd0;
   else
     // keep rect_out at 9 bits as in your original code
     rect_out <= (diff_out[12] == 1'b0) ? diff_out[8:0] : (~diff_out[8:0] + 1'b1);
 end


 // Stage 3: Moving Window Integration
 integer i; // Declare integer outside the always block
 always @(posedge clk or negedge rst) begin
   if (rst) begin
     for (i = 0; i < 16; i = i + 1)
       Xin_Reg_Inte[i] <= 9'd0;
   end else begin
     for (i = 15; i > 0; i = i - 1)
       Xin_Reg_Inte[i] <= Xin_Reg_Inte[i - 1];
     Xin_Reg_Inte[0] <= rect_out;
   end
 end

 // 16-tap accumulation — unchanged
 wire signed [12:0] sum_lvl_2;
 assign sum_lvl_2 = Xin_Reg_Inte[0] + Xin_Reg_Inte[1] + Xin_Reg_Inte[2] +
                    Xin_Reg_Inte[3] + Xin_Reg_Inte[4] + Xin_Reg_Inte[5] +
                    Xin_Reg_Inte[6] + Xin_Reg_Inte[7] + Xin_Reg_Inte[8] +
                    Xin_Reg_Inte[9] + Xin_Reg_Inte[10]+ Xin_Reg_Inte[11]+
                    Xin_Reg_Inte[12]+ Xin_Reg_Inte[13]+ Xin_Reg_Inte[14]+
                    Xin_Reg_Inte[15];

 assign Yout = sum_lvl_2;
endmodule
