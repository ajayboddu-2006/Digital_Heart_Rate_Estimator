
module HR_estimator #(
        parameter CLK_FREQ = 200  // Clock frequency in Hz
)(
    input  wire        clk,
    input  wire        rst,        
    input  signed [7:0] Xin,
    output wire [31:0] bpm,
    output wire signed [12:0] Yout,
    output wire peak_detected,
    output wire [31:0] avg_interval
);    
    
    // Stage 1: Preprocessing
    preprocessing_stage filter_inst(
        .clk(clk), 
        .rst(rst), 
        .Xin(Xin), 
        .Yout(Yout)
    );
    
    // Stage 2: Peak Detection
    peak_detector peak_detector_inst(
        .clk(clk), 
        .rst(rst), 
        .transformed_signal(Yout), 
        .peak_detected(peak_detected)
    );
    
    // Stage 3: RR Interval Estimation
    RR_Interval_Calc #(.NUM_PEAKS(4)) RR_inst(
        .clk(clk), 
        .rst(rst), 
        .peak_detected(peak_detected), 
        .avg_interval(avg_interval)
    );
  
     bpm_calc #(
        .CLK_FREQ(CLK_FREQ)
    ) bpm_calc (
        .clk(clk),
        .rst(rst),
        .rr_cycles(avg_interval),
        .bpm(bpm)
    );
endmodule
