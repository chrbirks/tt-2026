// Bang-Bang Phase Detector
// Samples clk_fb on rising edge of clk_ref.
// early=1 means DCO is too fast (fb leads ref), early=0 means too slow.

module bb_phase_detector (
    input  wire clk_ref,
    input  wire rst_n,
    input  wire clk_fb,
    output reg  early
);

    always @(posedge clk_ref or negedge rst_n) begin
        if (!rst_n)
            early <= 1'b0;
        else
            early <= clk_fb;
    end

endmodule
