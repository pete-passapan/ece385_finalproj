`timescale 1ns / 1ps

module filter_bank_tb;

    logic clk = 0;
    logic rst = 1;

    logic pdm_in;
    logic pcm_valid, valid_out,pcm_valid_sync, valid_mem, envelope_valid_out;
    logic signed [15:0] pcm_out, pcm_data_sync, mem_out;
    logic signed [15:0] d_out [15];  //filterbank output
    logic signed [15:0] envelope_out [15];  // envelope output
    logic signed [15:0] carrier_bands [15]; //memory output
    logic [14:0] valid_bus, valid_carriers, envelope_valid_bus;
    logic signed [15:0] mixed_out;
    logic mixed_valid;
    

    // 4.4 MHz
    always #11.36 clk = ~clk;

    pdm_to_pcm #(.DECIMATE(100)) dut_pcm (
        .clk(clk),
        .rst(rst),
        .MIC_DATA(pdm_in),
        .pcm_valid(pcm_valid),
        .MIC_PCM(pcm_out)
    );
        
    pcm_sync pcm_sync_inst (
        .clk_fast(clk),         
        .rst(rst),                     
    
        .pcm_valid_in(pcm_valid),       
        .pcm_data_in(pcm_out),          
    
        .pcm_valid_out(pcm_valid_sync), 
        .pcm_data_out(pcm_data_sync)    
    );

//    carrier_rom_bank carrier_rom  (
//        .clk(clk),
//        .rst(rst),
//        .enable_44k(pcm_valid_sync),
//        .carrier_bands(carrier_bands),
//        .valid_bus(valid_carriers)
//    );

//    // DUT 2: Mel Filterbank
//    mel_filterbank dut_fbank (
        
//        .clk(clk),
//        .pcm_valid(pcm_valid_sync),
//        .rst(rst),
//        .d_in(pcm_data_sync),
//        .d_out(d_out),
//        .valid_out(valid_out),
//        .valid_bus(valid_bus)
//    );
    
//    envelope_bank ebank (
        
//        .clk(clk),
//        .pcm_valid(pcm_valid_sync),
//        .rst(rst),
//        .d_in(pcm_data_sync),
//        .d_out(envelope_out),
//        .valid_out(envelope_valid_out),
//        .valid_bus(envelope_valid_bus)
//    );
    
//    envelope_carrier_mixer_fsm mixer (
//        .clk(clk),
//        .rst(rst),
    
//        .envelope_in(envelope_out),
//        .carrier_in(carrier_bands),
//        .envelope_valid(envelope_valid_out),
//        .carrier_valid(|valid_carriers),
    
//        .mixed_out(mixed_out),
//        .mixed_valid(mixed_valid)
//    );
    
    logic hilbert_valid;
    logic signed [15:0] hilbert_out;
    
    fir_filter hilbert_inst (
        .clk        (clk),
        .rst        (rst),
        .pcm_in     (pcm_data_sync),
        .valid_in   (pcm_valid_sync),
        .pcm_out    (hilbert_out),
        .valid_out  (hilbert_valid)
    );
    
    logic delay_valid;
    logic signed [15:0] delay_out;
    
    delay_line delay_inst (
        .clk(clk),
        .rst(rst),
        .din(pcm_data_sync),
        .valid_in(pcm_valid_sync),
        .dout(delay_out),
        .valid_out(delay_valid)
    );

    
//    mem_playback dut_mem (
//        .clk(clk),
//        .rst(rst),
//        .enable(pcm_valid_sync),
//        .data_out(mem_out),
//        .valid_out(valid_mem)
//    );

    logic hilb_env_valid;
    logic signed [15:0] hilb_env_out;

    hilbert_top hilbert_fsm (
    .clk(clk),
    .rst(rst),

    .real_in(delay_out),
    .hilbert_in(hilbert_out),
    .real_valid(delay_valid),
    .hilbert_valid(hilbert_valid),

    .envelope_out(hilb_env_out),
    .envelope_valid(hilb_env_valid)
);

    
    function [15:0] abs(input [15:0] x);
      abs = x[15] ? -x : x;
    endfunction
    
    logic signed [15:0] rectified;
    assign rectified = abs(pcm_data_sync);
    
    

    real sample_rate = 4.4e6;
    int num_samples = 500000;

    real integ = 0;
    real target;
    real out_val = 0;
    //band centers computed by matlab
    real band_centers [15] = '{
    59.19,
    82.99,
    116.30,
    163.59,
    229.25,
    321.16,
    451.41,
    632.05,
    889.87,
    1247.67,
    1744.56,
    2452.54,
    3439.13,
    4823.61,
    6752.77
};


    real phase [15];
    
    real freq;
    real phase_t;

    initial begin;
        #200 rst = 0;

        for (int i = 0; i < num_samples; i++) begin
            @(posedge clk);

            // Sum of sinusoids at band centers
            target = 0.0;
            for (int j = 0; j < 15; j++) begin
                phase[j] = 2.0 * 3.14159 * band_centers[j] * i / sample_rate;
                target += (0.004)*$sin(phase[j]);
            end
//            freq = 7000.0;
//            phase_t = 2.0 * 3.14159 * freq *i / sample_rate;
        
            
//            target += (0.07)*$sin(phase_t);


            // delta-sigma modulator 
            out_val = (integ >= 0) ? 1.0 : -1.0; //comparator out
            pdm_in = (out_val > 0); // dac
            integ += target - out_val; //difference amplifier

        end

        $finish;
    end

endmodule
