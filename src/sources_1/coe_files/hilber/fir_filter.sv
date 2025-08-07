module fir_filter #(
    parameter N = 63                          // num taps
)(
    input  logic clk,              
    input  logic rst,

    input  logic signed [15:0] pcm_in,  
    input  logic valid_in,                       

    output logic signed [15:0] pcm_out,  
    output logic valid_out
);

    logic signed [15:0] coeffs [N];
    initial begin
        $readmemb("hilbert_taps.mem" , coeffs);
    end

    logic signed [15:0] x [0:N-1];

    logic signed [39:0] acc;
    logic [7:0] mac_index;
    logic mac_active, mac_done;

    // states
    typedef enum logic [1:0] {
        IDLE, LOAD, MAC, DONE
    } state_t;

    state_t state, next_state;
    
    
     always_comb begin
            next_state = state;
            case (state)
                IDLE:  if (valid_in) next_state = LOAD;
                LOAD:              next_state = MAC;
                MAC:  if (mac_index == N-1) next_state = DONE; //after all multiply-accum have finished
                DONE:              next_state = IDLE;
            endcase
        end
    


    always_ff @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

   
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < N; i++) begin
                x[i] <= '0;
            end
        end else if (state == LOAD) begin //shift in new sample
            x[0] <= pcm_in;
            for (int i = 1; i < N; i++) begin
                x[i] <= x[i-1];
            end
        end
    end

    // multiply-accum
    always_ff @(posedge clk) begin
        if (state == LOAD) begin
            acc <= '0;
            mac_index <= 0;
        end else if (state == MAC) begin //perform all the macs per new sample. each mac on a new clock cycle
            acc <= acc + x[mac_index] * coeffs[mac_index];
            mac_index <= mac_index + 1;
        end
    end

    logic signed [15:0] acc_scaled;
    always_comb begin
        // taps are q2.14 so scale back down
        logic signed [39:0] acc_shifted;
        acc_shifted = acc >>> 14;

        // clip
        if (acc_shifted > 32767)
            acc_scaled = 32767;
        else if (acc_shifted < -32768)
            acc_scaled = -32768;
        else
            acc_scaled = acc_shifted[15:0];
    end
    
    always_ff @(posedge clk) begin
        if (state == DONE) begin
            pcm_out <= acc_scaled;
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end

endmodule
