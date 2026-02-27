# ADPLL Makefile — iverilog simulation + yosys synthesis + GDS flow

TOP         = tt_um_chrbirks_top
SRC_DIR     = src
TEST_DIR    = test
SRC_FILES   = $(SRC_DIR)/bb_phase_detector.sv \
              $(SRC_DIR)/digital_loop_filter.sv \
              $(SRC_DIR)/freq_divider.sv \
              $(SRC_DIR)/tt_um_chrbirks_top.sv
SIM_DCO     = $(SRC_DIR)/ring_osc_dco_sim_model.sv
GATE_DCO    = $(SRC_DIR)/ring_osc_dco.sv

# Yosys/synthesis settings
LIBERTY    ?= $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib
VERILOG_LIB?= $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v

# GDS / LibreLane flow settings
TT_TOOLS          = tt
TT_TOOLS_REPO     = https://github.com/TinyTapeout/tt-support-tools
TT_TOOLS_REF      = main
LIBRELANE_VERSION = 3.0.0.dev44
PDK_ROOT_LOCAL    ?= $(CURDIR)/IHP-Open-PDK
VENV              = .venv
# Set GDS_EXTRA_ARGS=--no-docker to run without Docker (requires local OpenROAD/KLayout install)
GDS_EXTRA_ARGS    ?=

.PHONY: sim view synth gds-setup gds gl-test clean help

help:
	@echo "Targets:"
	@echo "  sim        — Compile and run behavioral simulation (iverilog + vvp)"
	@echo "  view       — Open waveform in GTKWave"
	@echo "  synth      — Synthesize with Yosys using sg13g2 liberty"
	@echo "  gds-setup  — One-time setup: clone tt-support-tools and install librelane"
	@echo "  gds        — Full ASIC flow: synthesis → P&R → DRC → timing → GDS"
	@echo "  gl-test    — Gate-level simulation using netlist from runs/wokwi/final/nl/"
	@echo "  clean      — Remove build artifacts"

## Synthesis with Yosys (gate-level DCO, no behavioral model)
synth:
	@if [ -z "$(PDK_ROOT)" ]; then \
		echo "ERROR: PDK_ROOT not set. Point it to your IHP PDK installation."; \
		exit 1; \
	fi
	yosys -p " \
		read_verilog -sv $(SRC_DIR)/pdk_stubs.v; \
		read_verilog -sv $(SRC_FILES) $(GATE_DCO); \
		synth -top $(TOP); \
		dfflibmap -liberty $(LIBERTY); \
		abc -liberty $(LIBERTY); \
		stat; \
		write_verilog -noattr synth_$(TOP).v \
	"
	@echo "Synthesis complete: synth_$(TOP).v"

## One-time setup: clone tt-support-tools, create venv, and install librelane
gds-setup:
	@if [ ! -d "$(TT_TOOLS)" ]; then \
		git clone $(TT_TOOLS_REPO) --branch $(TT_TOOLS_REF) $(TT_TOOLS); \
	else \
		echo "$(TT_TOOLS)/ already exists, skipping clone"; \
	fi
	@if [ ! -d "$(VENV)" ]; then \
		python -m venv $(VENV); \
	fi
	$(VENV)/bin/pip install --upgrade pip librelane==$(LIBRELANE_VERSION)
	$(VENV)/bin/pip install gitpython chevron configupdater requests gdstk cairosvg matplotlib mistune

## Full ASIC flow: synthesis → place-and-route → DRC → timing → GDS
gds: gds-setup
	PDK_ROOT=$(PDK_ROOT_LOCAL) PATH=$(CURDIR)/$(VENV)/bin:$$PATH $(VENV)/bin/python ./$(TT_TOOLS)/tt_tool.py --create-user-config --ihp
	PDK_ROOT=$(PDK_ROOT_LOCAL) PATH=$(CURDIR)/$(VENV)/bin:$$PATH $(VENV)/bin/python ./$(TT_TOOLS)/tt_tool.py --harden --ihp $(GDS_EXTRA_ARGS)

## Gate-level simulation using netlist produced by the GDS flow
gl-test:
	@if [ ! -d "runs/wokwi/final/nl" ]; then \
		echo "ERROR: runs/wokwi/final/nl/ not found. Run 'make gds' first."; \
		exit 1; \
	fi
	cp runs/wokwi/final/nl/*.nl.v $(TEST_DIR)/
	cd $(TEST_DIR) && make clean && GATES=yes make

clean:
	rm -f synth_$(TOP).v
	rm -rf runs/ $(TT_TOOLS)/ $(VENV)/
