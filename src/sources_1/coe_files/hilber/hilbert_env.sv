module hilbert_env #(
    parameter integer TAP_NUM = 31,
    parameter integer DATA_WIDTH = 16
) (
    input logic clk,
    input logic rst,
    input logic valid,
    input logic signed [DATA_WIDTH-1:0] din,
    output logic signed [DATA_WIDTH+1:0] envelope_out
);

    logic signed [DATA_WIDTH-1:0] hilbert_coeffs [0:TAP_NUM-1];
    
    initial
    begin
        $readmemh("hilbert_taps.mem",hilbert_coeffs);
    end
    
    logic signed [DATA_WIDTH-1:0] shift_reg [0:TAP_NUM-1];
    logic signed [2*DATA_WIDTH-1:0] acc;
    logic signed [DATA_WIDTH-1:0] imag_part;
    logic signed [DATA_WIDTH-1:0] real_part;

    // Shift Register
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < TAP_NUM; i++)
                shift_reg[i] <= '0;
        end else begin
            shift_reg[0] <= din;
            for (int i = 1; i < TAP_NUM; i++)
                shift_reg[i] <= shift_reg[i-1];
        end
    end

    // Hilbert FIR filtering (imaginary part)
    always_comb begin
        acc = 0;
        for (int i = 0; i < TAP_NUM; i++) begin
            acc += shift_reg[i] * hilbert_coeffs[i];
        end
        imag_part = acc >>> 15; // Adjust shift to match scaling
    end

    // Real part is just delayed version of input (center tap)
    assign real_part = shift_reg[(TAP_NUM-1)/2];

    // Envelope approx: |real| + |imag|
    wire signed [DATA_WIDTH-1:0] abs_real = (real_part < 0) ? -real_part : real_part;
    wire signed [DATA_WIDTH-1:0] abs_imag = (imag_part < 0) ? -imag_part : imag_part;

    always_ff @(posedge clk) begin
        if (rst) begin
            envelope_out <= '0;
        end else begin
            envelope_out <= abs_real + abs_imag;
        end
    end

endmodule
