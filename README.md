# HWSW Project: Benchmark Optimization, Analysis, and Hardware Acceleration

Course: ECE882 (HWSW Co-Design)
Benchmarks selected: **nbody**, **pyflate**

## Repository structure

```
hwsw-project/
├── README.md
├── src/
│   ├── nbody/
│   │   ├── software/
│   │   │   ├── nbody_original.py         - baseline (pyperformance bm_nbody)
│   │   │   ├── nbody_unrolled.py         - optimization 1: manual loop unrolling
│   │   │   ├── nbody_unrolled_sqrt.py    - optimization 2: sqrt() instead of **-1.5
│   │   │   ├── nbody_numba.py            - optimization 3: numba JIT (nopython)
│   │   │   ├── perf_wrapper_baseline.py  - single-process perf stat wrapper (baseline)
│   │   │   └── perf_wrapper_numba.py     - single-process perf stat wrapper (numba)
│   │   └── hardware/
│   │       ├── nbody_datapath.sv         - body registers, force computation, position update
│   │       ├── nbody_controller.sv       - 7-state FSM sequencing all pairs and iterations
│   │       ├── nbody_accelerator.sv      - top-level (wires controller + datapath)
│   │       └── nbody_tb.sv               - testbench (not run through a simulator - see note below)
│   └── pyflate/
│       ├── software/
│       │   ├── pyflate_original.py       - baseline (pyperformance bm_pyflate, Paul Sladen)
│       │   ├── pyflate_lookup.py         - optimization 1: O(1) Huffman symbol lookup
│       │   ├── pyflate_v2_lookup_mtf.py  - optimization 2: + faster move_to_front
│       │   ├── cprofile_wrapper_baseline.py - single-process cProfile wrapper
│       │   └── data/interpreter.tar.bz2  - benchmark input file (from pyperformance)
│       └── hardware/
│           ├── pyflate_datapath.sv       - bit shift-in register, wires lookup + MTF units
│           ├── pyflate_controller.sv     - 9-state FSM (decode one symbol at a time)
│           ├── huffman_lookup.sv         - parallel (CAM-style) O(1) Huffman symbol match
│           ├── move_to_front.sv          - single-cycle 256-entry MTF list shift
│           ├── pyflate_mmio.sv           - memory-mapped CONTROL/STATUS/OUTPUT registers
│           ├── pyflate_accelerator.sv    - top-level (wires controller + datapath)
│           └── pyflate_tb.sv             - testbench (not run through a simulator - see note below)
└── results/
    ├── nbody/
    │   ├── baseline.json / unrolled.json / v2_sqrt.json / numba.json   - pyperf raw results
    │   ├── compare_unroll.txt / compare_v2.txt / compare_numba.txt     - pyperf compare_to output
    │   ├── perf_report_nbody.txt                                       - perf report (python3-dbg)
    │   ├── perf_stat_baseline.txt / perf_stat_numba.txt                 - perf stat (pyperf multi-process run)
    │   ├── perf_stat_baseline_singlerun.txt / perf_stat_numba_singlerun.txt
    │   │       - perf stat, single-process apples-to-apples comparison (see Methodology notes)
    │   ├── baseline_flame.svg / numba_flame.svg                         - py-spy flame graphs
    │   ├── optimization_unrolled.txt / run_v2_full_output.txt           - full run output logs
    │   └── report_nbody.txt                                             - final written report
    └── pyflate/
        ├── baseline.json / v1_lookup.json / v2_lookup_mtf.json          - pyperf raw results
        ├── compare_v1_lookup.txt / compare_v2_lookup_mtf.txt            - pyperf compare_to output
        ├── cprofile_baseline.txt / pyflate_profile_baseline.prof        - cProfile output
        └── report_pyflate.txt                                          - final written report (TODO)
```

## Environment setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install pyperf numpy numba
```

A SystemVerilog simulator (e.g. `apt install iverilog`) is only needed if
you choose to simulate the hardware designs - see the note below.

## Benchmark 1: nbody

**Source**: pyperformance's `bm_nbody` - 5-body solar-system gravity
simulation, 20,000 iterations, pure Python in the original.

### Software - how to run each version

```bash
cd src/nbody/software
python nbody_original.py -o ../../../results/nbody/baseline.json --values 15 --loops 4
python nbody_unrolled.py -o ../../../results/nbody/unrolled.json --values 15 --loops 4
python nbody_unrolled_sqrt.py -o ../../../results/nbody/v2_sqrt.json --values 15 --loops 4
python nbody_numba.py -o ../../../results/nbody/numba.json --values 15 --loops 4   # requires numba

python -m pyperf compare_to results/nbody/baseline.json results/nbody/<variant>.json
```

Single-process perf stat comparison (bypasses pyperf's multi-worker
process spawning, which otherwise double-counts numba's JIT compilation
once per worker - see Methodology notes below):
```bash
perf stat -e cache-references,cache-misses,cycles,instructions python perf_wrapper_baseline.py
perf stat -e cache-references,cache-misses,cycles,instructions python perf_wrapper_numba.py
```

### Software results

| Optimization | Result | Verdict |
|---|---|---|
| Baseline | 229-231 ms +/- 3-5 ms | - |
| 1. Manual loop unrolling | 231 ms +/- 4-5 ms | Not statistically significant |
| 2. `sqrt()` instead of `** -1.5` | 239-242 ms +/- 3-8 ms | 1.04-1.05x **slower** |
| 3. Numba JIT (`@njit`, NumPy arrays) | 9.24 ms +/- 0.12 ms | **24.82-24.95x faster** |

All optimizations verified correct against the original's `report_energy()`
output (differences of 0.0 or floating-point rounding noise only).

### Hardware

`src/nbody/hardware/`: a sequential 7-state FSM (`nbody_controller.sv`)
drives `nbody_datapath.sv` through all 10 body-pair force computations and
the position-update step, autonomously repeating for the full iteration
count once started. Arithmetic is 64-bit IEEE-754 double, expressed
behaviorally via SystemVerilog `real`/`$sqrt`/`$bitstoreal` (a simulation-only
stand-in for synthesizable floating-point IP blocks - see
`results/nbody/report_nbody.txt` Section 5 for the full design description
and the precision/area/throughput trade-offs this implies).

**Status: this design has not been run through a simulator in this
submission.** It is presented as a logically-consistent architectural
description, per the assignment's note that synthesis, fabrication, and
physical testing are not expected.

## Benchmark 2: pyflate

**Source**: pyperformance's `bm_pyflate` - pure-Python bzip2/gzip
decompressor (Paul Sladen, 2006-2007), decompressing `data/interpreter.tar.bz2`.

### Software - how to run each version

```bash
cd src/pyflate/software
python pyflate_original.py -o ../../../results/pyflate/baseline.json --loops 1 --values 15
python pyflate_lookup.py -o ../../../results/pyflate/v1_lookup.json --loops 1 --values 15
python pyflate_v2_lookup_mtf.py -o ../../../results/pyflate/v2_lookup_mtf.json --loops 1 --values 15

python -m pyperf compare_to results/pyflate/baseline.json results/pyflate/<variant>.json
```

Profiling (bypasses pyperf's multi-process runner - see Methodology notes):
```bash
python cprofile_wrapper_baseline.py
```

### Software results

cProfile on the baseline showed `find_next_symbol()` (Huffman symbol
decode) responsible for ~49.6% of total runtime - a linear scan over
the entire Huffman table for every symbol decoded.

| Optimization | Result | Verdict |
|---|---|---|
| Baseline | 1.12 sec +/- 0.01 sec | - |
| 1. `find_next_symbol()`: O(1) dict lookup | 1.07 sec +/- 0.01 sec | 1.05x faster (~5%) - not enough alone |
| 2. + `move_to_front()`: `pop`/`insert` instead of list slicing | 0.887 sec +/- 0.006 sec | **1.26x faster (~20.8%)** - exceeds the 7% target |

Both optimized versions verified byte-identical to the original on a
reference bzip2 stream, and pass the benchmark's own internal MD5 check
against the real input file.

### Hardware

`src/pyflate/hardware/`: a 9-state FSM (`pyflate_controller.sv`) drives
`pyflate_datapath.sv`, which shifts in one input bit at a time into
`code_value`/`code_length`, and wires two hardware realizations of the
two software optimizations above:
- `huffman_lookup.sv` - a parallel, CAM-style symbol match against up to
  512 table entries simultaneously (single-cycle O(1) latency), the
  hardware counterpart of the software's dict-based lookup.
- `move_to_front.sv` - a single-cycle, 256-entry list shift, the hardware
  counterpart of the software's `pop`/`insert` fix.

`pyflate_mmio.sv` exposes three memory-mapped registers
(`CONTROL` 0x000, `STATUS` 0x008, `OUTPUT` 0x010) for `start`/`init_mtf`,
`busy`/`done`/`decoded_valid`, and the decoded symbol byte. Table entries
and input bits are loaded through separate, direct ports
(`load_table_entry`+fields, `input_bit`+`input_valid`) - one entry/bit at a
time, not via DMA or a memory interface.

A timing bug was found and fixed during design review: the bit
shift-in logic was originally gated on `load_bit && input_valid`, but the
controller asserts `load_bit` one clock cycle after observing
`input_valid`, which by then has typically already fallen (a single-cycle
pulse) - so the bit was silently never latched. Fixed by gating on
`load_bit` alone, since the controller's FSM is already the single source
of truth for when a bit is valid to consume.

**Status: this design has not been run through a simulator in this
submission.** Presented as a logically-consistent architectural
description, per the assignment's note that synthesis, fabrication, and
physical testing are not expected.

**Known limitation (documented, not fixed)**: earlier draft block
diagrams for this accelerator depicted a full memory-mapped DMA interface
(address/size registers, autonomous reads of the Huffman table and
compressed input from system memory, autonomous output writes) - the
actual RTL does not implement this; table entries and input bits must be
fed individually by the host through direct ports, and `pyflate_mmio.sv`
only implements the three registers listed above. This is a real
throughput limitation of the current design (many host-accelerator
handshakes per decoded symbol) and a candidate for future extension, not
merely a documentation gap to paper over.

## Methodology notes that apply to both benchmarks

- Always measure with `pyperf compare_to`, never eyeball means; run
  `python -m pyperf system tune` before measuring for stability (and
  `system reset` afterward when done).
- Avoid `--fast` for anything but a quick sanity check - it produces
  unstable results (pyperf's own stability warning fires reliably with it).
- When profiling or `perf stat`-ing code that runs through
  `pyperf.Runner` (which spawns worker subprocesses), measure the actual
  function directly in a single process instead (see
  `perf_wrapper_*.py` / `cprofile_wrapper_baseline.py`) - otherwise the
  measurement captures parent-process IPC/subprocess-spawn overhead (or,
  for JIT-compiled code, repeated compilation once per worker process)
  rather than the benchmark's real steady-state work.
- For JIT-compiled code (numba), trigger compilation with a warm-up call
  before the timed region - otherwise the first measured call includes
  one-time compilation latency and misrepresents steady-state speed.
- Every optimized software version in this repository was independently
  verified for correctness against the original's output before being
  accepted as a result (see each benchmark's software results above).

## AI tool usage

Prompts and instructions used with AI tools during this project are to be
documented in `prompt.txt`, per submission requirements.
**TODO: not yet completed.**

## Status / TODO

- [x] nbody: 3 software optimizations measured, verified, and documented
- [x] nbody: hardware accelerator designed (SystemVerilog, not simulated)
- [x] nbody: `report_nbody.txt` complete
- [x] pyflate: 2 software optimizations measured, verified, and documented; 7% target exceeded
- [x] pyflate: hardware accelerator designed (SystemVerilog, not simulated), one timing bug found and fixed
- [ ] pyflate: `report_pyflate.txt`
- [ ] `prompt.txt` (AI tool usage documentation, both benchmarks)
- [ ] Presentation
