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

