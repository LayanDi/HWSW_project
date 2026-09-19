"""
N-body benchmark - NUMBA JIT VERSION (optimization #3)

Based on pyperformance's bm_nbody (Computer Language Benchmarks Game).

Optimization #1 (manual unroll) and #2 (sqrt instead of **-1.5) both stayed
inside pure CPython and showed no real improvement (not significant / 1.05x
slower) -> the bottleneck is CPython's own interpreter overhead (bytecode
dispatch, dynamic type checks, float boxing/unboxing on every operation),
not the arithmetic formula or loop structure itself.

This version removes that overhead entirely: positions/velocities/masses
are stored as NumPy float64 arrays (numba's nopython mode requires static,
uniform types - it cannot compile Python lists of mixed nested lists), and
advance()/report_energy() are compiled ahead-of-first-call to native
machine code via @numba.njit (== @numba.jit(nopython=True)). Inside the
compiled function there is no per-operation interpreter round-trip at all.

Body order (fixed, matches original BODIES dict insertion order):
    0 = sun, 1 = jupiter, 2 = saturn, 3 = uranus, 4 = neptune
The pair loop (i in 0..3, j in i+1..4) visits pairs in exactly the same
order as the original combinations()-based pairs list, so results are
directly comparable.
"""
import numpy as np
import numba
import pyperf

__contact__ = "collinwinter@google.com (Collin Winter)"

DEFAULT_ITERATIONS = 20000
DEFAULT_REFERENCE = 'sun'

PI = 3.14159265358979323
SOLAR_MASS = 4 * PI * PI
DAYS_PER_YEAR = 365.24

BODY_NAMES = ['sun', 'jupiter', 'saturn', 'uranus', 'neptune']
BODY_INDEX = {name: i for i, name in enumerate(BODY_NAMES)}

# positions[i] = [x, y, z], velocities[i] = [vx, vy, vz], masses[i] = m
INITIAL_POSITIONS = np.array([
    [0.0, 0.0, 0.0],
    [4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01],
    [8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01],
    [1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01],
    [1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01],
], dtype=np.float64)

INITIAL_VELOCITIES = np.array([
    [0.0, 0.0, 0.0],
    [1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05],
    [-2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05],
    [2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05],
    [2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05],
], dtype=np.float64) * DAYS_PER_YEAR

MASSES = np.array([
    SOLAR_MASS,
    9.54791938424326609e-04 * SOLAR_MASS,
    2.85885980666130812e-04 * SOLAR_MASS,
    4.36624404335156298e-05 * SOLAR_MASS,
    5.15138902046611451e-05 * SOLAR_MASS,
], dtype=np.float64)

N_BODIES = 5


@numba.njit(cache=True)
def advance(dt, n, pos, vel, mass):
    for _ in range(n):
        for i in range(N_BODIES - 1):
            for j in range(i + 1, N_BODIES):
                dx = pos[i, 0] - pos[j, 0]
                dy = pos[i, 1] - pos[j, 1]
                dz = pos[i, 2] - pos[j, 2]
                d2 = dx * dx + dy * dy + dz * dz
                mag = dt * (d2 ** (-1.5))
                b1m = mass[i] * mag
                b2m = mass[j] * mag
                vel[i, 0] -= dx * b2m
                vel[i, 1] -= dy * b2m
                vel[i, 2] -= dz * b2m
                vel[j, 0] += dx * b1m
                vel[j, 1] += dy * b1m
                vel[j, 2] += dz * b1m

        for i in range(N_BODIES):
            pos[i, 0] += dt * vel[i, 0]
            pos[i, 1] += dt * vel[i, 1]
            pos[i, 2] += dt * vel[i, 2]


@numba.njit(cache=True)
def report_energy(pos, vel, mass):
    e = 0.0
    for i in range(N_BODIES - 1):
        for j in range(i + 1, N_BODIES):
            dx = pos[i, 0] - pos[j, 0]
            dy = pos[i, 1] - pos[j, 1]
            dz = pos[i, 2] - pos[j, 2]
            e -= (mass[i] * mass[j]) / ((dx * dx + dy * dy + dz * dz) ** 0.5)

    for i in range(N_BODIES):
        e += mass[i] * (vel[i, 0] ** 2 + vel[i, 1] ** 2 + vel[i, 2] ** 2) / 2.0
    return e


def offset_momentum(pos, vel, mass, ref_index):
    px = py = pz = 0.0
    for i in range(N_BODIES):
        px -= vel[i, 0] * mass[i]
        py -= vel[i, 1] * mass[i]
        pz -= vel[i, 2] * mass[i]
    vel[ref_index, 0] = px / mass[ref_index]
    vel[ref_index, 1] = py / mass[ref_index]
    vel[ref_index, 2] = pz / mass[ref_index]


def bench_nbody(loops, reference, iterations):
    ref_index = BODY_INDEX[reference]

    # Fresh copies each timed run (mutable state), NOT counted in t0..t1
    pos = INITIAL_POSITIONS.copy()
    vel = INITIAL_VELOCITIES.copy()
    mass = MASSES.copy()
    offset_momentum(pos, vel, mass, ref_index)

    # Warm up / trigger JIT compilation OUTSIDE the timed region, so we
    # measure steady-state native execution, not one-time compile cost.
    advance(0.0, 0, pos, vel, mass)
    report_energy(pos, vel, mass)

    range_it = range(loops)
    t0 = pyperf.perf_counter()

    for _ in range_it:
        report_energy(pos, vel, mass)
        advance(0.01, iterations, pos, vel, mass)
        report_energy(pos, vel, mass)

    return pyperf.perf_counter() - t0


def add_cmdline_args(cmd, args):
    cmd.extend(("--iterations", str(args.iterations)))


if __name__ == '__main__':
    runner = pyperf.Runner(add_cmdline_args=add_cmdline_args)
    runner.metadata['description'] = "n-body benchmark (numba njit)"
    runner.argparser.add_argument("--iterations",
                                   type=int, default=DEFAULT_ITERATIONS,
                                   help="Number of nbody advance() iterations "
                                        "(default: %s)" % DEFAULT_ITERATIONS)
    runner.argparser.add_argument("--reference",
                                   type=str, default=DEFAULT_REFERENCE,
                                   help="nbody reference (default: %s)"
                                        % DEFAULT_REFERENCE)
    args = runner.parse_args()
    runner.bench_time_func('nbody', bench_nbody,
                            args.reference, args.iterations)
