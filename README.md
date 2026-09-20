# HWSW Project

Benchmarks selected: **nbody**, **pyflate**

## Repository structure

```
hwsw-project/
├── README.md
├── prompt.docx
├── .gitignore
├── src/
│   ├── nbody/
│       ├── report_nbody.pdf              - report
│   │   ├── script_nbody.sh               - reproduces every nbody measurement end-to-end
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
│       ├── report_pyflate.pdf            - report
│       ├── script_pyflate.sh             - reproduces every pyflate measurement end-to-end
│       ├── software/
│       │   ├── pyflate_original.py       - baseline (pyperformance bm_pyflate, Paul Sladen)
│       │   ├── pyflate_lookup.py         - optimization 1: O(1) Huffman symbol lookup
│       │   ├── pyflate_v2_lookup_mtf.py  - optimization 2: + faster move_to_front
│       │   ├── cprofile_wrapper_baseline.py - single-process cProfile wrapper
│       │   ├── flamegraph_wrapper.py     - repeats decode N times so py-spy samples well
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
    │   ├── perf_stat_baseline.txt / perf_stat_numba.txt                 - perf stat 
    │   ├── perf_stat_baseline_singlerun.txt / perf_stat_numba_singlerun.txt
    │   │       - perf stat, single-process apples-to-apples comparison (see Methodology notes)
    │   ├── baseline_flame.svg / numba_flame.svg                         - py-spy flame graphs
    │   └── optimization_unrolled.txt / run_v2_full_output.txt           - full run output logs 
    └── pyflate/
        ├── baseline.json / v1_lookup.json / v2_lookup_mtf.json          - pyperf raw results
        ├── compare_v1_lookup.txt / compare_v2_lookup_mtf.txt            - pyperf compare_to output
        ├── cprofile_baseline.txt / pyflate_profile_baseline.prof        - cProfile output
        └── baseline_flame.svg / v2_lookup_mtf_flame.svg                 - py-spy flame graphs
```


## Environment setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install pyperf numpy numba py-spy
```

A SystemVerilog simulator  - neither design was run through a simulator in this submission

## Quick start

```bash
./src/nbody/script_nbody.sh      # runs and measures all 4 nbody variants + flame graphs
./src/pyflate/script_pyflate.sh  # runs and measures all 3 pyflate variants + flame graphs
```

Each script installs its own dependencies, runs `pyperf system tune`,
measures every variant with `pyperf compare_to`, and regenerates the flame
graphs. Run `python -m pyperf system reset` afterward to undo the system
tuning.

## Benchmark 1: nbody

**Source**: pyperformance's `bm_nbody` - 5-body solar-system gravity
simulation, 20,000 iterations, pure Python in the original.

### Software results

| Optimization | Result | Verdict |
|---|---|---|
| Baseline | 229-231 ms +/- 3-5 ms | - |
| 1. Manual loop unrolling | 231 ms +/- 4-5 ms | Not statistically significant |
| 2. `sqrt()` instead of `** -1.5` | 239-242 ms +/- 3-8 ms | 1.04-1.05x **slower** |
| 3. Numba JIT (`@njit`, NumPy arrays) | 9.24 ms +/- 0.12 ms | **24.82-24.95x faster** |

All optimizations verified correct against the original's `report_energy()`
output (differences of 0.0 or floating-point rounding noise only). Full
analysis, flame graphs, and discussion in `results/nbody/report_nbody_final.pdf`.

### Hardware

`src/nbody/hardware/`: a sequential 7-state FSM (`nbody_controller.sv`)
drives `nbody_datapath.sv` through all 10 body-pair force computations and
the position-update step, autonomously repeating for the full iteration
count once started. Arithmetic is 64-bit IEEE-754 double, expressed
behaviorally via SystemVerilog `real`/`$sqrt`/`$bitstoreal` (a
simulation-only stand-in for synthesizable floating-point IP blocks).

**Status: not run through a simulator in this submission.** Presented as
a logically-consistent architectural description.

## Benchmark 2: pyflate

**Source**: pyperformance's `bm_pyflate` - pure-Python bzip2/gzip
decompressor (Paul Sladen, 2006-2007), decompressing `data/interpreter.tar.bz2`.

### Software results

cProfile on the baseline showed `find_next_symbol()` (Huffman symbol
decode) responsible for ~49.6% of total runtime - a linear scan over the
entire Huffman table for every symbol decoded.

| Optimization | Result | Verdict |
|---|---|---|
| Baseline | 1.12 sec +/- 0.01 sec | - |
| 1. `find_next_symbol()`: O(1) dict lookup | 1.07 sec +/- 0.01 sec | 1.05x faster (~5%) - not enough alone |
| 2. + `move_to_front()`: `pop`/`insert` instead of list slicing | 0.887 sec +/- 0.006 sec | **1.26x faster (~20.8%)** - exceeds the 7% target |

Both optimized versions verified byte-identical to the original on a
reference bzip2 stream, and pass the benchmark's own internal MD5 check
against the real input file. Full analysis, flame graphs, and discussion
in `results/pyflate/report_pyflate.docx`.

### Hardware

`src/pyflate/hardware/`: a 9-state FSM (`pyflate_controller.sv`) drives
`pyflate_datapath.sv`, which shifts in one input bit at a time, and wires
two hardware realizations of the two software optimizations above:
- `huffman_lookup.sv` - a parallel, CAM-style symbol match against up to
  512 table entries simultaneously (single-cycle O(1) latency), the
  hardware counterpart of the software's dict-based lookup.
- `move_to_front.sv` - a single-cycle, 256-entry list shift, the hardware
  counterpart of the software's `pop`/`insert` fix.


**Status: not run through a simulator in this submission.** Presented as
a logically-consistent architectural description.



