// Bang-Bang Phase Detector
// Samples clk_fb_i on rising edge of clk_ref_i.
//
// early_o = 1: DCO clock is too fast compared to ref clock
// early_o = 0: DCO clock is too slow compared to ref clock

module bb_phase_detector (
    input  wire clk_ref_i,
    input  wire rst_n_i,
    input  wire clk_fb_i,
    output reg  early_o
);

    always @(posedge clk_ref_i or negedge rst_n_i) begin
        if (!rst_n_i)
            early_o <= 1'b0;
        else
            early_o <= clk_fb_i;
    end

endmodule
