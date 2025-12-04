`timescale 1us/1ps
module HR_Estimator_tb;
    parameter CLK_FREQ = 200;
    reg clk;
    reg rst;
    reg signed [7:0] Xin;
    wire [31:0] bpm;  
    HR_estimator #(CLK_FREQ) dut (
        .clk(clk),
        .rst(rst),
        .Xin(Xin),
        .bpm(bpm)
    );

    initial clk = 0;
    always #0.005 clk = ~clk;  
    initial begin
        rst = 1;
        #10000;  
        rst = 0;
    end

    integer file;
    integer scan_result;
    integer ecg_value;
    initial begin
        file = $fopen("ecg_scaled_72.txt", "r");
        if (file == 0) begin
            $display("Error: Could not open ECG file.");
            $finish;
        end
        Xin = 0;
        #5000;  
        while (!$feof(file)) begin
            scan_result = $fscanf(file, "%d\n", ecg_value); 
            if (scan_result != 1) begin
                $display("Error: Failed to read ECG value from file.");
                $finish;
            end
            Xin = ecg_value[7:0]; 
            #5000;
        end
        $fclose(file);
        #100000000000000;
        $finish;
    end

    initial begin
    $dumpfile("hr.vcd");
    $dumpvars(0, HR_Estimator_tb);
        $monitor("Time: %0t | Xin: %d | bpm: %d", 
                 $time, Xin, bpm);
    end

endmodule