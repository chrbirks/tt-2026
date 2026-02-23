// ADPLL Top-Level
// Wires together: Bang-Bang PD, Loop Filter, DCO, Divider.
// Provides lock detection via shift register monitoring early/late pattern.

module tt_um_chrbirks_top #(
    parameter DIV_RATIO = 8
) (
    input  wire       clk_ref,
    input  wire       rst_n,
    input  wire       enable,
    output wire       clk_out,
    output wire       locked,
    output wire [6:0] freq_ctrl
);

    wire early;
    wire dco_clk;
    wire clk_fb;

    // Phase Detector: compare ref_clk with feedback clock
    bb_phase_detector u_pd (
        .clk_ref (clk_ref),
        .rst_n   (rst_n),
        .clk_fb  (clk_fb),
        .early   (early)
    );

    // Loop Filter: adjust frequency control word
    digital_loop_filter u_lf (
        .clk_ref   (clk_ref),
        .rst_n     (rst_n),
        .early     (early),
        .freq_ctrl (freq_ctrl)
    );

    // DCO: generate high-frequency clock
    // In simulation, the behavioral model replaces the gate-level version
    ring_osc_dco u_dco (
        .enable   (enable),
        .freq_ctrl(freq_ctrl),
        .dco_clk  (dco_clk)
    );

    // Frequency Divider: divide DCO clock down to ref_clk range
    freq_divider #(
        .DIV_RATIO(DIV_RATIO)
    ) u_div (
        .clk_in  (dco_clk),
        .rst_n   (rst_n),
        .clk_out (clk_fb)
    );

    assign clk_out = clk_fb;

    // Lock Detector: 4-bit shift register checks for alternating early/late
    // pattern (1010 or 0101), indicating freq_ctrl is dithering by +/-1.
    reg [3:0] early_history;

    always @(posedge clk_ref or negedge rst_n) begin
        if (!rst_n)
            early_history <= 4'b0000;
        else
            early_history <= {early_history[2:0], early};
    end

    assign locked = (early_history == 4'b1010) || (early_history == 4'b0101);

endmodule
