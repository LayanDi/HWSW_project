`timescale 1ns/1ps

module nbody_tb;

    localparam int NUM_BODIES = 5;
    localparam int FP_WIDTH    = 64;

    logic clk;
    logic rst_n;
    logic start;

    logic [31:0] iterations;
    logic [FP_WIDTH-1:0] dt;

    logic [FP_WIDTH-1:0] pos_x_in [NUM_BODIES];
    logic [FP_WIDTH-1:0] pos_y_in [NUM_BODIES];
    logic [FP_WIDTH-1:0] pos_z_in [NUM_BODIES];

    logic [FP_WIDTH-1:0] vel_x_in [NUM_BODIES];
    logic [FP_WIDTH-1:0] vel_y_in [NUM_BODIES];
    logic [FP_WIDTH-1:0] vel_z_in [NUM_BODIES];

    logic [FP_WIDTH-1:0] mass_in [NUM_BODIES];

    logic [FP_WIDTH-1:0] pos_x_out [NUM_BODIES];
    logic [FP_WIDTH-1:0] pos_y_out [NUM_BODIES];
    logic [FP_WIDTH-1:0] pos_z_out [NUM_BODIES];

    logic [FP_WIDTH-1:0] vel_x_out [NUM_BODIES];
    logic [FP_WIDTH-1:0] vel_y_out [NUM_BODIES];
    logic [FP_WIDTH-1:0] vel_z_out [NUM_BODIES];

    logic busy;
    logic done;

    real PI;
    real SOLAR_MASS;
    real DAYS_PER_YEAR;

    integer k;

    nbody_accelerator #(
        .NUM_BODIES(NUM_BODIES),
        .FP_WIDTH(FP_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .start(start),
        .iterations(iterations),
        .dt(dt),

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

        .busy(busy),
        .done(done)
    );

    always #5 clk = ~clk;

    task automatic set_body(
        input int idx,
        input real x,
        input real y,
        input real z,
        input real vx,
        input real vy,
        input real vz,
        input real mass
    );
        begin
            pos_x_in[idx] = $realtobits(x);
            pos_y_in[idx] = $realtobits(y);
            pos_z_in[idx] = $realtobits(z);

            vel_x_in[idx] = $realtobits(vx);
            vel_y_in[idx] = $realtobits(vy);
            vel_z_in[idx] = $realtobits(vz);

            mass_in[idx] = $realtobits(mass);
        end
    endtask

    initial begin
        $dumpfile("nbody_tb.vcd");
        $dumpvars(0, nbody_tb);

        clk   = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;

        PI            = 3.14159265358979323;
        SOLAR_MASS    = 4.0 * PI * PI;
        DAYS_PER_YEAR = 365.24;

        dt         = $realtobits(0.01);
        iterations = 32'd1;

        /* Sun */
        set_body(
            0,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            SOLAR_MASS
        );

        /* Jupiter */
        set_body(
            1,
            4.84143144246472090,
           -1.16032004402742839,
           -0.103622044471123181,
            1.66007664274403694e-3 * DAYS_PER_YEAR,
            7.69901118419740425e-3 * DAYS_PER_YEAR,
           -6.90460016972063023e-5 * DAYS_PER_YEAR,
            9.54791938424326609e-4 * SOLAR_MASS
        );

        /* Saturn */
        set_body(
            2,
            8.34336671824457987,
            4.12479856412430479,
           -0.403523417114321381,
           -2.76742510726862411e-3 * DAYS_PER_YEAR,
            4.99852801234917238e-3 * DAYS_PER_YEAR,
            2.30417297573763929e-5 * DAYS_PER_YEAR,
            2.85885980666130812e-4 * SOLAR_MASS
        );

        /* Uranus */
        set_body(
            3,
            12.8943695621391310,
           -15.1111514016986340,
           -0.223307578892655734,
            2.96460137564761618e-3 * DAYS_PER_YEAR,
            2.37847173959480950e-3 * DAYS_PER_YEAR,
           -2.96589568540237556e-5 * DAYS_PER_YEAR,
            4.36624404335156298e-5 * SOLAR_MASS
        );

        /* Neptune */
        set_body(
            4,
            15.3796971148509165,
           -25.9193146099879641,
            0.179258772950371181,
            2.68067772490389322e-3 * DAYS_PER_YEAR,
            1.62824170038242295e-3 * DAYS_PER_YEAR,
           -9.51592254519715870e-5 * DAYS_PER_YEAR,
            5.15138902046611451e-5 * SOLAR_MASS
        );

        #20;
        rst_n = 1'b1;

        #20;
        start = 1'b1;
        #10;
        start = 1'b0;

        wait(done == 1'b1);

        $display("--------------------------------------------------");
        $display("N-body accelerator completed");
        $display("Iterations = %0d", iterations);

        for (k = 0; k < NUM_BODIES; k = k + 1) begin
            $display(
                "Body %0d: pos=(%f, %f, %f) vel=(%f, %f, %f)",
                k,
                $bitstoreal(pos_x_out[k]),
                $bitstoreal(pos_y_out[k]),
                $bitstoreal(pos_z_out[k]),
                $bitstoreal(vel_x_out[k]),
                $bitstoreal(vel_y_out[k]),
                $bitstoreal(vel_z_out[k])
            );
        end

        $display("--------------------------------------------------");

        #20;
        $finish;
    end

endmodule
