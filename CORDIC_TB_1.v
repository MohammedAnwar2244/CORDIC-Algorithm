// Add to your testbench

// Reference model in SystemVerilog (to replace MATLAB for automation)
function real ref_cos(input real deg);
    real rad;
    begin
        rad = deg * 3.14159265358979 / 180.0;
        ref_cos = $cos(rad);
    end
endfunction

function real ref_sin(input real deg);
    real rad;
    begin
        rad = deg * 3.14159265358979 / 180.0;
        ref_sin = $sin(rad);
    end
endfunction

// Modified apply_test with golden model comparison
task apply_test(input real deg, input [127:0] name);
    real rad, cos_exp, sin_exp, cos_dut, sin_dut, err_cos, err_sin;
    begin
        rad = deg * 3.14159265358979 / 180.0;

        // Inputs
        x_start = 32'h40000000; // 1.0 in Q2.30
        y_start = 0;
        angle   = $rtoi(rad * (1<<27));

        // Reset cycle
        rst_n = 0; @(posedge clk);
        rst_n = 1; @(posedge clk);

        // Wait until valid
        wait(valid);
        @(posedge clk);

        // Convert DUT outputs
        cos_dut = $itor(cosine) / (1<<30);
        sin_dut = $itor(sine)   / (1<<30);

        // Expected values
        cos_exp = ref_cos(deg);
        sin_exp = ref_sin(deg);

        // Errors
        err_cos = cos_dut - cos_exp;
        err_sin = sin_dut - sin_exp;

        // Print results
        $display("[%s] deg=%0f | DUT(cos=%f, sin=%f) | EXP(cos=%f, sin=%f) | ERR(cos=%f, sin=%f)",
                  name, deg, cos_dut, sin_dut, cos_exp, sin_exp, err_cos, err_sin);

        // Check tolerance (±0.01)
        if ((err_cos > 0.01) || (err_cos < -0.01) ||
            (err_sin > 0.01) || (err_sin < -0.01)) begin
            $display("  ** ERROR: Mismatch exceeds tolerance!");
        end
    end
endtask

// In main initial block add extra tests
initial begin
    // Deterministic tests
    apply_test(450,  "450_deg (overflow)");
    apply_test(-90,  "minus90_deg (underflow)");
    apply_test(720,  "720_deg (overflow)");

    // Randomized tests
    repeat (10) begin
        real rand_deg;
        rand_deg = ($urandom_range(-2000, 2000)); // random angle
        apply_test(rand_deg, "random_test");
    end

    $display("===== All Tests Finished =====");
    $stop;
end
