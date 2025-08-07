module hilbert #(
    parameter N_TAPS = 31,
    parameter signed [15:0] COEFFS [0:N_TAPS-1] = '{
        -523, 0, -427, 0, -612, 0, -870, 0,
        -1257, 0, -1915, 0, -3372, 0, -10396, 0,
        10396, 0, 3372, 0, 1915, 0, 1257, 0,
        870, 0, 612, 0, 427, 0, 523
    }
)(
    input logic clk,//4.4 MHz
    input logic pcm_valid,
    input logic rst,
    input logic signed [15:0] din,
    output logic signed [15:0] dout,
    output logic out_valid
);

    // Internal shift register to hold samples. circular buffer of size 31
    logic signed [15:0] shift_reg [0:N_TAPS-1];

    integer i;
    logic signed [31:0] mul [N_TAPS];
    logic signed [31:0] acc;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < N_TAPS; i++) begin
                shift_reg[i] <= 16'sd0;
            end
            dout <= 32'sd0;
        end else begin
            // Shift the register
            for (i = N_TAPS-1; i > 0; i--) begin
                shift_reg[i] <= shift_reg[i-1];
            end
            shift_reg[0] <= din;

            // Multiply stage
            acc = 32'sd0;
            for (i = 0; i < N_TAPS; i++) begin
                acc += shift_reg[i] * COEFFS[i];
            end

            dout <= acc>>>14;
        end
    end

endmodule
