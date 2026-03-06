# Educational ADPLL for IHP SG13G2 130nm

An All-Digital Phase-Locked Loop (ADPLL) designed for the IHP SG13G2 130nm PDK, targeting fabrication through the [Tiny Tapeout](https://www.tinytapeout.com) program.

This is the simplest possible ADPLL — under 300 lines of RTL — intended to teach PLL fundamentals while remaining synthesizable with Yosys + OpenROAD against the SG13G2 standard cell library.

## Architecture

```
ref_clk ──►[Bang-Bang PD]──► early/late ──►[Loop Filter]──► freq_ctrl[6:0]
                ▲                              (up/down counter)     │
                │                                                    ▼
           [Divider /N] ◄── dco_clk ◄──────────[Ring Osc DCO] ──► clk_out
```

**Operating principle:** The bang-bang phase detector compares the divided DCO output against the reference clock. If the DCO is too fast, the loop filter decrements `freq_ctrl` (adding delay stages, slowing the DCO). If too slow, it increments. At lock, `freq_ctrl` dithers by +/-1 around the target value.

**Target specs:**
- Reference clock: 5-10 MHz
- DCO range: ~300-600 MHz (7-stage ring oscillator)
- Output clock: ~40-75 MHz (with /8 divider)
- Division ratio: parameterizable (default 8)

## Modules

| Module                | File                            | Description                                                                                                                                               |
|-----------------------|---------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `bb_phase_detector`   | `src/bb_phase_detector.sv`      | Single D-FF sampling `clk_fb` on `clk_ref` rising edge. Outputs `early` signal.                                                                           |
| `digital_loop_filter` | `src/digital_loop_filter.sv`    | 7-bit saturating up/down counter. Resets to midpoint (64).                                                                                                |
| `ring_osc_dco`        | `src/ring_osc_dco.sv`           | Gate-level 7-stage ring oscillator using `sg13g2_inv_1` and `sg13g2_mux2_1` cells directly. Per-stage switchable delay path controlled by `freq_ctrl[i]`. |
| `ring_osc_dco` (sim)  | `src/ring_osc_dco_sim_model.sv` | Behavioral DCO model for simulation (gate-level has zero delay in Verilog simulators). Maps `freq_ctrl` to a time delay.                                  |
| `freq_divider`        | `src/freq_divider.sv`           | Parameterized divide-by-N counter with 50% duty cycle output.                                                                                             |
| `tt_um_chrbirks_top`  | `src/tt_um_chrbirks_top.sv`     | Top-level wiring + lock detector (4-bit shift register checking for alternating early/late pattern).                                                      |

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
│   ├── tt_um_chrbirks_top.sv                 Top-level + lock detector
│   ├── bb_phase_detector.sv         Bang-bang phase detector
│   ├── digital_loop_filter.sv       Saturating up/down counter
│   ├── ring_osc_dco.sv              Gate-level DCO (sg13g2 cells)
│   ├── ring_osc_dco_sim_model.sv    Behavioral DCO for simulation
│   └── freq_divider.sv              Divide-by-N
├── test/
│   └── tb_adpll.sv                  Testbench with frequency measurement
├── Makefile
├── CLAUDE.md
└── README.md
```

## Quick Start

### Prerequisites

- [Icarus Verilog](https://github.com/steveicarus/iverilog) (`iverilog`, `vvp`) for simulation
- [GTKWave](https://gtkwave.sourceforge.net/) for waveform viewing (optional)
- [Yosys](https://github.com/YosysHQ/yosys) + IHP SG13G2 PDK for synthesis

### Simulate

```sh
cd test/
make sim
```

Compiles with `-DSIMULATION` to use the behavioral DCO model. Runs a 10 MHz reference clock, waits for lock, and measures the output frequency.

### View Waveforms

```sh
cd test/
make sim-view
```

Opens `adpll.vcd` in GTKWave. Key signals to observe:
- `freq_ctrl` — should converge from 64 to a stable value
- `clk_out` — divided DCO output
- `locked` — asserts when alternating early/late pattern detected
- `early` — phase detector output

### Synthesize

```sh
source sourceme.sh
python -m venv .venv
source .venv/bin/activate
make synth
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

```sh
make gds
```

#### With locally installed tools

```sh
GDS_EXTRA_ARGS=--no-docker make gds
```


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

  Most useful signal combinations

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

## Simulation Results

With a 10 MHz reference and DIV_RATIO=8:

- `freq_ctrl` starts at 64 (midpoint), converges to ~47-48
- Lock acquired in ~40 us (~400 reference cycles)
- Measured output: ~55 MHz (behavioral model approximation)
- Steady-state: `freq_ctrl` dithers +/-1, confirming proper bang-bang operation

The behavioral model uses approximate delay parameters. On real silicon, the SG13G2 inverter delays (~80-120 ps) would produce a different absolute frequency, but the loop dynamics are the same.

## License

See repository for license details.
