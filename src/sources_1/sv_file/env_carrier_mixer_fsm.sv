//multiply values from envelope bank and pre-filtered carrier bank. output

module envelope_carrier_mixer_fsm #(
    parameter N = 15,
    parameter WIDTH = 16
)(
    input  logic clk,
    input  logic rst,

    input  logic signed [WIDTH-1:0] envelope_in [N],
    input  logic signed [WIDTH-1:0] carrier_in  [N],
    input  logic envelope_valid,
    input  logic carrier_valid,

    output logic signed [WIDTH-1:0] mixed_out,
    output logic mixed_valid
);

    // states
    //we wait until the carriers (from bram) give a valid output, and then wait for the envelope, then we multiply-accumulate and output.
    typedef enum logic [1:0] {
        IDLE,
        WAIT_ENV,
        MAC,
        OUT
    } state_t;

    state_t state, next_state;

    logic signed [WIDTH-1:0] envelope_reg [N];
    logic signed [WIDTH-1:0] carrier_reg  [N];
    logic signed [2*WIDTH-1:0] products [N];
    logic signed [2*WIDTH-1:0] acc;
    
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                next_state = carrier_valid ? WAIT_ENV : IDLE;

            WAIT_ENV:
                next_state = envelope_valid ? MAC : WAIT_ENV;

            MAC:
                next_state = OUT;

            OUT:
                next_state = IDLE;
        endcase
    end
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            mixed_out <= 0;
            mixed_valid <= 0;
        end else begin
            state <= next_state;
            mixed_valid <= 0; // default off

            case (state)
                IDLE: begin
                    // wait for carrier_valid
                    if (carrier_valid) begin
                        for (int i = 0; i < N; i++) begin
                            carrier_reg[i] <= carrier_in[i];
                        end
                    end
                    
                end

                WAIT_ENV: begin
                    if (envelope_valid) begin
                        for (int i = 0; i < N; i++) begin
                            envelope_reg[i] <= envelope_in[i];
                        end
                    end
                end

                MAC: begin
                
                //experimental weighting to find the least problematic carriers. also gain.
                    acc = 0;
                    products[0]  = (envelope_reg[0]  * carrier_reg[0])>>>2;
                    products[1]  = (envelope_reg[1]  * carrier_reg[1])>>>2;
                    products[2]  = 0;
                    products[3]  = 0;
                    products[4]  = envelope_reg[4]  * carrier_reg[4];
                    products[5]  = (envelope_reg[5]  * carrier_reg[5])>>>1;
                    products[6]  = (envelope_reg[6]  * carrier_reg[6])>>>1;
                    products[7]  = (envelope_reg[7]  * carrier_reg[7])<<<1;
                    products[8]  = (envelope_reg[8]  * carrier_reg[8])<<<2;
                    products[9]  = (envelope_reg[9]  * carrier_reg[9])<<<1;
                    products[10] = envelope_reg[10] * carrier_reg[10];
                    products[11] = envelope_reg[11] * carrier_reg[11];
                    products[12] = (envelope_reg[12] * carrier_reg[12]);
                    products[13] = (envelope_reg[13] * carrier_reg[13])<<<1;
                    products[14] = (envelope_reg[14] * carrier_reg[14])<<<1;
                    
                    acc = products[0]  + products[1]  + products[2]  + products[3]  + products[4]
                        + products[5]  + products[6]  + products[7]  + products[8]  + products[9]
                        + products[10] + products[11] + products[12] + products[13] + products[14];

                end

                OUT: begin
                    mixed_out <= acc[29-:16];
                    mixed_valid <= 1;
                end
            endcase
        end
    end    

endmodule
