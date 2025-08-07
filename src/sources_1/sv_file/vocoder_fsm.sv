`timescale 1ns / 1ps

module vocoder_fsm (
    input  logic clk,
    input  logic rst,

    // Synchronized inputs (valid once per 100 cycles)
    input  logic pcm_valid_44k,
    input  logic signed [15:0] mic_data_sync,
    input  logic signed [15:0] mem_data_sync,

    // Outputs from filters
    output logic signed [15:0] mic_filtered [15],
    output logic signed [15:0] mem_filtered [15],
    output logic valid_out
);

    typedef enum logic [2:0] {
        IDLE,
        MIC_PROC, MIC_WAIT,
        MEM_PROC, MEM_WAIT,
        DONE
    } state_t;

    state_t state, next_state;

    // Local input buffer
    logic signed [15:0] mic_buf, mem_buf;

    // Filter interface
    logic signed [15:0] d_in;
    logic pcm_valid;
    logic signed [15:0] filter_out [15];
    logic [14:0] valid_bus;
    logic filter_valid;

    // Instantiate shared filterbank
    mel_filterbank filter_inst (
        .clk(clk),
        .rst(rst),
        .pcm_valid(pcm_valid),
        .d_in(d_in),
        .d_out(filter_out),
        .valid_bus(valid_bus),
        .valid_out(filter_valid)
    );

    // FSM next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE:       if (pcm_valid_44k) next_state = MIC_PROC;
            MIC_PROC:   next_state = MIC_WAIT;
            MIC_WAIT:   if (filter_valid) next_state = MEM_PROC;
            MEM_PROC:   next_state = MEM_WAIT;
            MEM_WAIT:   if (filter_valid) next_state = DONE;
            DONE:       next_state = IDLE;
        endcase
    end

    // FSM state register
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Buffer mic/mem data on pcm_valid_44k
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mic_buf <= 16'sd0;
            mem_buf <= 16'sd0;
        end else if (pcm_valid_44k) begin
            mic_buf <= mic_data_sync;
            mem_buf <= mem_data_sync;
        end
    end

    // pcm_valid pulse into filter
    assign pcm_valid = (state == MIC_PROC || state == MEM_PROC);

    // mux input into filter
    assign d_in = (state == MIC_PROC||MIC_WAIT) ? mic_buf :
                  (state == MEM_PROC||MEM_WAIT) ? mem_buf : 16'sd0;

    // Output capture
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mic_filtered <= '{default: 16'sd0};
            mem_filtered <= '{default: 16'sd0};
            valid_out <= 0;
        end else begin
            valid_out <= 0;
            if (state == MIC_WAIT && filter_valid)
                mic_filtered <= filter_out;
            if (state == MEM_WAIT && filter_valid) begin
                mem_filtered <= filter_out;
                valid_out <= 1;
            end
        end
    end

endmodule
