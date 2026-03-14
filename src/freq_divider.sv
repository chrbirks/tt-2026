// Frequency Divider (Divide-by-N)
// Counts DCO clock edges and toggles output every N/2 cycles
// to produce a 50% duty cycle output at f_dco/N.

module freq_divider #(
    parameter DIV_RATIO = 8
) (
    input  wire clk_i,
    input  wire rst_n_i,
    output reg  clk_o
);

    localparam HALF = DIV_RATIO / 2;
    localparam CTR_W = $clog2(HALF);

    reg [CTR_W-1:0] count;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            count   <= '0;
            clk_o <= 1'b0;
        end else if (count == HALF - 1) begin
            count   <= '0;
            clk_o <= ~clk_o;
        end else begin
            count <= count + 1'b1;
        end
    end

endmodule
