# ADPLL Makefile — iverilog simulation + yosys synthesis

TOP         = tt_um_chrbirks_top
SRC_DIR     = src
TEST_DIR    = test
SRC_FILES   = $(SRC_DIR)/bb_phase_detector.sv \
              $(SRC_DIR)/digital_loop_filter.sv \
              $(SRC_DIR)/freq_divider.sv \
              $(SRC_DIR)/tt_um_chrbirks_top.sv
SIM_DCO     = $(SRC_DIR)/ring_osc_dco_sim_model.sv
GATE_DCO    = $(SRC_DIR)/ring_osc_dco.sv
TB          = $(TEST_DIR)/tb_adpll.sv

# Yosys/synthesis settings
LIBERTY    ?= $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib
VERILOG_LIB?= $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v

.PHONY: sim view synth clean help

help:
	@echo "Targets:"
	@echo "  sim    — Compile and run simulation (behavioral DCO)"
	@echo "  view   — Open VCD waveform in GTKWave"
	@echo "  synth  — Synthesize with Yosys using sg13g2 liberty"
	@echo "  clean  — Remove build artifacts"

## Simulation (uses behavioral DCO model)
sim: adpll_tb
	vvp adpll_tb

adpll_tb: $(SRC_FILES) $(SIM_DCO) $(TB)
	iverilog -g2012 -DSIMULATION -o $@ $(SRC_FILES) $(SIM_DCO) $(TB)

## Waveform viewer
view: adpll.vcd
	gtkwave adpll.vcd &

adpll.vcd: sim

## Synthesis with Yosys (gate-level DCO, no behavioral model)
synth:
	@if [ -z "$(PDK_ROOT)" ]; then \
		echo "ERROR: PDK_ROOT not set. Point it to your IHP PDK installation."; \
		exit 1; \
	fi
	yosys -p " \
		read_verilog -sv $(SRC_FILES) $(GATE_DCO); \
		synth -top $(TOP); \
		dfflibmap -liberty $(LIBERTY); \
		abc -liberty $(LIBERTY); \
		stat; \
		write_verilog -noattr synth_$(TOP).v \
	"
	@echo "Synthesis complete: synth_$(TOP).v"

clean:
	rm -f adpll_tb adpll.vcd synth_$(TOP).v
