//fsm for the hilbert transformer: first, wait for hilbert output and then wait for and load delayed signal, then add their magnitudes and pass into LPF.

module hilbert_top (
    input  logic clk,
    input  logic rst,

    input  logic signed [15:0] real_in,     // I
    input  logic signed [15:0] hilbert_in,  // Q
    input  logic               real_valid,  
    input  logic               hilbert_valid,

    output logic signed [15:0] envelope_out,
    output logic               envelope_valid
);

    localparam int COEFFS_PER_LINE = 5;
    logic signed [15:0] coeff_mem [0:COEFFS_PER_LINE-1];
    initial begin
        $readmemb("lpf_coeffs.mem", coeff_mem);
    end
    
    function [15:0] abs(input [15:0] x);
      abs = x[15] ? -x : x;
    endfunction

    //states
    typedef enum logic [1:0] {
        IDLE,
        WAIT_REAL,
        ABS_ADD,
        FILTER
    } state_t;

    state_t state, next_state;

    //load I and Q into these
    logic signed [15:0] real_reg, hilbert_reg;
    logic signed [16:0] sum_abs;  

    logic signed [15:0] lpf_input;
    logic               lpf_valid;
    logic signed [15:0] lpf_output;
    logic               lpf_out_valid;

    //next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE:       next_state = hilbert_valid ? WAIT_REAL : IDLE;
            WAIT_REAL:  next_state = real_valid    ? ABS_ADD   : WAIT_REAL;
            ABS_ADD:    next_state = FILTER;
            FILTER:     next_state = IDLE;
        endcase
    end

    // states
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state           <= IDLE;
            envelope_valid  <= 0;
            lpf_valid       <= 0;
            lpf_input <=0;
            real_reg<=0;
             hilbert_reg<=0;

   sum_abs<=0;  
        end else begin
            state      <= next_state;
            envelope_valid <= 0;
            lpf_valid  <= 0;

            case (state)
            //waiting for Q
                IDLE: begin
                    if (hilbert_valid)
                        hilbert_reg <= hilbert_in;
                end

                WAIT_REAL: begin
                    if (real_valid)
                        real_reg <= real_in;
                end

                ABS_ADD: begin
                    sum_abs     <= abs(real_reg) + abs(hilbert_reg);
                end

                FILTER: begin
                    lpf_input <= sum_abs[15:0];  // Truncate if needed
                    lpf_valid <= 1;
                end
            endcase
        end
    end

    
    biquad_filter lpf ( 
                .clk(clk),
                .rst(rst),
                .d_in(lpf_input),
                .pcm_valid(lpf_valid),
                .d_out(envelope_out),
                .valid_out(envelope_valid),
                .B0(coeff_mem[0]),
                .B1(coeff_mem[1]),
                .B2(coeff_mem[2]),
                .A1(coeff_mem[3]),
                .A2(coeff_mem[4])
            );


endmodule
