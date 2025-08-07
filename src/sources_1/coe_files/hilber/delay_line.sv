//Delays an input signal by a DEPTH number of samples

module delay_line #(
    parameter integer DEPTH = 31  // (63-1)/2
)(
    input  logic                         clk,
    input  logic                         rst,
    input  logic signed [15:0] din,
    input  logic                         valid_in,
    output logic signed [15:0] dout,
    output logic                         valid_out
);

    //makes a 31 long shift-register; take the last sample as the output to delay
    logic signed [15:0] shift_reg [0:DEPTH-1];
    logic valid_reg [0:DEPTH-1];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < DEPTH; i++) begin
                shift_reg[i] <= '0;
                valid_reg[i] <= 0;
            end
        end else begin
            shift_reg[0] <= din;
            valid_reg[0] <= valid_in;
            for (int i = 1; i < DEPTH; i++) begin
                shift_reg[i] <= shift_reg[i-1];
                valid_reg[i] <= valid_reg[i-1];
            end
        end
    end

    assign dout = shift_reg[DEPTH-1];
    assign valid_out = valid_reg[DEPTH-1];

endmodule
