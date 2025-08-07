//cascade the biquads. out of the first goes into the in of the other, along with their corresponding valid_out

module bandpass (
    input  logic clk,
    input  logic rst,
    input  logic signed [15:0] d_in,
    input  logic pcm_valid,   // this comes from pdm_to_pcm

    // SOS 1 Coefficients
    input  logic signed [15:0] B0_0, B1_0, B2_0,
    input  logic signed [15:0] A1_0, A2_0,

    // SOS 2 Coefficients
    input  logic signed [15:0] B0_1, B1_1, B2_1,
    input  logic signed [15:0] A1_1, A2_1,

    output logic signed [15:0] d_out,
    output logic valid_out    
);

    logic signed [15:0] out1;
    logic valid1;

    // First SOS
    biquad_filter SOS1 (
        .clk(clk),
        .rst(rst),
        .d_in(d_in),
        .pcm_valid(pcm_valid),
        .d_out(out1),
        .valid_out(valid1),
        .B0(B0_0), .B1(B1_0), .B2(B2_0),
        .A1(A1_0), .A2(A2_0)
    );

    // Second SOS
    biquad_filter SOS2 (
        .clk(clk),
        .rst(rst),
        .d_in(out1),
        .pcm_valid(valid1),      
        .d_out(d_out),
        .valid_out(valid_out),   
        .B0(B0_1), .B1(B1_1), .B2(B2_1),
        .A1(A1_1), .A2(A2_1)
    );

endmodule
