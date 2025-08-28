
module peak_detector
 (
    input clk,
    input rst,
    input signed [12:0] transformed_signal,
    output reg peak_detected
);
    reg signed [12:0] signal_buffer [0:255];
    reg [7:0] index;
    integer j;

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
        end else
            signal_buffer[index] <= transformed_signal;
    end

    // Max value tracking
    reg signed [12:0] max_value, temp_max_value;
    always @(posedge clk or posedge rst) begin
        if (rst)
            max_value <= 13'd0;
        else begin
            temp_max_value = 13'd0;
            for (j = 0; j < 256; j = j + 1)
                if (signal_buffer[j] > temp_max_value)
                    temp_max_value = signal_buffer[j];
            max_value <= temp_max_value;
        end
    end

    // Dynamic threshold
    reg signed [12:0] threshold;
    always @(posedge clk or posedge rst) begin
        if (rst)
            threshold <= 13'd0;
        else
            threshold <= (max_value >> 1) + 13'd50;
    end

    // Peak detection
    always @(posedge clk or posedge rst) begin
        if (rst)
            peak_detected <= 1'b0;
        else
            peak_detected <= (transformed_signal > threshold);
    end
endmodule


