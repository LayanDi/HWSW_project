`timescale 1ns/1ps

module nbody_accelerator #(
    parameter int NUM_BODIES = 5,
    parameter int FP_WIDTH    = 64
)(
    input  logic clk,
    input  logic rst_n,

    input  logic start,
    input  logic [31:0] iterations,
    input  logic [FP_WIDTH-1:0] dt,

    input  logic [FP_WIDTH-1:0] pos_x_in [NUM_BODIES],
    input  logic [FP_WIDTH-1:0] pos_y_in [NUM_BODIES],
    input  logic [FP_WIDTH-1:0] pos_z_in [NUM_BODIES],

    input  logic [FP_WIDTH-1:0] vel_x_in [NUM_BODIES],
    input  logic [FP_WIDTH-1:0] vel_y_in [NUM_BODIES],
    input  logic [FP_WIDTH-1:0] vel_z_in [NUM_BODIES],

    input  logic [FP_WIDTH-1:0] mass_in [NUM_BODIES],

    output logic [FP_WIDTH-1:0] pos_x_out [NUM_BODIES],
    output logic [FP_WIDTH-1:0] pos_y_out [NUM_BODIES],
    output logic [FP_WIDTH-1:0] pos_z_out [NUM_BODIES],

    output logic [FP_WIDTH-1:0] vel_x_out [NUM_BODIES],
    output logic [FP_WIDTH-1:0] vel_y_out [NUM_BODIES],
    output logic [FP_WIDTH-1:0] vel_z_out [NUM_BODIES],

    output logic busy,
    output logic done
);

    logic load_inputs;
    logic calc_pair;
    logic update_positions;
    logic capture_outputs;

    logic [$clog2(NUM_BODIES)-1:0] body_i;
    logic [$clog2(NUM_BODIES)-1:0] body_j;
    logic [31:0] iteration_count;

    logic datapath_done;

    nbody_controller #(
        .NUM_BODIES(NUM_BODIES)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .iterations(iterations),

        .datapath_done(datapath_done),

        .load_inputs(load_inputs),
        .calc_pair(calc_pair),
        .update_positions(update_positions),
        .capture_outputs(capture_outputs),

        .body_i(body_i),
        .body_j(body_j),
        .iteration_count(iteration_count),

        .busy(busy),
        .done(done)
    );

    nbody_datapath #(
        .NUM_BODIES(NUM_BODIES),
        .FP_WIDTH(FP_WIDTH)
    ) u_datapath (
        .clk(clk),
        .rst_n(rst_n),

        .load_inputs(load_inputs),
        .calc_pair(calc_pair),
        .update_positions(update_positions),

        .body_i(body_i),
        .body_j(body_j),

        .dt_in(dt),

        .pos_x_in(pos_x_in),
        .pos_y_in(pos_y_in),
        .pos_z_in(pos_z_in),

        .vel_x_in(vel_x_in),
        .vel_y_in(vel_y_in),
        .vel_z_in(vel_z_in),

        .mass_in(mass_in),

        .pos_x_out(pos_x_out),
        .pos_y_out(pos_y_out),
        .pos_z_out(pos_z_out),

        .vel_x_out(vel_x_out),
        .vel_y_out(vel_y_out),
        .vel_z_out(vel_z_out),

        .datapath_done(datapath_done)
    );

endmodule
