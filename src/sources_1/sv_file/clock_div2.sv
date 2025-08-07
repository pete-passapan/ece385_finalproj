module clock_div2 (
    input  logic clk_in,    // 8.8 MHz
    input  logic rst,
    output logic clk_out    // 4.4 MHz 
);

    always_ff @(posedge clk_in or posedge rst) begin
        if (rst)
            clk_out <= 1'b0;
        else
            clk_out <= ~clk_out; // new edge only on rising edges of the original
    end

endmodule
