// ADPLL Top-Level
// Wires together: Bang-Bang PD, Loop Filter, DCO, Divider.
// Provides lock detection via shift register monitoring early/late pattern.

module tt_um_chrbirks_top #(
    parameter DIV_RATIO = 8
) (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Aliases for inputs/outputs
  wire   clk_ref;
  wire   enable;
  wire   clk_out;
  wire   locked;
  wire [6:0] freq_ctrl;

  // Internal signals
  wire early;
  wire dco_clk;
  wire clk_fb;

  // Reassign inputs
  assign clk_ref = clk;
  assign enable  = ena;

  // ui_in unused in closed-loop mode (TT convention: all inputs declared)

  // Reassign outputs
  assign uo_out = {6'b0, locked, clk_out};
  assign uio_out = {1'b0, freq_ctrl};
  assign uio_oe  = 8'b0111_1111;        // uio[6:0] as outputs

  // TODO: Assign clk to output pin for reference

    // Phase Detector: compare ref_clk with feedback clock
    bb_phase_detector pd_inst (
        .clk_ref_i (clk_ref),
        .rst_n_i   (rst_n),
        .clk_fb_i  (clk_fb),
        .early_o   (early)
    );

    // Loop Filter: adjust frequency control word
    digital_loop_filter filter_inst (
        .clk_ref_i   (clk_ref),
        .rst_n_i     (rst_n),
        .early_i     (early),
        .freq_ctrl_o (freq_ctrl)
    );

    // DCO: generate high-frequency clock
    // In simulation, the behavioral model replaces the gate-level version
    ring_osc_dco dco_inst (
        .enable_i    (enable),
        .freq_ctrl_i (freq_ctrl),
        .dco_clk_o   (dco_clk)
    );

    // Frequency Divider: divide DCO clock down to ref_clk range
    // TODO: Handle different clock domains
    freq_divider #(
        .DIV_RATIO(DIV_RATIO)
    ) freq_div_inst (
        .clk_i   (dco_clk),
        .rst_n_i (rst_n),
        .clk_o   (clk_fb)
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
