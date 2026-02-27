// Black-box stubs for sg13g2 cells used in ring_osc_dco.
// Port names must match the Liberty file exactly.
// These replace the full sg13g2_stdcell.v (which has specify/ifnone blocks
// that Yosys cannot parse) for synthesis purposes.

(* blackbox *)
module sg13g2_inv_1 (input A, output Y);
endmodule

(* blackbox *)
module sg13g2_mux2_1 (input A0, input A1, input S, output X);
endmodule
