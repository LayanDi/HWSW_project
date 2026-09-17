"""
Single-process wrapper for the ORIGINAL nbody benchmark, structured
identically to perf_wrapper_numba.py so perf stat numbers are directly
comparable (same REPEATS, same single-process measurement, no pyperf
multi-worker spawning on either side).

Usage:
    perf stat -e cache-references,cache-misses,cycles,instructions \
        python perf_wrapper_baseline.py
"""
import time
import nbody_original as orig

REPEATS = 20  # must match perf_wrapper_numba.py

orig.offset_momentum(orig.BODIES[orig.DEFAULT_REFERENCE])

t0 = time.perf_counter()
for _ in range(REPEATS):
    orig.report_energy()
    orig.advance(0.01, orig.DEFAULT_ITERATIONS)
    orig.report_energy()
t1 = time.perf_counter()

print(f"Steady-state mean per loop: {(t1 - t0) / REPEATS * 1000:.3f} ms")
