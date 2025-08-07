`timescale 1ns / 1ps

//literally 15 of the same lpf

module envelope_bank (
    input  logic clk,
    input  logic rst,
    input  logic pcm_valid,               
    input  logic signed [15:0] d_in [15],       //from filterbank
    output logic signed [15:0] d_out [15], 
    output logic [14:0] valid_bus,
    output logic valid_out                 
);

    localparam int COEFFS_PER_LINE = 5;
    localparam int COEFFS_PER_FILTER = 5;
    localparam int NUM_LINES = 1;
    localparam int NUM_FILTERS = 15;

    logic signed [15:0] coeff_mem [0:COEFFS_PER_LINE-1];

    initial begin
        $readmemb("lpf_coeffs.mem", coeff_mem);
    end


    function [15:0] abs(input [15:0] x);
      abs = x[15] ? -x : x;
    endfunction
    
    generate
        for (genvar i = 0; i < NUM_FILTERS; i++) begin : filter_bank
            biquad_filter lpf ( //second order lpf used to generate the envelope of a rectified bandpassed mic input
                .clk(clk),
                .rst(rst),
                .d_in(abs(d_in[i])),
                .pcm_valid(pcm_valid),
                .d_out(d_out[i]),
                .valid_out(valid_bus[i]),
                .B0(coeff_mem[0]),
                .B1(coeff_mem[1]),
                .B2(coeff_mem[2]),
                .A1(coeff_mem[3]),
                .A2(coeff_mem[4])
            );
        end
    endgenerate

    assign valid_out = |valid_bus; //assume that one of the filter valid_out represents all of them ( no skew)

endmodule

