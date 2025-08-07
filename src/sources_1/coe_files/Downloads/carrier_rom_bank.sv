
`timescale 1ns / 1ps

module carrier_rom_bank #(
    parameter MEM_DEPTH = 4036,
    parameter ADDR_WIDTH = $clog2(MEM_DEPTH)
)(
    input  logic clk,
    input  logic rst,
    input  logic enable_44k,  

    output logic signed [15:0] carrier_bands [15],
    output logic [14:0] valid_bus    
);

    logic signed [15:0] band_data [15];
    logic [14:0] valid_signals ;

    band1_playback  #(.MEM_DEPTH(MEM_DEPTH)) b1  (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[0]),  .valid_out(valid_signals[0]));
    band2_playback  #(.MEM_DEPTH(MEM_DEPTH)) b2  (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[1]),  .valid_out(valid_signals[1]));
    band3_playback  #(.MEM_DEPTH(MEM_DEPTH)) b3  (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[2]),  .valid_out(valid_signals[2]));
    band4_playback  #(.MEM_DEPTH(MEM_DEPTH)) b4  (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[3]),  .valid_out(valid_signals[3]));
    band5_playback  #(.MEM_DEPTH(MEM_DEPTH)) b5  (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[4]),  .valid_out(valid_signals[4]));
    band6_playback  #(.MEM_DEPTH(MEM_DEPTH)) b6  (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[5]),  .valid_out(valid_signals[5]));
    band7_playback  #(.MEM_DEPTH(MEM_DEPTH)) b7  (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[6]),  .valid_out(valid_signals[6]));
    band8_playback  #(.MEM_DEPTH(MEM_DEPTH)) b8  (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[7]),  .valid_out(valid_signals[7]));
    band9_playback  #(.MEM_DEPTH(MEM_DEPTH)) b9  (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[8]),  .valid_out(valid_signals[8]));
    band10_playback #(.MEM_DEPTH(MEM_DEPTH)) b10 (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[9]),  .valid_out(valid_signals[9]));
    band11_playback #(.MEM_DEPTH(MEM_DEPTH)) b11 (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[10]), .valid_out(valid_signals[10]));
    band12_playback #(.MEM_DEPTH(MEM_DEPTH)) b12 (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[11]), .valid_out(valid_signals[11]));
    band13_playback #(.MEM_DEPTH(MEM_DEPTH)) b13 (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[12]), .valid_out(valid_signals[12]));
    band14_playback #(.MEM_DEPTH(MEM_DEPTH)) b14 (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[13]), .valid_out(valid_signals[13]));
    band15_playback #(.MEM_DEPTH(MEM_DEPTH)) b15 (.clk(clk), .rst(rst), .enable(enable_44k), .data_out(band_data[14]), .valid_out(valid_signals[14]));

    always_comb begin
        for (int i = 0; i < 15; i++)
            carrier_bands[i] = band_data[i];
    end

    assign valid_bus = valid_signals;

endmodule
