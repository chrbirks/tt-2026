// Frequency Divider (Divide-by-N)
// Counts DCO clock edges and toggles output every N/2 cycles
// to produce a 50% duty cycle output at f_dco/N.

module freq_divider #(
    parameter DIV_RATIO = 8
) (
    input  wire clk_in,
    input  wire rst_n,
    output reg  clk_out
);

    localparam HALF = DIV_RATIO / 2;
    localparam CTR_W = $clog2(HALF);

    reg [CTR_W-1:0] count;

    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            count   <= '0;
            clk_out <= 1'b0;
        end else if (count == HALF - 1) begin
            count   <= '0;
            clk_out <= ~clk_out;
        end else begin
            count <= count + 1'b1;
        end
    end

endmodule
