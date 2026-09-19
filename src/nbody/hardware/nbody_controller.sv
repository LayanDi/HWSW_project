`timescale 1ns/1ps

module nbody_controller #(
    parameter int NUM_BODIES = 5
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [31:0] iterations,

    input  logic        datapath_done,

    output logic        load_inputs,
    output logic        calc_pair,
    output logic        update_positions,
    output logic        capture_outputs,

    output logic [$clog2(NUM_BODIES)-1:0] body_i,
    output logic [$clog2(NUM_BODIES)-1:0] body_j,
    output logic [31:0] iteration_count,

    output logic        busy,
    output logic        done
);

    typedef enum logic [2:0] {
        S_IDLE,
        S_LOAD,
        S_PAIR_START,
        S_PAIR_WAIT,
        S_POS_START,
        S_POS_WAIT,
        S_FINISH
    } state_t;

    state_t state, next_state;

    logic [$clog2(NUM_BODIES)-1:0] next_i, next_j;
    logic last_pair;

    assign last_pair = (body_i == NUM_BODIES-2) &&
                       (body_j == NUM_BODIES-1);

    always_comb begin
        next_i = body_i;
        next_j = body_j;

        if (last_pair) begin
            next_i = '0;
            next_j = {{($clog2(NUM_BODIES)-1){1'b0}},1'b1};
        end
        else if (body_j == NUM_BODIES-1) begin
            next_i = body_i + 1'b1;
            next_j = body_i + 2;
        end
        else begin
            next_j = body_j + 1'b1;
        end
    end

    always_comb begin
        next_state       = state;

        load_inputs      = 1'b0;
        calc_pair        = 1'b0;
        update_positions = 1'b0;
        capture_outputs  = 1'b0;

        busy              = 1'b1;
        done              = 1'b0;

        case (state)
            S_IDLE: begin
                busy = 1'b0;
                if (start)
                    next_state = S_LOAD;
            end

            S_LOAD: begin
                load_inputs = 1'b1;
                next_state  = S_PAIR_START;
            end

            S_PAIR_START: begin
                calc_pair  = 1'b1;
                next_state = S_PAIR_WAIT;
            end

            S_PAIR_WAIT: begin
                if (datapath_done) begin
                    if (last_pair)
                        next_state = S_POS_START;
                    else
                        next_state = S_PAIR_START;
                end
            end

            S_POS_START: begin
                update_positions = 1'b1;
                next_state       = S_POS_WAIT;
            end

            S_POS_WAIT: begin
                if (datapath_done) begin
                    if (iteration_count + 1 >= iterations)
                        next_state = S_FINISH;
                    else
                        next_state = S_PAIR_START;
                end
            end

            S_FINISH: begin
                capture_outputs = 1'b1;
                busy            = 1'b0;
                done            = 1'b1;
                next_state      = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            body_i          <= '0;
            body_j          <= {{($clog2(NUM_BODIES)-1){1'b0}},1'b1};
            iteration_count <= 32'd0;
        end
        else begin
            state <= next_state;

            if (state == S_IDLE && start) begin
                body_i          <= '0;
                body_j          <= {{($clog2(NUM_BODIES)-1){1'b0}},1'b1};
                iteration_count <= 32'd0;
            end

            if (state == S_PAIR_WAIT && datapath_done) begin
                if (last_pair) begin
                    body_i <= '0;
                    body_j <= {{($clog2(NUM_BODIES)-1){1'b0}},1'b1};
                end
                else begin
                    body_i <= next_i;
                    body_j <= next_j;
                end
            end

            if (state == S_POS_WAIT && datapath_done) begin
                iteration_count <= iteration_count + 1'b1;
                body_i          <= '0;
                body_j          <= {{($clog2(NUM_BODIES)-1){1'b0}},1'b1};
            end
        end
    end

endmodule
