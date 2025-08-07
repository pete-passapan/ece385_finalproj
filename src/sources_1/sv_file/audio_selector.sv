module audio_selector(

    input  logic [15:0] switches,                  // sw 0 = mic, sw 1-15 = filters
    
    input  logic signed [15:0] mic_in,
    input  logic        mic_valid,                  //mic
    
    input  logic signed [15:0] mem_in,              //bram
    input  logic        mem_valid,
    
    input  logic signed [15:0] dout [15],  // filter outputs
    input  logic [14:0] valid_bus,       // filter valids
    output logic signed [15:0] pcm_out,
    output logic pcm_valid_out
);

    always_comb begin
        pcm_out = 16'sd0;
        pcm_valid_out = 1'b0;

        if (switches[0]) begin
            pcm_out = mic_in;
            pcm_valid_out = mic_valid;
        end else if (switches == 16'b0) begin
            pcm_out = mem_in;
            pcm_valid_out = mem_valid;
        end else 
        
        begin
            for (int i = 0; i < 15; i++) begin
                if (switches[i+1]) begin  // switches[1] corresponds to dout[0]
                    pcm_out = dout[i][15:0];
                    pcm_valid_out = valid_bus[i];
                end
            end
        end 
    end

endmodule


