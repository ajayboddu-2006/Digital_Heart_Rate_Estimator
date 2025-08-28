// ---------- Stage 3: RR Interval Calculator (Final after NUM_PEAKS) ----------
module RR_Interval_Calc #(
    parameter NUM_PEAKS = 5   // number of intervals to average
)(
    input  clk,
    input  rst,
    input  peak_detected, 
    output reg [31:0] avg_interval, // final average interval
    output reg        output_valid  // goes high once final result ready
);

    // Internal registers
    reg [15:0] current_time;
    reg [15:0] prev_time; 
    reg [31:0] sum_intervals;
    reg [3:0]  interval_count;
    reg prev_peak_detected;

    wire peak_rising_edge;
    assign peak_rising_edge = peak_detected && !prev_peak_detected;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_time      <= 16'd0;
            prev_time         <= 16'd0;
            sum_intervals     <= 32'd0;
            interval_count    <= 4'd0;
            avg_interval      <= 32'd0;
            output_valid      <= 1'b0;
            prev_peak_detected<= 1'b0;
        end 
        else begin
            // Always increment time
            current_time <= current_time + 1;

            // Edge detector
            prev_peak_detected <= peak_detected;

            if (peak_rising_edge) begin
                if (prev_time != 16'd0) begin
                    // Compute this interval
                    sum_intervals  <= sum_intervals + (current_time - prev_time);

                    // Check BEFORE incrementing → ensures exactly NUM_PEAKS
                    if (interval_count + 1 == NUM_PEAKS) begin
                        avg_interval <= (sum_intervals + (current_time - prev_time)) / NUM_PEAKS;
                        output_valid <= 1'b1;  // final result ready
                    end

                    interval_count <= interval_count + 1;
                end

                // Update reference time
                prev_time <= current_time;
            end
        end
    end
endmodule


