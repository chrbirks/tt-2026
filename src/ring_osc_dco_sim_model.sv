// Behavioral DCO Model for Simulation
// Gate-level ring oscillator has zero propagation delay in Verilog simulators,
// so this model maps freq_ctrl to a time delay to produce a realistic clock.

`timescale 1ns / 1ps

module ring_osc_dco (
    input  wire       enable,
    input  wire [6:0] freq_ctrl,
    output reg        dco_clk
);

    // Map freq_ctrl to half-period delay (in ns).
    // Higher freq_ctrl → more delay stages active → slower oscillation.
    // Target: ~300-600 MHz DCO → half-period ~0.8-1.7 ns
    // After /8 divider: ~40-75 MHz output
    real half_period;

    always @(*) begin
        // Base half-period 0.8 ns (fastest, ~625 MHz)
        // Each freq_ctrl bit adds ~0.13 ns delay
        // At freq_ctrl=127: 0.8 + 127*0.007 = ~1.7 ns (~294 MHz)
        half_period = 0.8 + freq_ctrl * 0.007;
    end

    initial dco_clk = 1'b0;

    always begin
        if (enable) begin
            #(half_period) dco_clk = ~dco_clk;
        end else begin
            dco_clk = 1'b0;
            @(posedge enable);
        end
    end

endmodule
