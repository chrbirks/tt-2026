# ADPLL Makefile — iverilog simulation + yosys synthesis

TOP         = tt_um_chrbirks_top
SRC_DIR     = ../src
TEST_DIR    = .
VERILOG_LIB ?= ../IHP-Open-PDK/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_udp.v \
               ../IHP-Open-PDK/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v
SRC_FILES   = $(SRC_DIR)/bb_phase_detector.sv \
              $(SRC_DIR)/digital_loop_filter.sv \
              $(SRC_DIR)/freq_divider.sv \
              $(SRC_DIR)/tt_um_chrbirks_top.sv
SIM_DCO     = $(SRC_DIR)/ring_osc_dco_sim_model.sv
TB          = $(TEST_DIR)/tb_adpll.sv
SDF_DIR     = ../runs/wokwi/final/sdf
SDF_CORNER  ?= nom_typ_1p20V_25C
SDF_FILE    = $(SDF_DIR)/$(SDF_CORNER)/$(TOP)__$(SDF_CORNER).sdf

.PHONY: sim adpll_tb sim-gl sim-view sim-gl-view clean help

help:
	@echo "Targets:"
	@echo "  sim      - Compile and run RTL simulation (behavioral DCO)"
	@echo "  sim-view - View RTL simulation in GTKWave"
	@echo "  sim-gl   - Compile and run gate-level simulation"
	@echo "  sim-view - View gate-level simulation in GTKWave"
	@echo "  clean    - Remove build artifacts"

## Simulation (uses behavioral DCO model)
sim: clean adpll_tb
	vvp adpll_tb

adpll_tb: $(SRC_FILES) $(SIM_DCO) $(TB)
	iverilog -g2012 -DSIMULATION -o $@ $(SRC_FILES) $(SIM_DCO) $(TB)

## Gate-level simulation using netlist produced by the GDS flow
sim-gl: $(VERILOG_LIB)
	@if [ ! -d "../runs/wokwi/final/nl" ]; then \
		echo "ERROR: ../runs/wokwi/final/nl/ not found. Run 'make gds' first."; \
		exit 1; \
	fi
	@if [ ! -f "$(SDF_FILE)" ]; then \
		echo "ERROR: SDF file not found: $(SDF_FILE)"; \
		exit 1; \
	fi
	sed 's/\\dco_inst\./\\dco_inst__/g' ../runs/wokwi/final/nl/$(TOP).nl.v > $(TOP).nl.v
	./filter_sdf.sh $(SDF_FILE) > $(TOP).filtered.sdf
	iverilog -g2012 -gspecify -Ttyp -DGL_SIMULATION \
		-DSDF_FILE=\"$(TOP).filtered.sdf\" \
		-o $@ $(VERILOG_LIB) $(TOP).nl.v $(TB)
	vvp sim-gl

## Waveform viewers
sim-view: adpll.vcd
	gtkwave adpll.vcd &

sim-gl-view: adpll_gl.vcd
	gtkwave adpll_gl.vcd &

clean:
	rm -f ./transcript ./*.log ./adpll_tb ./adpll.vcd ./adpll_gl.vcd ./sim-gl ./$(TOP).nl.v ./$(TOP).filtered.sdf
