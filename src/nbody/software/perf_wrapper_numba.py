"""
Wrapper for perf stat: measure ONLY the steady-state (already-JIT-compiled)
execution of nbody_numba, in a single process, with no pyperf multi-worker
process spawning. This avoids counting numba's JIT compilation overhead
multiple times (once per pyperf worker process), which otherwise dominates
process-level perf stat / perf record measurements for JIT-compiled code.

Usage:
    perf stat -e cache-references,cache-misses,cycles,instructions \
        python perf_wrapper_numba.py
"""
import time
import nbody_numba as nb

REPEATS = 20  # repeat the timed loop body a few times for a stable measurement

pos = nb.INITIAL_POSITIONS.copy()
vel = nb.INITIAL_VELOCITIES.copy()
mass = nb.MASSES.copy()
nb.offset_momentum(pos, vel, mass, 0)

# Trigger JIT compilation here, BEFORE perf stat's measurement window
# conceptually "matters" - though perf stat measures the whole process
# either way, we now only compile ONCE total (single process), not once
# per pyperf worker.
nb.advance(0.0, 0, pos, vel, mass)
nb.report_energy(pos, vel, mass)

t0 = time.perf_counter()
for _ in range(REPEATS):
    nb.report_energy(pos, vel, mass)
    nb.advance(0.01, nb.DEFAULT_ITERATIONS, pos, vel, mass)
    nb.report_energy(pos, vel, mass)
t1 = time.perf_counter()

print(f"Steady-state mean per loop: {(t1 - t0) / REPEATS * 1000:.3f} ms")
