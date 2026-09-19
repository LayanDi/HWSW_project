`timescale 1ns/1ps


module nbody_datapath #(
    parameter int NUM_BODIES = 5,
    parameter int FP_WIDTH    = 64
)(
    input  logic clk,
    input  logic rst_n,

    input  logic load_inputs,
    input  logic calc_pair,
    input  logic update_positions,

    input  logic [$clog2(NUM_BODIES)-1:0] body_i,
    input  logic [$clog2(NUM_BODIES)-1:0] body_j,

    input  logic [FP_WIDTH-1:0] dt_in,

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

    output logic datapath_done
);

    logic [FP_WIDTH-1:0] x  [NUM_BODIES];
    logic [FP_WIDTH-1:0] y  [NUM_BODIES];
    logic [FP_WIDTH-1:0] z  [NUM_BODIES];

    logic [FP_WIDTH-1:0] vx [NUM_BODIES];
    logic [FP_WIDTH-1:0] vy [NUM_BODIES];
    logic [FP_WIDTH-1:0] vz [NUM_BODIES];

    logic [FP_WIDTH-1:0] m  [NUM_BODIES];

    integer k;

    real r_dt;

    real xi, yi, zi;
    real xj, yj, zj;

    real vxi, vyi, vzi;
    real vxj, vyj, vzj;

    real mi, mj;

    real dx, dy, dz;
    real r2;
    real mag;
    real b1m, b2m;

    real tx, ty, tz;
    real tvx, tvy, tvz;

    always_comb begin
        for (k = 0; k < NUM_BODIES; k = k + 1) begin
            pos_x_out[k] = x[k];
            pos_y_out[k] = y[k];
            pos_z_out[k] = z[k];

            vel_x_out[k] = vx[k];
            vel_y_out[k] = vy[k];
            vel_z_out[k] = vz[k];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            datapath_done <= 1'b0;

            for (k = 0; k < NUM_BODIES; k = k + 1) begin
                x[k]  <= '0;
                y[k]  <= '0;
                z[k]  <= '0;
                vx[k] <= '0;
                vy[k] <= '0;
                vz[k] <= '0;
                m[k]  <= '0;
            end
        end
        else begin
            datapath_done <= 1'b0;

            if (load_inputs) begin
                for (k = 0; k < NUM_BODIES; k = k + 1) begin
                    x[k]  <= pos_x_in[k];
                    y[k]  <= pos_y_in[k];
                    z[k]  <= pos_z_in[k];

                    vx[k] <= vel_x_in[k];
                    vy[k] <= vel_y_in[k];
                    vz[k] <= vel_z_in[k];

                    m[k]  <= mass_in[k];
                end

                datapath_done <= 1'b1;
            end

            else if (calc_pair) begin
                r_dt = $bitstoreal(dt_in);

                xi = $bitstoreal(x[body_i]);
                yi = $bitstoreal(y[body_i]);
                zi = $bitstoreal(z[body_i]);

                xj = $bitstoreal(x[body_j]);
                yj = $bitstoreal(y[body_j]);
                zj = $bitstoreal(z[body_j]);

                vxi = $bitstoreal(vx[body_i]);
                vyi = $bitstoreal(vy[body_i]);
                vzi = $bitstoreal(vz[body_i]);

                vxj = $bitstoreal(vx[body_j]);
                vyj = $bitstoreal(vy[body_j]);
                vzj = $bitstoreal(vz[body_j]);

                mi = $bitstoreal(m[body_i]);
                mj = $bitstoreal(m[body_j]);

                dx = xi - xj;
                dy = yi - yj;
                dz = zi - zj;

                r2 = dx*dx + dy*dy + dz*dz;

                /*
                 * Same formula as the Python benchmark:
                 * mag = dt * (r2 ** -1.5)
                 *
                 * 1.0 / (r2 * sqrt(r2)) is mathematically equivalent.
                 * $sqrt is a simulation system function.
                 */
                mag = r_dt / (r2 * $sqrt(r2));

                b1m = mi * mag;
                b2m = mj * mag;

                vxi = vxi - dx * b2m;
                vyi = vyi - dy * b2m;
                vzi = vzi - dz * b2m;

                vxj = vxj + dx * b1m;
                vyj = vyj + dy * b1m;
                vzj = vzj + dz * b1m;

                vx[body_i] <= $realtobits(vxi);
                vy[body_i] <= $realtobits(vyi);
                vz[body_i] <= $realtobits(vzi);

                vx[body_j] <= $realtobits(vxj);
                vy[body_j] <= $realtobits(vyj);
                vz[body_j] <= $realtobits(vzj);

                datapath_done <= 1'b1;
            end

            else if (update_positions) begin
                r_dt = $bitstoreal(dt_in);

                for (k = 0; k < NUM_BODIES; k = k + 1) begin
                    tx  = $bitstoreal(x[k]);
                    ty  = $bitstoreal(y[k]);
                    tz  = $bitstoreal(z[k]);

                    tvx = $bitstoreal(vx[k]);
                    tvy = $bitstoreal(vy[k]);
                    tvz = $bitstoreal(vz[k]);

                    tx = tx + r_dt * tvx;
                    ty = ty + r_dt * tvy;
                    tz = tz + r_dt * tvz;

                    x[k] <= $realtobits(tx);
                    y[k] <= $realtobits(ty);
                    z[k] <= $realtobits(tz);
                end

                datapath_done <= 1'b1;
            end
        end
    end

endmodule
