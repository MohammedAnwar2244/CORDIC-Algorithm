`timescale 1ns/1ps

module CORDIC_tb;

    // Parameters
    parameter WIDTH  = 32;
    parameter N_ITER = 10;

    // Signals
    reg                     clk;
    reg                     rst_n;
    reg  signed [WIDTH-1:0] x_start, y_start;
    reg  signed [WIDTH-1:0] angle;
    wire signed [WIDTH-1:0] cosine, sine;
    wire                    valid;

    // Instantiate DUT
    CORDIC #(.WIDTH(WIDTH), .N_ITER(N_ITER)) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .x_start (x_start),
        .y_start (y_start),
        .angle   (angle),
        .cosine  (cosine),
        .sine    (sine),
        .valid   (valid)
    );

    // Clock generation (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Task: apply one test vector (self-check vs SV reference)
    task apply_test(input real deg, input [127:0] name);
        real rad;
        real cos_ref, sin_ref;
        real cos_dut, sin_dut;
        real tol;
        begin
            rad = deg * 3.14159265358979 / 180.0;  // deg -> rad

            // Inputs: (1,0) in Q2.30
            x_start = 32'h40000000; // ≈ 1.0
            y_start = 0;
            angle   = $rtoi(rad * (1<<27)); // rad in Q5.27

            // Reset cycle (give DUT a clear start)
            rst_n = 0; @(posedge clk);
            rst_n = 1; @(posedge clk);

            // Wait until DUT asserts valid
            wait(valid);
            @(posedge clk);

            // Convert DUT outputs to real
            cos_dut = $itor(cosine) / (1<<30);
            sin_dut = $itor(sine)   / (1<<30);

            // Reference model (MATLAB equivalent using SV math)
            cos_ref = $cos(rad);
            sin_ref = $sin(rad);

            // Tolerance
            tol = 1e-3; // adjust if needed

            // Print results
            $display("[%s] deg=%0f | DUT cos=%.6f, sin=%.6f | REF cos=%.6f, sin=%.6f",
                     name, deg, cos_dut, sin_dut, cos_ref, sin_ref);

            // Check within tolerance
            if ( (cos_dut - cos_ref) > tol || (cos_ref - cos_dut) > tol ||
                 (sin_dut - sin_ref) > tol || (sin_ref - sin_dut) > tol) begin
                $display("  [FAIL] difference > tol(%.6f)", tol);
            end else begin
                $display("  [PASS]");
            end
        end
    endtask

    // Main stimulus
    initial begin
        integer rand_deg;         // declare loop variable here
        reg [127:0] test_name;    // build text names here

        // Defaults
        rst_n   = 0;
        x_start = 0;
        y_start = 0;
        angle   = 0;

        // Short wait for stable clock
        repeat(3) @(posedge clk);

        // Deterministic tests
        apply_test(0,    "0_deg");
        apply_test(30,   "30_deg");
        apply_test(45,   "45_deg");
        apply_test(60,   "60_deg");
        apply_test(90,   "90_deg");
        apply_test(180,  "180_deg");
        apply_test(270,  "270_deg");
        apply_test(360,  "360_deg");

        // Overflow / Underflow tests
        apply_test(450,  "450_deg (->90)");
        apply_test(-90,  "-90_deg (->270)");
        apply_test(720,  "720_deg (->0)");
        apply_test(-450, "-450_deg (->270)");

        /* Randomized tests (large set)
        repeat (50) begin
            rand_deg = $urandom_range(-2000, 2000); // random integer angle
            // build readable test name into fixed-size reg
            $sformat(test_name, "random_test_%0d", rand_deg);
            apply_test(rand_deg, test_name);
        end
**/
        $display("===== All Tests Finished =====");
        $stop;
    end

endmodule
