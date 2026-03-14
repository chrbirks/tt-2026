# All-digital PLL

An All-Digital Phase-Locked Loop (ADPLL) designed for the IHP SG13G2 130nm PDK, targeting fabrication through the [Tiny Tapeout](https://www.tinytapeout.com) program.

## Architecture

```
ref_clk ──►[Bang-Bang PD]──► early/late ──►[Loop Filter]──► freq_ctrl[6:0]
                ▲                        (up/down counter)           │
                │                                                    ▼
           [Divider /8] ◄── dco_clk ◄─────────────────────────[Ring Osc DCO] ──► clk_out
```

**Operating principle:** The bang-bang phase detector compares the divided DCO output against the reference clock. If the DCO is too fast, the loop filter decrements `freq_ctrl` (adding delay stages, slowing the DCO). If too slow, it increments. At lock, `freq_ctrl` dithers by +/-1 around the target value.

**Target specs:**
- Reference clock: 5-10 MHz
- DCO range: ~300-600 MHz (7-stage ring oscillator)
- Output clock: ~40-75 MHz (with /8 divider)
- Division ratio: parameterizable (default 8)

## Modules

| Module                | File                           | Description                                                                                                                                               |
|-----------------------|--------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `bb_phase_detector`   | `src/bb_phase_detector.v`      | Single D-FF sampling `clk_fb` on `clk_ref` rising edge. Outputs `early` signal.                                                                           |
| `digital_loop_filter` | `src/digital_loop_filter.v`    | 7-bit saturating up/down counter. Resets to midpoint (64).                                                                                                |
| `ring_osc_dco`        | `src/ring_osc_dco.v`           | Gate-level 7-stage ring oscillator using `sg13g2_inv_1` and `sg13g2_mux2_1` cells directly. Per-stage switchable delay path controlled by `freq_ctrl[i]`. |
| `ring_osc_dco` (sim)  | `src/ring_osc_dco_sim_model.v` | Behavioral DCO model for simulation (gate-level has zero delay in Verilog simulators). Maps `freq_ctrl` to a time delay.                                  |
| `freq_divider`        | `src/freq_divider.v`           | Parameterized divide-by-N counter with 50% duty cycle output.                                                                                             |
| `tt_um_chrbirks_top`  | `src/tt_um_chrbirks_top.v`     | Top-level wiring + lock detector (4-bit shift register checking for alternating early/late pattern).                                                      |

### DCO Detail

The DCO is the only gate-level module — it directly instantiates SG13G2 standard cells to prevent Yosys from optimizing away the ring oscillator structure. Each of the 7 stages contains:

1. A mandatory inverter (`sg13g2_inv_1`) — always in the signal path
2. An optional delay pair (2 extra inverters) selected by a MUX (`sg13g2_mux2_1`)
3. `freq_ctrl[i]=0` bypasses the delay (fast path), `freq_ctrl[i]=1` routes through the extra inverters (slow path)

An enable MUX at the feedback point forces a constant input when `enable=0`, breaking oscillation. All internal wires use `(* keep *)` attributes.

## File Structure

```
tt2026/
├── src/
│   ├── tt_um_chrbirks_top.v                 Top-level + lock detector
│   ├── bb_phase_detector.v         Bang-bang phase detector
│   ├── digital_loop_filter.v       Saturating up/down counter
│   ├── ring_osc_dco.v              Gate-level DCO (sg13g2 cells)
│   ├── ring_osc_dco_sim_model.v    Behavioral DCO for simulation
│   └── freq_divider.v              Divide-by-N
├── test/
│   ├── tb_adpll.v                  Testbench with frequency measurement
│   └── filter_sdf.sh               SDF filter for iverilog compatibility
├── Makefile
├── CLAUDE.md
└── README.md
```

## Quick Start

### Prerequisites

- [Icarus Verilog](https://github.com/steveicarus/iverilog) (`iverilog`, `vvp`) for simulation
- [GTKWave](https://gtkwave.sourceforge.net/) for waveform viewing (optional)
- [Yosys](https://github.com/YosysHQ/yosys) + IHP SG13G2 PDK for synthesis

### RTL simulation

```sh
cd test/
python -m venv .venv
source .venv/bin/activate
make sim
```

Compiles with `-DSIMULATION` to use the behavioral DCO model. Runs a 10 MHz reference clock, waits for lock, and measures the output frequency.

### View RTL waveforms

```sh
make sim-view
```

Opens `adpll.vcd` in GTKWave. Key signals to observe:
- `freq_ctrl` — should converge from 64 to a stable value
- `clk_out` — divided DCO output
- `locked` — asserts when alternating early/late pattern detected
- `early` — phase detector output

### Synthesize

For debugging only since the GDS flow will be the one actually producing GDS files.

```sh
source sourceme.sh
python -m venv .venv
source .venv/bin/activate
make synth
make synth-check
make synth-stat
make synth-show
```

Runs Yosys with the SG13G2 liberty file. Outputs `synth_tt_um_chrbirks_top.v` and gate count statistics.

### GDS flow

Set up environment first:
```sh
source sourceme.sh
python -m venv .venv
source .venv/bin/activate
```

#### With tool support from docker

This clones and uses the Tiny Tapeout repo: https://github.com/TinyTapeout/tt-support-tools

```sh
make gds-setup gds
```

#### Or - With locally installed tools

This assumes that the tools used by the Tiny Tapeout flow are already installed locally.
The easiest way is to run it in a IIC-OSIC-TOOLS container (see https://github.com/iic-jku/IIC-OSIC-TOOLS )

```sh
GDS_EXTRA_ARGS=--no-docker make gds-setup gds
```

#### Post-GDS tools

To get some more information about the results of the GDS flow, use some of these tools:

 ┌────────────┬────────────────────────────────────────────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────┐
 │    Tool    │                                        What                                    │                      How                                              │
 ├────────────┼────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
 │ Log files  │ `runs/wokwi/flow.log` (stage summary), `*/yosys-synthesis.log` (Yosys output), │ Read directly                                                         │
 │            │ `*/verilator-lint.log` (lint)                                                  │                                                                       │
 ├────────────┼────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
 │ KLayout    │ GDS layout viewer (post-P&R)                                                   │ `klayout runs/wokwi/final/klayout_gds/tt_um_chrbirks_top.klayout.gds` │
 ├────────────┼────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
 │ Magic      │ DRC, extraction, cross-section view                                            │ magic -T $PDK_ROOT/ihp-sg13g2/libs.tech/magic/ihp-sg13g2.magicrc then │
 │            │                                                                                │ File -> Read GDS -> runs/wokwi/final/gds/tt_um_chrbirks_top.gds       │
 ├────────────┼────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────┤
 │ OpenSTA    │ Timing paths, setup/hold analysis on your post-P&R netlist                     │ sta then source the SDC/netlist from runs/wokwi/                      │
 │            │                                                                                │               runs/wokwi/final/nl/tt_um_chrbirks_top.nl.v             │
 │            │                                                                                │               runs/wokwi/final/pnl/tt_um_chrbirks_top.pnl.v           │
 └────────────┴────────────────────────────────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────┘

### Gate-Level Simulation (with SDF timing)

After running the GDS flow (`make gds`), you can simulate the post-place-and-route netlist with extracted timing delays:

```sh
source sourceme.sh
python -m venv .venv
source .venv/bin/activate
cd test/
make sim-gl                 # typical corner (1.20V, 25C)
make sim-gl-view            # open waveform
```

This uses SDF back-annotation to inject real parasitic delays extracted from the layout into the gate-level netlist. Without SDF delays, the ring oscillator's combinational feedback loop would hang the simulator at zero time.

Three PVT corners are available from the GDS flow:

```sh
make sim-gl SDF_CORNER=nom_typ_1p20V_25C     # typical (default)
make sim-gl SDF_CORNER=nom_fast_1p32V_m40C   # fast
make sim-gl SDF_CORNER=nom_slow_1p08V_125C   # slow
```

The Makefile runs `filter_sdf.sh` to patch the OpenSTA-generated SDF for iverilog compatibility (strips INTERCONNECT/COND entries, fixes escaped hierarchy names in the flattened netlist). The filtered SDF is passed to `$sdf_annotate` in the testbench via the `GL_SIMULATION` define.

### Post-extraction simulation

NOTE: Only seems to work without errors when using the IIC-OSIC-TOOLS container!

Run manually:
```sh
cd test
ngspice tb_dco_pex.spice

# Clock output vs reference clock
plot v("uo_out[0]") v(clk)
# Lock indicator
plot v("uo_out[1]")
# freq_ctrl[6:0] - watch it converge from midpoint
plot v("uio_out[6]") v("uio_out[5]") v("uio_out[4]") v("uio_out[3]") v("uio_out[2]") v("uio_out[1]") v("uio_out[0]")
# Zoom into DCO oscillation (internal node, if accessible)
plot v("uo_out[0]") xlimit 400n 500n
```

Or run with Make:
```sh
make pex-sim
make pex-sim-analysis
cd test
ngspice
load tb_dco_pex.raw

plot v("uo_out[0]") v(clk)
plot v("uio_out[6]") v("uio_out[5]") v("uio_out[4]") v("uio_out[3]")

# With GTKWave (if you prefer)
# ngspice .raw files aren't directly compatible with GTKWave (which expects VCD). You can convert inside ngspice:
write tb_dco_pex.vcd v("uo_out[0]") v("uo_out[1]") v(clk)
```

Some useful signal combinations

┌────────────────────┬───────────────────────────────────────────────┬────────────────────────────────────────────────────────┐
│  What to observe   │                   Signals                     │                    What you'll see                     │
├────────────────────┼───────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
│ Lock acquisition   │ v("uo_out[0]") + v(clk)                       │ clk_out aligning with ref_clk edges                    │
├────────────────────┼───────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
│ Loop convergence   │ v("uio_out[6]") through v("uio_out[0]")       │ freq_ctrl bits settling from midpoint (64)             │
├────────────────────┼───────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
│ Lock detection     │ v("uo_out[1])"                                │ Goes high when alternating early/late pattern detected │
├────────────────────┼───────────────────────────────────────────────┼────────────────────────────────────────────────────────┤
│ Phase relationship │ v("uo_out[0])" + v(clk) with xlimit 400n 500n │ Zoomed-in phase alignment at steady state              │
└────────────────────┴───────────────────────────────────────────────┴────────────────────────────────────────────────────────┘


### Clean

```sh
make clean
```

