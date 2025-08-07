`timescale 1ns / 1ps

//matlab will give you a0 but it's always 1. so a0 is not included.

//follows direct form 1:
// y[n] = B0*x[n] + B1*x[n-1] + B2*x[n-2] - A1*y[n-1] - A2*y[n-2]

module biquad_filter(
    input  logic clk,
    input  logic rst,
    input  logic signed [15:0] d_in,
    input  logic pcm_valid,               

    input  logic signed [15:0] B0, B1, B2,
    input  logic signed [15:0] A1, A2,

    output logic signed [15:0] d_out,
    output logic valid_out
);

    //states. MAC when a new sample comes in and then waits for the next. splits MAC to save DSP cores
    typedef enum logic [3:0] {
        WAITING,
        M0, ADD0,
        M1, ADD1,
        M2, ADD2,
        M3, SUB1,
        M4, SUB2,
        SHIFT_STAGE,
        SATURATE,
        OUTPUT
    } state_t;

    state_t state;

    logic signed [31:0] x0, x1, x2;
    logic signed [31:0] y1, y2;

    logic signed [31:0] mul;
    logic signed [31:0] acc;
    logic signed [31:0] shifted;
    logic signed [15:0] saturated;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= WAITING;

            x0 <= 0; x1 <= 0; x2 <= 0;
            y1 <= 0; y2 <= 0;

            mul <= 0;
            acc <= 0;
            shifted <= 0;
            saturated <= 0;

            d_out <= 0;
            valid_out <= 0;
        end else begin
            case (state)

                WAITING: begin
                    valid_out <= 0;
                    if (pcm_valid) begin
                        // Capture inputs
                        x2 <= x1;
                        x1 <= x0;
                        x0 <= d_in;

                        y2 <= y1;
                        y1 <= d_out;

                        state <= M0;
                    end
                end

                // B0 * x0
                M0: begin
                    mul <= B0 * x0;
                    state <= ADD0;
                end

                // acc = mul
                ADD0: begin
                    acc <= mul;
                    state <= M1;
                end

                // B1 * x1
                M1: begin
                    mul <= B1 * x1;
                    state <= ADD1;
                end

                // acc += mul
                ADD1: begin
                    acc <= acc + mul;
                    state <= M2;
                end

                // B2 * x2
                M2: begin
                    mul <= B2 * x2;
                    state <= ADD2;
                end

                // acc += mul
                ADD2: begin
                    acc <= acc + mul;
                    state <= M3;
                end

                // A1 * y1
                M3: begin
                    mul <= A1 * y1;
                    state <= SUB1;
                end

                // acc -= mul
                SUB1: begin
                    acc <= acc - mul;
                    state <= M4;
                end

                // A2 * y2
                M4: begin
                    mul <= A2 * y2;
                    state <= SUB2;
                end

                // acc -= mul
                SUB2: begin
                    acc <= acc - mul;
                    state <= SHIFT_STAGE;
                end

                //scaling
                SHIFT_STAGE: begin
                    shifted <= acc >>> 14;
                    state <= SATURATE;
                end

                // clip
                SATURATE: begin
                    if (shifted > 32'sd32767)
                        saturated <= 16'sd32767;
                    else if (shifted < -32'sd32768)
                        saturated <= -16'sd32768;
                    else
                        saturated <= shifted[15:0];
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    d_out <= saturated;
                    valid_out <= 1;
                    state <= WAITING;
                end

            endcase
        end
    end

endmodule