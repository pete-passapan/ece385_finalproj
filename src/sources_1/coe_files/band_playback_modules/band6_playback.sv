
module band6_playback #( 
    parameter MEM_DEPTH = 4036, 
    parameter ADDR_WIDTH = $clog2(MEM_DEPTH)
)(
    input  logic clk,             // 4.4 MHz
    input  logic rst,             // Reset
    input  logic enable,          // 44 kHz enable strobe
    output logic signed [15:0] data_out,
    output logic valid_out
);

    logic [ADDR_WIDTH-1:0] addr;
    logic [15:0] bram_dout;

    band6 mem_band_6( 
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
                data_out <= signed'(bram_dout);  // Cast as signed
                valid_out <= 1;

                if (addr == MEM_DEPTH - 1)
                    addr <= 0;
                else
                    addr <= addr + 1;
            end
        end
    end

endmodule
