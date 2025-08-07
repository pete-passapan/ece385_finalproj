`timescale 1ns / 1ps


//mic input to 15 different bandpass filters on mel cepstrump 50 Hz to 8 kHz
module mel_filterbank (
    input  logic clk,
    input  logic rst,
    input  logic pcm_valid,               
    input  logic signed [15:0] d_in,       
    output logic signed [15:0] d_out [15], 
    output logic [14:0] valid_bus,
    output logic valid_out                 
);

    localparam int COEFFS_PER_LINE = 5;
    localparam int COEFFS_PER_FILTER = 10;
    localparam int NUM_LINES = 30;
    localparam int NUM_FILTERS = 15;

    logic signed [15:0] coeff_mem [0:NUM_LINES-1][0:COEFFS_PER_LINE-1];

    initial begin
        $readmemb("sos_coeffs.mem", coeff_mem);
    end


    generate
        for (genvar i = 0; i < NUM_FILTERS; i++) begin : filter_bank
            bandpass filter_inst (
                .clk(clk),
                .rst(rst),
                .pcm_valid(pcm_valid),         
                .d_in(d_in),
                .d_out(d_out[i]),
                .valid_out(valid_bus[i]),       // Each filter produces its own valid_out

                // SOS 1 Coeffs
                .B0_0(coeff_mem[i*2 + 0][0]),
                .B1_0(coeff_mem[i*2 + 0][1]),
                .B2_0(coeff_mem[i*2 + 0][2]),
                .A1_0(coeff_mem[i*2 + 0][3]),
                .A2_0(coeff_mem[i*2 + 0][4]),

                // SOS 2 Coeffs
                .B0_1(coeff_mem[i*2 + 1][0]),
                .B1_1(coeff_mem[i*2 + 1][1]),
                .B2_1(coeff_mem[i*2 + 1][2]),
                .A1_1(coeff_mem[i*2 + 1][3]),
                .A2_1(coeff_mem[i*2 + 1][4])
            );
        end
    endgenerate

    assign valid_out = |valid_bus; //means any bit on the bus will raise this signal.

endmodule

