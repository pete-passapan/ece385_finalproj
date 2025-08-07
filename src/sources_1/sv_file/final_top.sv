`timescale 1ns / 1ps
//DEFINITIONS:
//MIC_CLK is 4.4 MHz and is used as the fast clock and used to drive the microphone. Higher clock speeds make us fail timing.
//SPKL, SPKR, MIC_CLK, MIC_DATA are all physical pins for the mic. 
//output PWM to SPKL, SPKR 
//drive 4.4 MHz to MIC_CLK
//get 4.4 MHz pdm data in response from MIC_DATA

//pdm_to_pcm
//fifth order CIC decimator, results in MIC_PCM (16-bit pcm data) and pcm_valid (44 kHz pulse when pcm data available)
// there's even some more gain after bit growth since pdm data is mostly noise power in high frequencies

//pcm_sync. I saw that you had to be careful crossing clock domains (pcm data out at 44 kHz, filters at 4.4 MHz). 
//this module just synchronizes the mic_pcm to some rising edge of the fast clock.

//filter_bank. takes in logic signed [15:0] pcm_data_sync from microphone and outputs packed array 
//logic signed [15:0] dout [15]

//makes use of bandpass which just connects two biquad filters together.
//biquad filters: uses direct form 1 equation, but splits the multiply-accumulate into steps using an FSM to reduce DSP
//usage. turns out to be around 13 clock cycles between input and valid output.


//carrier_rom_bank. i just loaded in 15 filtered snippets using the same filterbank on matlab into these brams.
//they take 2 brams each. [15:0] carrier_out [15] comes out.

//source of improvement: just share the same mel-filterbank as the microphone. requires multiplexing in time (easy)
//and loading in the states of the biquads when switching inputs (annoying). but we would save a lot of memory and get
//much cleaner audio since there's no pulses on the snippets being repeated.

//envelope_bank: [15:0] filtered_mic [15] goes in [15:0] envelope_out [15] comes out. This instantiates literally 15
//of the same lowpass filter. could also be improved by multiplexing but there's gonna be a lot of delay (13*i samples)
//for each channel and this actually matters. 

//env_carrier_mixer_fsm. [15:0] envelope_out [15]  and [15:0] carrier_out [15] come in, [15:0] mixed_out comes out.

//[15:0] mixed_out gets converted to pwm signal, but we only take 12 bits of it because that's what our clock allows. 
//pwm signal to SPKL and SPKR.


module final_top(
        input logic Clk, //100 MHz
        input logic reset_rtl_0,
        input logic MIC_DATA, //pdm data from the mic
        input logic [15:0] SW, //switches
        
     
        
        output logic SPKL,
        output logic SPKR,
        output logic MIC_CLK //drive mic with 4.4 MHz
    );

    logic clk_8_8MHz;
    
    clock_div2 clk_div_inst (
        .clk_in(clk_8_8MHz),
        .rst(reset_rtl_0),
        .clk_out(MIC_CLK)
    );

        
    logic clk_400MHz;
    clk_wiz_0 clk_wiz (
        .clk_in1(Clk),
        .clk_out1(clk_8_8MHz),
        .clk_out2(clk_400MHz),
        .reset(reset_rtl_0),
        .locked()
    );
    logic signed[15:0] MIC_PCM, sum_out, pcm_data_sync, mem_out;

    
    
    logic pcm_valid, valid_out,pcm_valid_sync, valid_mem, envelope_valid_out;

    logic pwm_out;
    logic signed [15:0] dout [15]; //filterbank output
    logic signed [15:0] envelope_out [15];  // envelope output

    logic signed [15:0] carrier_bands [15]; //memory output

    logic [14:0] valid_bus, valid_carriers, envelope_valid_bus;
    logic signed [15:0] mixed_out; //after mixer
    logic mixed_valid;
    
    
    logic signed [15:0] noise_gate_out;
    logic noise_gate_valid;
    pdm_to_pcm #(
        .DECIMATE(100)
        
        )pcm_converter(
        .clk(MIC_CLK),
        .rst(reset_rtl_0),
        .MIC_DATA(MIC_DATA),
        .MIC_PCM(MIC_PCM),
        .pcm_valid(pcm_valid)    
    );
    
    pcm_sync pcm_sync_inst (
        .clk_fast(MIC_CLK),         
        .rst(reset_rtl_0),                     
    
        .pcm_valid_in(pcm_valid),       
        .pcm_data_in(MIC_PCM),          
    
        .pcm_valid_out(pcm_valid_sync), 
        .pcm_data_out(pcm_data_sync)    
    );
    
    mel_filterbank filterbank(
        .pcm_valid(pcm_valid_sync),
        .clk(MIC_CLK),
        .rst(reset_rtl_0),
        .d_in(pcm_data_sync),
        .d_out(dout),
        .valid_out(valid_out),
        .valid_bus(valid_bus)
    );
    
        
    logic pcm_valid_out;
    logic signed [15:0] pcm_in;

//    mem_playback mem_playback_inst (
//            .clk(MIC_CLK),
//            .rst(reset_rtl_0),
//            .enable(pcm_valid_sync),
//            .data_out(mem_out),
//            .valid_out(valid_mem)
//        );
        
//    audio_selector selector_inst (
//        .switches(SW),
        
//        .mic_in(MIC_PCM), //from mic
//        .mic_valid(pcm_valid),
        
//        .mem_in(mem_out), //from memory playback
//        .mem_valid(valid_mem),
        
//        .dout(carrier_bands),
//        .valid_bus(valid_carriers),
        
//        .pcm_out(pcm_in),
//        .pcm_valid_out(pcm_valid_out)
//    );

    
    carrier_rom_bank carrier_rom  (
        .clk(MIC_CLK),
        .rst(reset_rtl_0),
        .enable_44k(pcm_valid_sync),
        .carrier_bands(carrier_bands),
        .valid_bus(valid_carriers)
    );
    
    
    envelope_bank ebank (
        
        .clk(MIC_CLK),
        .pcm_valid(valid_out),
        .rst(reset_rtl_0),
        .d_in(dout),
        .d_out(envelope_out),
        .valid_out(envelope_valid_out),
        .valid_bus(envelope_valid_bus)
    );
    
    envelope_carrier_mixer_fsm mixer (
        .clk(MIC_CLK),
        .rst(reset_rtl_0),
    
        .envelope_in(envelope_out),
        .carrier_in(carrier_bands),
        .envelope_valid(envelope_valid_out),
        .carrier_valid(|valid_carriers),
    
        .mixed_out(mixed_out),
        .mixed_valid(mixed_valid)
    );
    
    
    noise_gate ng(
    .clk(MIC_CLK),
    .rst(reset_rtl_0),
    .in(pcm_data_sync),
    .in_valid(pcm_valid_sync),

    .out(noise_gate_out),
    .out_valid(noise_gate_valid)
);

    logic valid_pcm;
    
    pcm_to_pwm pwm_converter (
        .clk(clk_400MHz), 
        .rst(reset_rtl_0),
        .pcm_in(pcm_in),
        .pcm_valid(valid_pcm),
        .pwm_out(pwm_out)
       
    );
    always_comb begin
        if(SW[0]==1)begin
            pcm_in = pcm_data_sync;
            valid_pcm = pcm_valid_sync;
            
        end else if(SW[1]==1)begin
            pcm_in = mixed_out[15:0];
            valid_pcm = mixed_valid;
        end else if (SW[2]==1) begin
            pcm_in = dout[6][15:0];
            valid_pcm = valid_bus[6];
        end else
        
        begin
            pcm_in = 0;
            valid_pcm = pcm_valid_sync;
        end
    end
    
    

//    pcm_to_pwm pwm_converter (
//        .clk(clk_400MHz),
//        .rst(reset_rtl_0),
//        .pcm_in(mem_out),
//        .pcm_valid(valid_mem),
//        .pwm_out(pwm_out)
       
//    );



    

    assign SPKL = pwm_out;
    assign SPKR = pwm_out;
    
    
    
    
endmodule
