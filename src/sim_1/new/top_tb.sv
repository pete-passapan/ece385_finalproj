module top_tb;
timeunit 10ns;
timeprecision 1ns;
    // Clock and reset
    logic clk = 0;
    logic rst = 1;

    // PDM and PCM signals
    logic pdm_in;
    logic pcm_valid;
    logic signed [31:0] pcm_out;
    logic SPKL;
    logic SPKR;
    logic MIC_CLK;
    logic MIC_DATA;
    logic clk_100MHz;
    

    // Instantiate DUT

     final_top final_tb(
        .Clk(clk),
        .reset_rtl_0(rst),
        .SPKL(SPKL),
        .SPKR(SPKR),
        .MIC_CLK(MIC_CLK),
        .MIC_DATA(MIC_DATA)
    );
    assign MIC_DATA = pdm_in;

    // Clock generator (4.4 MHz)
    always begin: CLOCK_GENERATION
        #1 clk = ~clk;
    end
    // Sine wave source
    real freq_hz = 1000.0;     // 1 kHz sine wave
    real sample_rate = 4.4e6;  // PDM rate
    int num_samples = 20000;

    // Delta-Sigma Modulator
    real phase = 0;
    real integ = 0;
    real target;
    real out_val = 0;

    initial begin
        $display("Start simulation...");
        #200 rst = 0;  // Release reset after a few cycles

        for (int i = 0; i < num_samples; i++) begin
            @(posedge clk);

            // Generate target analog sine value between -1 and 1
            phase = 2.0 * 3.14159 * freq_hz * i / sample_rate;
            target = $sin(phase);//sine values that exist at the 4.4 MHz

            // Delta-sigma modulator (1st order)
            out_val = (integ >= 0) ? 1.0 : -1.0; //at the same time, 
            pdm_in = (out_val > 0);  // Convert to 1-bit logic

            integ += target - out_val;
        end

        $finish;
    end

endmodule
