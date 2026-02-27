# ADPLL Makefile — iverilog simulation + yosys synthesis

TOP         = tt_um_chrbirks_top
SRC_DIR     = ../src
TEST_DIR    = .
SRC_FILES   = $(SRC_DIR)/bb_phase_detector.sv \
              $(SRC_DIR)/digital_loop_filter.sv \
              $(SRC_DIR)/freq_divider.sv \
              $(SRC_DIR)/tt_um_chrbirks_top.sv
SIM_DCO     = $(SRC_DIR)/ring_osc_dco_sim_model.sv
GATE_DCO    = $(SRC_DIR)/ring_osc_dco.sv
TB          = $(TEST_DIR)/tb_adpll.sv

.PHONY: sim sim-view clean help

help:
	@echo "Targets:"
	@echo "  sim    — Compile and run simulation (behavioral DCO)"
	@echo "  view   — Open VCD waveform in GTKWave"
	@echo "  clean  — Remove build artifacts"

## Simulation (uses behavioral DCO model)
sim: clean adpll_tb
	vvp adpll_tb

adpll_tb: $(SRC_FILES) $(SIM_DCO) $(TB)
	iverilog -g2012 -DSIMULATION -o $@ $(SRC_FILES) $(SIM_DCO) $(TB)

## Waveform viewer
sim-view: adpll.vcd
	surfer adpll.vcd &

# adpll.vcd: sim

clean:
	rm -f adpll_tb adpll.vcd
