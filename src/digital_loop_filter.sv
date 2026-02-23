// Digital Loop Filter
// 7-bit saturating up/down counter clocked by ref_clk.
// Increments on late (early=0), decrements on early (early=1).
// Resets to midpoint (64) to center the DCO range.

module digital_loop_filter (
    input  wire       clk_ref,
    input  wire       rst_n,
    input  wire       early,
    output reg  [6:0] freq_ctrl
);

    always @(posedge clk_ref or negedge rst_n) begin
        if (!rst_n) begin
            freq_ctrl <= 7'd64;
        end else if (early && freq_ctrl != 7'd0) begin
            // DCO too fast, decrement to slow down
            freq_ctrl <= freq_ctrl - 7'd1;
        end else if (!early && freq_ctrl != 7'd127) begin
            // DCO too slow, increment to speed up
            freq_ctrl <= freq_ctrl + 7'd1;
        end
    end

endmodule
