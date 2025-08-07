`timescale 1ns / 1ps
//fifth order CIC decimator. 


module pdm_to_pcm#(parameter DECIMATE = 100)(
        input logic clk, //PDM CLOCK 4.4 MHz
        input logic rst,
        input logic MIC_DATA, //this is a 1-bit PDM signal
        output logic signed [15:0] MIC_PCM, //  this is a 32-bit wide PCM signal 
        output logic pcm_valid //this clocks at 44 kHz
    );


    integer pdm_signed;
    always_comb
    begin
    if ((MIC_DATA == 1) || (MIC_DATA ==0)) begin
        pdm_signed = MIC_DATA ? 1 : -1; // if MIC_DATA is 1, this maps it to 01. if it's 0, this maps it to -1. 
    end else begin
        pdm_signed = -1;
    end
    end
    
    //INTEGRATOR
    logic signed [35:0] integrator[5]; //5th order CIC integrator 
    always_ff @(posedge clk) //pdm clock
    if (rst) begin
            for (int i = 0; i < 5; i++) integrator[i] <= 0;
    end else
    begin
        integrator[0] <= integrator[0] + pdm_signed;
        integrator[1] <= integrator[1] + integrator[0];
        integrator[2] <= integrator[2] + integrator[1];
        integrator[3] <= integrator[3] + integrator[2];
        integrator[4] <= integrator[4] + integrator[3];

    end
    
    //decimation of 100 to get 44 kHz (sampling rate) from 4.4 MHz
    //DECIMATION
    logic [$clog2(DECIMATE)-1:0] decim_count; // decimate 100 times means waiting for this to fill up to 100 and taking that sample. every 100th sample.
    logic signed [35:0] comb_input; // COMBING HAPPENS AFTER DECIMATION AT THE SAMPLING FREQUENCY
    logic do_comb;
    always_ff@(posedge clk)
    begin
        if (rst) begin
            decim_count <= 0;
            do_comb <= 0;
        end else begin
            if (decim_count == DECIMATE - 1)
            begin
                decim_count <= 0;//reset counter from 100 to 0
                do_comb <=1 ; //comb filter; add delayed (one clock cycle of the sampling rate) to previous This is high for only one clock cycle
                comb_input <= integrator[4]; //output of the fifth-order integrator
            end else begin
                decim_count <= decim_count + 1; //add decim_count until it gets to DECIMATE-1
                do_comb <=0; //don't comb unless you're at the sampling frequency
            
            end
        end
    end
    
    
    //fifth-ORDER COMB FILTER
    logic signed [35:0] comb[5];
    logic signed [35:0] delay[5];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 5; i++) begin
                comb[i] <= 0;
                delay[i] <= 0;
            end
        end else if (do_comb) begin // at the sampling times (indicated by the decimation counter)
            delay[0] <= comb_input; // fill the first stage with decimated value
            comb[0] <= comb_input - delay[0];
            for (int i = 1; i < 5; i++) begin
                delay[i] <= comb[i-1];
                comb[i] <= comb[i-1] - delay[i];
            end
        end
    end
   

    assign pcm_valid = do_comb;
    assign MIC_PCM = comb[4][30-:16]; //pcm outputs are just the outputs of the combs. these are 32 bits wide, and come out at the samplign frequency of 44 kHz.
//    they represent hte amplitude of some discrete-time signal 
// essentialy a left-shift, giving the signal a lot of gain.
    

    

endmodule
