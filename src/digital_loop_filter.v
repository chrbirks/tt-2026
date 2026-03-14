// Digital Loop Filter
// 7-bit saturating up/down counter clocked by ref_clk.
// Increments on late (early_i=0), decrements on early_i (early_i=1).
// Resets to midpoint (64) to center the DCO range.

module digital_loop_filter (
    input  wire       clk_ref_i,
    input  wire       rst_n_i,
    input  wire       early_i,
    output reg  [6:0] freq_ctrl_o
);

    always @(posedge clk_ref_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            freq_ctrl_o <= 7'd64;
        end else if (early_i && freq_ctrl_o != 7'd0) begin
            // DCO too fast, decrement to slow down
            freq_ctrl_o <= freq_ctrl_o - 7'd1;
        end else if (!early_i && freq_ctrl_o != 7'd127) begin
            // DCO too slow, increment to speed up
            freq_ctrl_o <= freq_ctrl_o + 7'd1;
        end
    end

endmodule
