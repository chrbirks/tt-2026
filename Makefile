# ADPLL Makefile — iverilog simulation + yosys synthesis + GDS flow

# Set GDS_EXTRA_ARGS=--no-docker to run without Docker (requires local OpenROAD/KLayout install)
GDS_EXTRA_ARGS    ?=

TOP         = tt_um_chrbirks_top
SRC_DIR     = src
TEST_DIR    = test
SRC_FILES   = $(SRC_DIR)/bb_phase_detector.sv \
              $(SRC_DIR)/digital_loop_filter.sv \
              $(SRC_DIR)/freq_divider.sv \
              $(SRC_DIR)/tt_um_chrbirks_top.sv
GATE_DCO    = $(SRC_DIR)/ring_osc_dco.sv

# Yosys/synthesis settings
LIBERTY    ?= $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib
VERILOG_LIB?= $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v

# GDS / LibreLane flow settings
TT_TOOLS          = tt
TT_TOOLS_REPO     = https://github.com/TinyTapeout/tt-support-tools
TT_TOOLS_REF      = main
PDK_REPO          = https://github.com/IHP-GmbH/IHP-Open-PDK.git
PDK_REPO_REF      = dev
PDK_ROOT_LOCAL    ?= $(CURDIR)/IHP-Open-PDK
VENV              = .venv

.PHONY: precheck synth synth-check synth-stat synth-show gds-setup patch-pyosys gds pex-sim pex-sim-analysis clean help

help:
	@echo "Targets:"
	@echo "  synth      — Synthesize with Yosys using sg13g2 liberty"
	@echo "  gds-setup  — One-time setup: clone tt-support-tools and install librelane"
	@echo "  gds        — Full ASIC flow: synthesis → P&R → DRC → timing → GDS"
	@echo "  pex-sim    — Run post-extraction SPICE simulation (saves raw waveform)"
	@echo "  pex-sim-analysis — Measure frequencies from saved pex-sim waveform (no re-sim)"
	@echo "  clean      — Remove build artifacts"

## Check for the env variables set: PDK, PDK_ROOT, VIRTUAL_ENV
precheck:
	@test $${PDK? PDK is not set}
	@test $${PDK_ROOT? PDK_ROOT is not set}
	@test $${VIRTUAL_ENV? VIRTUAL_ENV is not set}
	@if [ ! -d "$(PDK_ROOT_LOCAL)" ]; then \
		git clone --branch $(PDK_REPO_REF) --recurse-submodules $(PDK_REPO); \
	else \
		echo "$(PDK_ROOT_LOCAL)/ already exists, skipping clone"; \
	fi

## Synthesis with Yosys (gate-level DCO, no behavioral model)
synth: precheck
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

synth-check:
	yosys -p "read_verilog synth_tt_um_chrbirks_top.v; check"

synth-stat:
	yosys -p "read_verilog synth_tt_um_chrbirks_top.v; check; stat"

synth-show:
	yosys -p "read_verilog synth_tt_um_chrbirks_top.v; check; show tt_um_chrbirks_top"

## One-time setup: clone tt-support-tools, create venv, and install librelane
gds-setup: precheck
	@if [ ! -d "$(TT_TOOLS)" ]; then \
		git clone $(TT_TOOLS_REPO) --branch $(TT_TOOLS_REF) $(TT_TOOLS); \
	else \
		echo "$(TT_TOOLS)/ already exists, skipping clone"; \
	fi
	@if [ ! -d "$(VENV)" ]; then \
		python -m venv $(VENV); \
	fi
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r requirements.txt

## Full Tiny Tapeout ASIC flow: synthesis → place-and-route → DRC → timing → GDS
gds: gds-setup
	PDK_ROOT=$(PDK_ROOT_LOCAL) PATH=$(CURDIR)/$(VENV)/bin:$$PATH $(VENV)/bin/python ./$(TT_TOOLS)/tt_tool.py --create-user-config --ihp
	PDK_ROOT=$(PDK_ROOT_LOCAL) PATH=$(CURDIR)/$(VENV)/bin:$$PATH $(VENV)/bin/python ./$(TT_TOOLS)/tt_tool.py --harden --ihp $(GDS_EXTRA_ARGS)

## Post-extraction SPICE simulation (requires completed GDS flow)
## NOTE: Run from IIC-OSIC-TOOLS container
STDCELL_SPICE = $(PDK_ROOT_LOCAL)/ihp-sg13g2/libs.ref/sg13g2_stdcell/spice/sg13g2_stdcell.spice
EXTRACTED     = runs/wokwi/final/spice/$(TOP).spice

pex-sim:
	@if [ ! -f "$(EXTRACTED)" ]; then \
		echo "ERROR: $(EXTRACTED) not found. Run 'make gds' first."; \
		exit 1; \
	fi
	rm -f test/dco_pex_results.log
	rm -f test/dco_pex_analysis.log
	rm -f test/tt_um_chrbirks_top_pex.spice
	rm -f test/tb_dco_pex.raw
	python3 scripts/remap_spice_ports.py $(EXTRACTED) $(STDCELL_SPICE) $(TEST_DIR)/tt_um_chrbirks_top_pex.spice
	cd $(TEST_DIR) && ngspice -b tb_dco_pex.spice -o dco_pex_results.log
	@echo "Simulation log in $(TEST_DIR)/dco_pex_results.log"
	@echo "Waveform in $(TEST_DIR)/tb_dco_pex.raw"
	@echo "Run 'make pex-sim-analysis' to measure frequencies."

pex-sim-analysis:
	@if [ ! -f "$(TEST_DIR)/tb_dco_pex.raw" ]; then \
		echo "ERROR: $(TEST_DIR)/tb_dco_pex.raw not found. Run 'make pex-sim' first."; \
		exit 1; \
	fi
	rm -f test/dco_pex_analysis.log
	cd $(TEST_DIR) && ngspice tb_dco_pex_analysis.spice -o dco_pex_analysis.log
	@echo "Analysis results in $(TEST_DIR)/dco_pex_analysis.log"

clean:
	rm -f ./synth_$(TOP).v ./adpll_tb ./abc.history ./adpll.vcd
	rm -rf ./runs/
