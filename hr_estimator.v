`timescale 1us/1ps
module HR_estimator #(
        parameter CLK_FREQ = 200, // Clock frequency in Hz
        parameter NUM_PEAKS = 4
)(
    input  wire        clk,
    input  wire        rst,        
    input  signed [7:0] Xin,
    output wire [31:0] bpm
);    
    wire signed [12:0] Yout;
    wire peak_detected;
    wire [31:0] avg_interval;
    wire clk_div;
    // Stage 1: Preprocessing
    
    clock_div_100M_to_200 clk_div_inst(
        .clk_in(clk),
        .rst(rst),
        .clk_out(clk_div)   
    );

    preprocessing_stage filter_inst(
        .clk(clk_div), 
        .rst(rst), 
        .Xin(Xin), 
        .Yout(Yout)
    );
    
    // Stage 2: Peak Detection
    peak_detector peak_detector_inst(
        .clk(clk_div), 
        .rst(rst), 
        .transformed_signal(Yout), 
        .peak_detected(peak_detected)
    );
    
    // Stage 3: RR Interval Estimation
    RR_Interval_Calc #(.NUM_PEAKS(NUM_PEAKS)) RR_inst(
        .clk(clk_div), 
        .rst(rst), 
        .peak_detected(peak_detected), 
        .avg_interval(avg_interval)
    );
  
     bpm_calc #(
        .CLK_FREQ(CLK_FREQ)
    ) bpm_calc (
        .clk(clk_div),
        .rst(rst),
        .rr_cycles(avg_interval),
        .bpm(bpm)
    );
endmodule


module clock_div_100M_to_200 (
    input  wire clk_in,   // 100 MHz clock
    input  wire rst,
    output reg  clk_out   // 200 Hz output clock
);
    localparam integer DIV      = 500000;
    localparam integer HALF_DIV = DIV / 2;

    // log2(500000) ≈ 19 bits
    reg [18:0] count;

    always @(posedge clk_in or posedge rst) begin
        if (rst) begin
            count   <= 19'd0;
            clk_out <= 1'b0;
        end else begin
            // counter rolls over
            if (count == DIV-1)
                count <= 19'd0;
            else
                count <= count + 19'd1;

            // 50% duty cycle toggles
            if (count == HALF_DIV-1 || count == DIV-1)
                clk_out <= ~clk_out;
        end
    end
endmodule

module clock_gating_cell( input clk, input enable, input rst, output gated_clk );
 reg enable_latched; 
 always @(negedge clk or posedge rst) begin 
    if (rst) 
        enable_latched <= 1'b0; 
    else 
        enable_latched <= enable; 
    end 
    assign gated_clk = clk & enable_latched; 
endmodule




module preprocessing_stage #(
    parameter signed [7:0] FLAT_THRESH = 8'sd20,
    parameter integer      FLAT_CYCLES = 16
)(
    input  wire              clk,
    input  wire              rst,
    input  wire signed [7:0] Xin,
    output wire signed [12:0] Yout
);

    // =========================================================
    // PATH 1: LIGHT ACTIVITY MONITOR (always running on clk)
    // =========================================================

    reg  signed [7:0] Xin_prev;
    reg  [7:0]        flat_cnt;

    wire signed [8:0] diff     = Xin - Xin_prev;
    wire [8:0]        diff_abs = diff[8] ? (~diff + 9'sd1) : diff;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Xin_prev <= 8'sd0;
            flat_cnt <= 8'd0;
        end else begin
            Xin_prev <= Xin;

            if (diff_abs <= {1'b0, FLAT_THRESH}) begin
                // if (flat_cnt != 8'hFF)
                    flat_cnt <= flat_cnt + 1'b1;
            end else begin
                flat_cnt <= 8'd0;
            end
        end
    end

    // =========================================================
    // POWER FSM: ACTIVE / SLEEP  (runs on clk)
    // =========================================================
    localparam STATE_ACTIVE = 1'b0;
    localparam STATE_SLEEP  = 1'b1;

    reg state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_ACTIVE;
        end else begin
            case (state)
                STATE_ACTIVE:
                    if (flat_cnt >= FLAT_CYCLES[7:0])
                        state <= STATE_SLEEP;

                STATE_SLEEP:
                    if (diff_abs > {1'b0, FLAT_THRESH})
                        state <= STATE_ACTIVE;
            endcase
        end
    end

    wire pre_proc_ce = (state == STATE_ACTIVE);

    // =========================================================
    // TRUE CLOCK GATING FOR HEAVY PIPELINE
    // =========================================================
    wire clk_gated;

    clock_gating_cell CG_CELL(
        .clk(clk),
        .enable(pre_proc_ce),
        .rst(rst),
        .gated_clk(clk_gated)
    );

    // =========================================================
    // PATH 2: HEAVY PREPROCESSING PIPELINE (runs only on clk_gated)
    // =========================================================

    // ---- Stage 1: 5-point derivative ----
    reg signed [7:0] Xin_delay [4:0];
    integer k;

    always @(posedge clk_gated or posedge rst) begin
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

    // ---- Stage 2: rectification ----
    reg signed [8:0] rect_out;

    always @(posedge clk_gated or posedge rst) begin
        if (rst) begin
            rect_out <= 9'd0;
        end else begin
            rect_out <= (diff_out[12] ? (~diff_out[8:0] + 1'b1) : diff_out[8:0]);
        end
    end

    // ---- Stage 3: 16-sample moving window integrator ----
    reg signed [8:0] Xin_Reg_Inte [15:0];
    integer i;

    always @(posedge clk_gated or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1)
                Xin_Reg_Inte[i] <= 9'd0;
        end else begin
            for (i = 15; i > 0; i = i - 1)
                Xin_Reg_Inte[i] <= Xin_Reg_Inte[i - 1];
            Xin_Reg_Inte[0] <= rect_out;
        end
    end

    // ---- Final sum ----
    wire signed [12:0] sum_lvl_2;
    assign sum_lvl_2 = Xin_Reg_Inte[0]  + Xin_Reg_Inte[1]  + Xin_Reg_Inte[2]  +
                       Xin_Reg_Inte[3]  + Xin_Reg_Inte[4]  + Xin_Reg_Inte[5]  +
                       Xin_Reg_Inte[6]  + Xin_Reg_Inte[7]  + Xin_Reg_Inte[8]  +
                       Xin_Reg_Inte[9]  + Xin_Reg_Inte[10] + Xin_Reg_Inte[11] +
                       Xin_Reg_Inte[12] + Xin_Reg_Inte[13] + Xin_Reg_Inte[14] +
                       Xin_Reg_Inte[15];

    assign Yout = sum_lvl_2;

endmodule




// =============================================
// PEAK DETECTOR WITH POWER-SCALED CLOCK
// FAST: uses clk
// SLOW: uses clk_slow = clk / DIV_SLOW (50% duty)
// =============================================
module peak_detector #(
    // how long (in samples) with no peaks before going to SLOW
    parameter integer IDLE_SAMPLES = 50,   // at 200 Hz ≈ 2 s
    // divide factor for slow clock (must be even)
    parameter integer DIV_SLOW    = 16
)(
    input  wire              clk,                 // sample clock (200 Hz)
    input  wire              rst,
    input  wire signed [12:0] transformed_signal, // from preprocessing
    output reg               peak_detected        // registered peak flag
);
    // ---------- 1) Sample buffer (always at base clock) ----------
    reg signed [12:0] signal_buffer [0:255];
    reg [7:0]         index;
    integer           j;

    always @(posedge clk or posedge rst) begin
        if (rst)
            index <= 8'd0;
        else if (index < 8'd255)
            index <= index + 8'd1;
        else
            index <= 8'd0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (j = 0; j < 256; j = j + 1)
                signal_buffer[j] <= 13'd0;
        end else begin
            signal_buffer[index] <= transformed_signal;
        end
    end

    // ---------- 2) Slow clock generator (50% duty cycle) ----------
    wire clk_slow;
    clock_divider #(.DIV(DIV_SLOW)) u_div (
        .clk_in (clk),
        .rst    (rst),
        .clk_out(clk_slow)
    );

    // ---------- 3) Power-scaling FSM: FAST vs SLOW ----------
    localparam STATE_FAST = 1'b0;
    localparam STATE_SLOW = 1'b1;

    reg        ps_state;
    reg [15:0] idle_cnt;     // how many samples since last peak

    // We'll use the current threshold to make raw_peak (front-end)
    reg  signed [12:0] threshold;
    wire       raw_peak;

    assign raw_peak = (transformed_signal > threshold);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ps_state <= STATE_FAST;
            idle_cnt <= 16'd0;
        end else begin
            case (ps_state)
                // FAST mode: update counters every sample
                STATE_FAST: begin
                    if (raw_peak)
                        idle_cnt <= 16'd0;
                    else
                        idle_cnt <= idle_cnt + 16'd1;

                    if (idle_cnt >= IDLE_SAMPLES)
                        ps_state <= STATE_SLOW;  // go slow after long inactivity
                end

                // SLOW mode: we only care if a new peak appears
                STATE_SLOW: begin
                    if (raw_peak) begin
                        // activity came back → go fast again
                        ps_state <= STATE_FAST;
                        idle_cnt <= 16'd0;
                    end
                end
            endcase
        end
    end

    // ---------- 4) Select scaled clock for heavy logic ----------
    // For simulation / concept, a simple mux is OK.
    // In real ASIC, this would be a dedicated clock mux cell.
    wire clk_heavy;

    assign clk_scaled = (ps_state == STATE_FAST) ? clk : clk_slow;

    // ---------- 5) Heavy logic: max over buffer + threshold ----------
    reg signed [12:0] max_value, temp_max_value;

    always @(posedge clk_scaled or posedge rst) begin
        if (rst) begin
            max_value      <= 13'd0;
            temp_max_value <= 13'd0;
        end else begin
            temp_max_value = 13'd0;
            for (j = 0; j < 256; j = j + 1)
                if (signal_buffer[j] > temp_max_value)
                    temp_max_value = signal_buffer[j];

            max_value <= temp_max_value;
        end
    end

    always @(posedge clk_scaled or posedge rst) begin
        if (rst)
            threshold <= 13'd0;
        else
            threshold <= (max_value >>> 1) + 13'd50;  // max/2 + offset
    end

    // ---------- 6) Final registered peak output ----------
    always @(posedge clk or posedge rst) begin
        if (rst)
            peak_detected <= 1'b0;
        else
            peak_detected <= raw_peak;
    end
endmodule


// =============================================
// 50% DUTY CYCLE CLOCK DIVIDER
// clk_out = clk_in / DIV  (DIV must be even)
// =============================================
module clock_divider #
(
    parameter integer DIV = 16      // divide factor, must be even
)
(
    input  wire clk_in,
    input  wire rst,
    output reg  clk_out
);
    localparam HALF = DIV/2;

    reg [$clog2(DIV)-1:0] counter;

    always @(posedge clk_in or posedge rst) begin
        if (rst) begin
            counter <= 0;
            clk_out <= 1'b0;
        end else begin
            // count up
            if (counter == DIV-1)
                counter <= 0;
            else
                counter <= counter + 1'b1;

            // toggle clk_out in middle and at end → 50% duty
            if (counter == HALF-1 || counter == DIV-1)
                clk_out <= ~clk_out;
        end
    end
endmodule


module RR_Interval_Calc #(
    parameter integer NUM_PEAKS = 4 // number of RR intervals to average once
)(
    input  wire       clk,            // main/sample clock (e.g., 200 Hz)
    input  wire       rst,
    input  wire       peak_detected,  // 1-cycle pulse per R-peak
    output reg [31:0] avg_interval,   // final average RR in clk cycles
    output reg        output_valid    // high when avg_interval is ready
);

    // -------------------------------
    // Internal "done" flag
    // -------------------------------
    reg done;

    // -------------------------------
    // Gated clock for RR logic
    //  - Active while done=0
    //  - Off once done=1 (no more switching)
    // -------------------------------
    wire clk_rr;
    clock_gating_cell RR_CG (
        .clk      (clk),
        .enable   (!done),
        .rst      (rst),
        .gated_clk(clk_rr)
    );

    // -------------------------------
    // 1) Edge detector for peak_detected (on gated clock)
    // -------------------------------
    reg prev_peak_detected;
    wire peak_rising_edge = peak_detected && !prev_peak_detected;

    always @(posedge clk_rr or posedge rst) begin
        if (rst)
            prev_peak_detected <= 1'b0;
        else
            prev_peak_detected <= peak_detected;
    end

    // -------------------------------
    // 2) Timebase counter (full-rate while active)
    // -------------------------------
    reg [15:0] current_time;
    reg [15:0] prev_time;

    always @(posedge clk_rr or posedge rst) begin
        if (rst) begin
            current_time <= 16'd0;
            done         <= 1'b0;
        end else begin
            // Only counts while not done; once done, clk_rr stops anyway
            if (!done)
                current_time <= current_time + 16'd1;
        end
    end

    // -------------------------------
    // 3) Interval accumulation and ONE-SHOT averaging
    // -------------------------------
    reg [31:0] sum_intervals;
    reg [7:0]  interval_count;  // supports up to 255 intervals if needed

    always @(posedge clk_rr or posedge rst) begin
        if (rst) begin
            prev_time      <= 16'd0;
            sum_intervals  <= 32'd0;
            interval_count <= 8'd0;
            avg_interval   <= 32'd0;
            output_valid   <= 1'b0;
            // 'done' is reset in the other always block
        end else begin
            if (!done) begin
                // Default: valid low unless we just computed the average
                output_valid <= 1'b0;

                if (peak_rising_edge) begin
                    if (prev_time != 16'd0) begin
                        // One new RR interval
                        sum_intervals  <= sum_intervals + (current_time - prev_time);
                        interval_count <= interval_count + 1'b1;

                        if (interval_count + 1 == NUM_PEAKS) begin
                            // Include last interval in the average
                            avg_interval <=
                                (sum_intervals + (current_time - prev_time)) / NUM_PEAKS;

                            output_valid <= 1'b1;
                            done         <= 1'b1;  // Freeze RR logic from now on
                        end
                    end

                    // Update timestamp for next interval
                    prev_time <= current_time;
                end
            end
            // When done==1, this block holds all registers; clk_rr is also gated off.
        end
    end

endmodule





module bpm_calc #(
    parameter CLK_FREQ = 200
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] rr_cycles,
    output reg  [31:0] bpm
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bpm <= 0;
        end else if (rr_cycles != 0) begin
            // Direct calculation: BPM = 60 * CLK_FREQ / rr_cycles
            bpm <= (60 * CLK_FREQ) / rr_cycles;
        end
    end

endmodule