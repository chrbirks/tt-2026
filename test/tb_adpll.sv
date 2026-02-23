// ADPLL Testbench
// Uses behavioral DCO model (compile with -DSIMULATION).
// Generates ref_clk, monitors lock acquisition, measures output frequency.

`timescale 1ns / 1ps

module tb_adpll;

    // Parameters
    localparam REF_PERIOD = 100.0;  // 10 MHz reference clock (100 ns period)
    localparam DIV_RATIO  = 8;
    localparam SIM_TIME   = 200_000; // 200 us simulation

    // Signals
    reg        clk_ref;
    reg        rst_n;
    reg        enable;
    wire       clk_out;
    wire       locked;
    wire [6:0] freq_ctrl;

    // DUT
    tt_um_chrbirks_top #(
        .DIV_RATIO(DIV_RATIO)
    ) dut (
        .clk_ref   (clk_ref),
        .rst_n     (rst_n),
        .enable    (enable),
        .clk_out   (clk_out),
        .locked    (locked),
        .freq_ctrl (freq_ctrl)
    );

    // Reference clock generation
    initial clk_ref = 1'b0;
    always #(REF_PERIOD / 2) clk_ref = ~clk_ref;

    // VCD dump
    initial begin
        $dumpfile("adpll.vcd");
        $dumpvars(0, tb_adpll);
    end

    // Frequency measurement
    integer edge_count;
    real    t_start, t_end, measured_freq;

    task measure_frequency;
        input real window_ns;  // measurement window in ns
        begin
            edge_count = 0;
            t_start = $realtime;
            t_end = t_start + window_ns;
            while ($realtime < t_end) begin
                @(posedge clk_out);
                edge_count = edge_count + 1;
            end
            measured_freq = edge_count / (window_ns * 1e-9) / 1e6; // in MHz
            $display("[MEASURE] %0d edges in %.0f ns → %.2f MHz",
                     edge_count, window_ns, measured_freq);
        end
    endtask

    // Monitor freq_ctrl changes
    always @(freq_ctrl) begin
        $display("[%0t ns] freq_ctrl = %0d", $time, freq_ctrl);
    end

    // Monitor lock
    always @(posedge locked) begin
        $display("[%0t ns] *** LOCKED ***", $time);
    end

    // Main test sequence
    initial begin
        $display("=== ADPLL Testbench Start ===");
        $display("Reference clock: %.1f MHz", 1000.0 / REF_PERIOD);
        $display("Division ratio:  %0d", DIV_RATIO);
        $display("Expected output: ~%.1f MHz", 1000.0 / REF_PERIOD * DIV_RATIO);

        // Reset
        rst_n  = 1'b0;
        enable = 1'b0;
        #(REF_PERIOD * 5);

        // Release reset, enable DCO
        rst_n  = 1'b1;
        enable = 1'b1;
        $display("[%0t ns] Reset released, DCO enabled", $time);

        // Wait for lock or timeout
        fork
            begin : wait_lock
                @(posedge locked);
                $display("[%0t ns] Lock acquired!", $time);
            end
            begin : timeout
                #(SIM_TIME);
                $display("[%0t ns] Timeout - lock not acquired", $time);
            end
        join_any
        disable wait_lock;
        disable timeout;

        // Measure output frequency over 10 us window
        $display("\n--- Frequency Measurement ---");
        measure_frequency(10_000.0);

        // Let it run a bit more and measure again
        #(20_000);
        $display("\n--- Second Measurement ---");
        measure_frequency(10_000.0);

        // Final status
        $display("\n=== Final Status ===");
        $display("freq_ctrl = %0d", freq_ctrl);
        $display("locked    = %0b", locked);
        $display("=== ADPLL Testbench End ===");

        $finish;
    end

    // Watchdog timer
    initial begin
        #(SIM_TIME * 2);
        $display("WATCHDOG: Simulation timeout");
        $finish;
    end

endmodule
