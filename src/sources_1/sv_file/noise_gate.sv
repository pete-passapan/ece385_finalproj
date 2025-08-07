//just detects if the mic input is greater than a threshold, otherwise it's 0.

module noise_gate #(
    parameter WIDTH = 16,
    parameter THRESH = 16'sd5000  // volume threshold
)(
    input  logic clk,
    input  logic rst,
    input  logic signed [WIDTH-1:0] in,
    input  logic in_valid,

    output logic signed [WIDTH-1:0] out,
    output logic out_valid
);

    logic signed [WIDTH-1:0] abs_val;
    logic signed [WIDTH-1:0] smoothed;
    logic signed [WIDTH-1:0] prev;

    assign abs_val = in[WIDTH-1] ? -in : in;

    //iir lpf on rectified 
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            smoothed <= 0;
            prev <= 0;
        end else if (in_valid) begin
            smoothed <= (prev >> 2) + (abs_val >> 2) + (smoothed >> 1); 
            prev <= abs_val;
        end
    end

    // binary output saying if input level reaches threshold
    always_ff @(posedge clk) begin
        if (in_valid) begin
            if (smoothed > THRESH) begin
                out <= 16'sd1;
                out_valid <= 1;
            end else begin
                out <= 16'sd0;
                out_valid <= 1;
            end
        end else begin
            out_valid <= 0;
        end
    end

endmodule
