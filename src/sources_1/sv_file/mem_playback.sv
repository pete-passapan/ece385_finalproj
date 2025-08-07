module mem_playback #(
    parameter MEM_DEPTH = 44000,
    parameter ADDR_WIDTH = $clog2(MEM_DEPTH) 
)(
    input  logic clk,             // 4.4 MHz
    input  logic rst,             
    input  logic enable,          // 44 khz
    output logic signed [15:0] data_out,
    output logic valid_out
);

    logic [ADDR_WIDTH-1:0] addr;
    logic [15:0] bram_dout;

    wav_bram wav_mem (
        .clka(clk),
        .addra(addr),
        .douta(bram_dout)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            addr <= 0;
            data_out <= 16'sd0;
            valid_out <= 0;
        end else begin
            valid_out <= 0;
            if (enable) begin
                data_out <= signed'(bram_dout);  
                valid_out <= 1;

                if (addr == MEM_DEPTH - 1)
                    addr <= 0;
                else
                    addr <= addr + 1;
            end
        end
    end

endmodule


