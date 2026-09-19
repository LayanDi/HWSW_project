"""
Wrapper for py-spy flame graphs: a single decode of interpreter.tar.bz2
takes only ~1.1s, which isn't long enough for py-spy's default 100Hz
sampling to gather a rich flame graph. This wrapper repeats the decode
REPEATS times in a single process so py-spy has enough wall-clock time
to sample well - mirroring the --iterations bump used for nbody's numba
flame graph.

Usage:
    py-spy record -o baseline_flame.svg -- python flamegraph_wrapper.py pyflate_original
    py-spy record -o v2_lookup_mtf_flame.svg -- python flamegraph_wrapper.py pyflate_v2_lookup_mtf
"""
import sys
import os
import importlib

REPEATS = 15  # ~15-17s total at ~1.1s/baseline decode, ~13s at ~0.89s/v2 decode

if len(sys.argv) != 2:
    print("Usage: python flamegraph_wrapper.py <module_name>")
    print("  e.g.: python flamegraph_wrapper.py pyflate_original")
    print("        python flamegraph_wrapper.py pyflate_lookup")
    print("        python flamegraph_wrapper.py pyflate_v2_lookup_mtf")
    sys.exit(1)

module_name = sys.argv[1]
mod = importlib.import_module(module_name)

filename = os.path.join(os.path.dirname(os.path.abspath(mod.__file__)),
                         "data", "interpreter.tar.bz2")

for i in range(REPEATS):
    dt = mod.bench_pyflake(1, filename)
    print(f"[{i+1}/{REPEATS}] decoded in {dt:.3f}s")
