//suggested when crossing clock domains from 44 kHz to 4.4 MHz. it's probably not necessary since the CIC decimator
//also runs on the same fast clock.

module pcm_sync (
    input  logic clk_fast,        // 4.4 MHz clock
    input  logic rst,

    input  logic pcm_valid_in,    
    input  logic signed [15:0] pcm_data_in, // MIC_PCM

    output logic pcm_valid_out,   
    output logic signed [15:0] pcm_data_out 
);

    logic pcm_valid_sync_0, pcm_valid_sync_1;
    logic pcm_valid_rising_edge;

    always_ff @(posedge clk_fast or posedge rst) begin
        if (rst) begin
            pcm_valid_sync_0 <= 0;
            pcm_valid_sync_1 <= 0;
        end else begin
        //double flop
            pcm_valid_sync_0 <= pcm_valid_in;
            pcm_valid_sync_1 <= pcm_valid_sync_0;
        end
    end

    //detects a rising edge (prev. value 0 and current value 1)
    assign pcm_valid_rising_edge = pcm_valid_sync_0 & ~pcm_valid_sync_1;

    logic signed [15:0] pcm_data_buffer;

    //sample the pcm data on the synchronized valid signal
    always_ff @(posedge clk_fast or posedge rst) begin
        if (rst)
            pcm_data_buffer <= 0;
        else if (pcm_valid_rising_edge)
            pcm_data_buffer <= pcm_data_in;
    end
    
    //output. both are synchronized to the fast clock.
    assign pcm_valid_out = pcm_valid_rising_edge;
    assign pcm_data_out = pcm_data_buffer;

endmodule
