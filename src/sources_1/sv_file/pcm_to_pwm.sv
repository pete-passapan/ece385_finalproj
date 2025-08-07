//counter pcm to pwm converter

module pcm_to_pwm (
    input  logic clk,                    // 400 MHz 
    input  logic rst,
    input  logic signed [15:0] pcm_in,    
    input  logic pcm_valid,               
    output logic pwm_out                 
);

    //synchronize pcm valid to 400 MHz clock 
    logic pcm_valid_sync_0, pcm_valid_sync_1;
    logic pcm_valid_rising_edge;
    //double flop
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pcm_valid_sync_0 <= 0;
            pcm_valid_sync_1 <= 0;
        end else begin
            pcm_valid_sync_0 <= pcm_valid;
            pcm_valid_sync_1 <= pcm_valid_sync_0;
        end
    end

    assign pcm_valid_rising_edge = (pcm_valid_sync_0 & ~pcm_valid_sync_1);

    // synchronize pcm inputs using synchronized valid 
    logic signed [15:0] pcm_reg;
    always_ff @(posedge clk) begin
        if (rst)
            pcm_reg <= 0;
        else if (pcm_valid_rising_edge)
            pcm_reg <= pcm_in;
    end
    
    
    //12-bit pwm, center signed pcm input so the waveform is all positive
    logic [11:0] duty_cycle;
    always_comb begin
        duty_cycle = (pcm_reg[15-:12]) + 12'd2048;
    end

    // pwm counter
    // duty cycle proportional to amplitude; it's 1 until the counter counts to the amplitude. 
    //amplitude as a fraction of full 12-bit is the duty cycle
    logic [11:0] pwm_counter;
    always_ff @(posedge clk) begin
        if (rst)
            pwm_counter <= 0;
        else
            pwm_counter <= pwm_counter + 1;
    end

    assign pwm_out = (pwm_counter < duty_cycle);

endmodule
