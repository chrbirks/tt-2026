// Ring Oscillator DCO — Gate-Level (sg13g2_stdcell)
// 7-stage ring oscillator with per-stage delay control.
// Each stage: mandatory inverter + optional 2-inverter delay path via MUX.
// freq_ctrl_i[i]=0: bypass (fast), freq_ctrl_i[i]=1: extra delay (slow).
// Enable via MUX at feedback point: enable_i=0 breaks oscillation.

module ring_osc_dco (
    input  wire       enable_i,
    input  wire [6:0] freq_ctrl_i,
    output wire       dco_clk_o
);

    // Inter-stage wires
    (* keep *) wire stage_out [0:6];
    (* keep *) wire feedback;

    // Per-stage delay path wires
    (* keep *) wire fast_path [0:6];
    (* keep *) wire delay_a   [0:6];
    (* keep *) wire delay_b   [0:6];
    (* keep *) wire mux_out   [0:6];

    // Enable MUX at feedback point: selects between stage 6 output and constant 0
    // When enable_i=0, input is held constant → no oscillation
    (* keep *) wire osc_input;
    sg13g2_mux2_1 u_en_mux (
        .A0(1'b0),
        .A1(stage_out[6]),
        .S(enable_i),
        .X(osc_input)
    );

    // Stage 0: input from feedback (enable_i mux output)
    sg13g2_inv_1 u_inv_0 (.A(osc_input),    .Y(fast_path[0]));
    sg13g2_inv_1 u_da_0  (.A(osc_input),    .Y(delay_a[0]));
    sg13g2_inv_1 u_db_0  (.A(delay_a[0]),   .Y(delay_b[0]));
    sg13g2_mux2_1 u_mux_0 (
        .A0(fast_path[0]),
        .A1(delay_b[0]),
        .S(freq_ctrl_i[0]),
        .X(stage_out[0])
    );

    // Stage 1
    sg13g2_inv_1 u_inv_1 (.A(stage_out[0]), .Y(fast_path[1]));
    sg13g2_inv_1 u_da_1  (.A(stage_out[0]), .Y(delay_a[1]));
    sg13g2_inv_1 u_db_1  (.A(delay_a[1]),   .Y(delay_b[1]));
    sg13g2_mux2_1 u_mux_1 (
        .A0(fast_path[1]),
        .A1(delay_b[1]),
        .S(freq_ctrl_i[1]),
        .X(stage_out[1])
    );

    // Stage 2
    sg13g2_inv_1 u_inv_2 (.A(stage_out[1]), .Y(fast_path[2]));
    sg13g2_inv_1 u_da_2  (.A(stage_out[1]), .Y(delay_a[2]));
    sg13g2_inv_1 u_db_2  (.A(delay_a[2]),   .Y(delay_b[2]));
    sg13g2_mux2_1 u_mux_2 (
        .A0(fast_path[2]),
        .A1(delay_b[2]),
        .S(freq_ctrl_i[2]),
        .X(stage_out[2])
    );

    // Stage 3
    sg13g2_inv_1 u_inv_3 (.A(stage_out[2]), .Y(fast_path[3]));
    sg13g2_inv_1 u_da_3  (.A(stage_out[2]), .Y(delay_a[3]));
    sg13g2_inv_1 u_db_3  (.A(delay_a[3]),   .Y(delay_b[3]));
    sg13g2_mux2_1 u_mux_3 (
        .A0(fast_path[3]),
        .A1(delay_b[3]),
        .S(freq_ctrl_i[3]),
        .X(stage_out[3])
    );

    // Stage 4
    sg13g2_inv_1 u_inv_4 (.A(stage_out[3]), .Y(fast_path[4]));
    sg13g2_inv_1 u_da_4  (.A(stage_out[3]), .Y(delay_a[4]));
    sg13g2_inv_1 u_db_4  (.A(delay_a[4]),   .Y(delay_b[4]));
    sg13g2_mux2_1 u_mux_4 (
        .A0(fast_path[4]),
        .A1(delay_b[4]),
        .S(freq_ctrl_i[4]),
        .X(stage_out[4])
    );

    // Stage 5
    sg13g2_inv_1 u_inv_5 (.A(stage_out[4]), .Y(fast_path[5]));
    sg13g2_inv_1 u_da_5  (.A(stage_out[4]), .Y(delay_a[5]));
    sg13g2_inv_1 u_db_5  (.A(delay_a[5]),   .Y(delay_b[5]));
    sg13g2_mux2_1 u_mux_5 (
        .A0(fast_path[5]),
        .A1(delay_b[5]),
        .S(freq_ctrl_i[5]),
        .X(stage_out[5])
    );

    // Stage 6
    sg13g2_inv_1 u_inv_6 (.A(stage_out[5]), .Y(fast_path[6]));
    sg13g2_inv_1 u_da_6  (.A(stage_out[5]), .Y(delay_a[6]));
    sg13g2_inv_1 u_db_6  (.A(delay_a[6]),   .Y(delay_b[6]));
    sg13g2_mux2_1 u_mux_6 (
        .A0(fast_path[6]),
        .A1(delay_b[6]),
        .S(freq_ctrl_i[6]),
        .X(stage_out[6])
    );

    assign dco_clk_o = stage_out[6];

endmodule
