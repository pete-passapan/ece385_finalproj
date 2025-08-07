`timescale 1ns / 1ps

module pcm_tb;

    // Clock and reset
    logic clk = 0;
    logic rst = 1;

    // PDM and PCM signals
    logic pdm_in;
    logic pcm_valid;
    logic signed [15:0] pcm_out, dout;

    // Clock generator (4.4 MHz)
    always #11.36 clk = ~clk;

    // Filter coefficients (Q2.14)
    logic signed [15:0] B0_0 = 16'sd246;
    logic signed [15:0] B1_0 = 16'sd0;
    logic signed [15:0] B2_0 = -16'sd246;
    logic signed [15:0] A1_0 = -16'sd32272;
    logic signed [15:0] A2_0 = 16'sd15977;

    logic signed [15:0] B0_1 = 16'sd246;
    logic signed [15:0] B1_1 = 16'sd0;
    logic signed [15:0] B2_1 = -16'sd246;
    logic signed [15:0] A1_1 = -16'sd32435;
    logic signed [15:0] A2_1 = 16'sd16095;

    // DUT: PDM to PCM
    pdm_to_pcm #(
        .DECIMATE(100)
    ) dut (
        .clk(clk),
        .rst(rst),
        .MIC_DATA(pdm_in),
        .pcm_valid(pcm_valid),
        .MIC_PCM(pcm_out)
    );

    // DUT2: Runtime-coefficient bandpass filter
    bandpass dut2 (
        .clk(pcm_valid),
        .rst(rst),
        .d_in(pcm_out),
        .d_out(dout),

        .B0_0(B0_0), .B1_0(B1_0), .B2_0(B2_0),
        .A1_0(A1_0), .A2_0(A2_0),
        .B0_1(B0_1), .B1_1(B1_1), .B2_1(B2_1),
        .A1_1(A1_1), .A2_1(A2_1)
    );

    // Sine wave input via delta-sigma
    real freq_1 = 450.0;
    real freq_2 = 1000.0;
    real freq_3 = 50.0;
    real sample_rate = 4.4e6;
    int num_samples = 200000;

    real phase1 = 0;
    real phase2 = 0;
    real phase3 = 0;

    real integ = 0;
    real target;
    real out_val = 0;

    initial begin
        $display("Start simulation...");
        #200 rst = 0;

        for (int i = 0; i < num_samples; i++) begin
            @(posedge clk);

            phase1 = 2.0 * 3.14159 * freq_1 * i / sample_rate;
            phase2 = 2.0 * 3.14159 * freq_2 * i / sample_rate;
            phase3 = 2.0 * 3.14159 * freq_3 * i / sample_rate;

            target = 0.03 * ($sin(phase1) + $sin(phase2) + $sin(phase3));

            out_val = (integ >= 0) ? 1.0 : -1.0;
            pdm_in = (out_val > 0);
            integ += target - out_val;

            if (pcm_valid)
                $display("PCM[%0d] = %0d -> Filtered = %0d", i, pcm_out, dout);
        end

        $finish;
    end

endmodule
