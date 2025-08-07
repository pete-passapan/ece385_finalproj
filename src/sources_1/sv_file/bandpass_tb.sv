`timescale 1ns / 1 ps
module bandpass_tb;
  logic clk, rst;
  logic signed [15:0] r_din;
  logic signed [15:0] dout;
  // Clock generation (100 MHz)
  always #50 clk = ~clk;

   integer fid;
  integer status;
  integer sample; 
  integer i;
  integer j = 0;

  localparam num_samples = 1000;
  
  logic signed [15:0] r_wave_sample [0:num_samples - 1];

  // DUT: Your bandpass filter
  bandpass #(
    .B0_0(16'sd246), .B1_0(16'sd0), .B2_0(-16'sd246),
    .A1_0(-16'sd32272), .A2_0(16'sd15977),
    .B0_1(16'sd246), .B1_1(16'sd0), .B2_1(-16'sd246),
    .A1_1(-16'sd32435), .A2_1(16'sd16095)
  ) dut (
    .clk(clk),
    .rst(rst),
    .d_in(r_din),
    .d_out(dout)
  );

  initial
  begin
    clk = 0;
    r_din = 0;
    rst = 1;
    #200 rst=0;
    
    fid = $fopen("signed_multitone_44kHz.txt","r");
    for (i = 0; i < num_samples; i = i + 1)
        begin
          status = $fscanf(fid,"%d\n",sample); 
          r_wave_sample[i] = 16'(sample);
        end
      $fclose(fid);
      repeat(num_samples)
        begin 
          wait (clk == 0) wait (clk == 1)
          r_din = r_wave_sample[j];
          j = j + 1;
        end
      
      #50000
      $finish;
  end  

endmodule