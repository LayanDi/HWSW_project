`timescale 1ns/1ps
module pyflate_controller(
    input logic clk, rst_n, start, input_valid, symbol_match, mtf_done,
    input logic output_ready, end_of_stream,
    output logic clear_code, load_bit, do_lookup, do_mtf, decoded_valid,
    output logic busy, done
);
    typedef enum logic [3:0] {
        S_IDLE,S_CLEAR,S_WAIT_BIT,S_READ_BIT,S_LOOKUP,
        S_MTF_START,S_MTF_WAIT,S_OUTPUT,S_DONE
    } state_t;
    state_t state,next_state;

    always_comb begin
        next_state=state; clear_code=0; load_bit=0; do_lookup=0;
        do_mtf=0; decoded_valid=0; busy=1; done=0;
        case(state)
            S_IDLE: begin busy=0; if(start) next_state=S_CLEAR; end
            S_CLEAR: begin clear_code=1; next_state=S_WAIT_BIT; end
            S_WAIT_BIT: begin
                if(end_of_stream) next_state=S_DONE;
                else if(input_valid) next_state=S_READ_BIT;
            end
            S_READ_BIT: begin load_bit=1; next_state=S_LOOKUP; end
            S_LOOKUP: begin
                do_lookup=1;
                if(symbol_match) next_state=S_MTF_START;
                else next_state=S_WAIT_BIT;
            end
            S_MTF_START: begin do_mtf=1; next_state=S_MTF_WAIT; end
            S_MTF_WAIT: if(mtf_done) next_state=S_OUTPUT;
            S_OUTPUT: begin
                decoded_valid=1;
                if(output_ready) next_state=S_CLEAR;
            end
            S_DONE: begin busy=0; done=1; next_state=S_IDLE; end
            default: next_state=S_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n)
        if(!rst_n) state<=S_IDLE; else state<=next_state;
endmodule
