"""
N-body benchmark - MANUALLY UNROLLED VERSION (optimization #1)

Based on pyperformance's bm_nbody (Computer Language Benchmarks Game).
Original: combinations() builds 10 (body_a, body_b) pairs and advance()/
report_energy() iterate + tuple-unpack them on every one of the 20,000
iterations. Since the number of bodies (5) and pairs (10) is fixed, this
version unrolls that loop into 10 explicit blocks, removing:
  - the tuple-unpacking of each pair on every iteration
  - the Python-level iteration over the `pairs` list
  - the nested-tuple unpacking of each body ((r, v, m))

Numerically, this performs the exact same operations in the exact same
order as the original -> report_energy() before/after should print
identical floating point values to the original, and perf/pyperf results
are directly comparable.
"""
import pyperf

__contact__ = "collinwinter@google.com (Collin Winter)"

DEFAULT_ITERATIONS = 20000
DEFAULT_REFERENCE = 'sun'

PI = 3.14159265358979323
SOLAR_MASS = 4 * PI * PI
DAYS_PER_YEAR = 365.24

BODIES = {
    'sun': ([0.0, 0.0, 0.0], [0.0, 0.0, 0.0], SOLAR_MASS),

    'jupiter': ([4.84143144246472090e+00,
                 -1.16032004402742839e+00,
                 -1.03622044471123109e-01],
                [1.66007664274403694e-03 * DAYS_PER_YEAR,
                 7.69901118419740425e-03 * DAYS_PER_YEAR,
                 -6.90460016972063023e-05 * DAYS_PER_YEAR],
                9.54791938424326609e-04 * SOLAR_MASS),

    'saturn': ([8.34336671824457987e+00,
                4.12479856412430479e+00,
                -4.03523417114321381e-01],
               [-2.76742510726862411e-03 * DAYS_PER_YEAR,
                4.99852801234917238e-03 * DAYS_PER_YEAR,
                2.30417297573763929e-05 * DAYS_PER_YEAR],
               2.85885980666130812e-04 * SOLAR_MASS),

    'uranus': ([1.28943695621391310e+01,
                -1.51111514016986312e+01,
                -2.23307578892655734e-01],
               [2.96460137564761618e-03 * DAYS_PER_YEAR,
                2.37847173959480950e-03 * DAYS_PER_YEAR,
                -2.96589568540237556e-05 * DAYS_PER_YEAR],
               4.36624404335156298e-05 * SOLAR_MASS),

    'neptune': ([1.53796971148509165e+01,
                 -2.59193146099879641e+01,
                 1.79258772950371181e-01],
                [2.68067772490389322e-03 * DAYS_PER_YEAR,
                 1.62824170038242295e-03 * DAYS_PER_YEAR,
                 -9.51592254519715870e-05 * DAYS_PER_YEAR],
                5.15138902046611451e-05 * SOLAR_MASS)}

SYSTEM = list(BODIES.values())

# Unpack each body once (module load time), not once per pair per iteration.
# Order matches BODIES insertion order: sun, jupiter, saturn, uranus, neptune
SUN, JUPITER, SATURN, URANUS, NEPTUNE = SYSTEM


def advance(dt, n, bodies=SYSTEM):
    (r0, v0, m0) = SUN
    (r1, v1, m1) = JUPITER
    (r2, v2, m2) = SATURN
    (r3, v3, m3) = URANUS
    (r4, v4, m4) = NEPTUNE

    for _ in range(n):
        # pair (sun, jupiter)
        dx = r0[0] - r1[0]; dy = r0[1] - r1[1]; dz = r0[2] - r1[2]
        mag = dt * ((dx * dx + dy * dy + dz * dz) ** (-1.5))
        b1m = m0 * mag; b2m = m1 * mag
        v0[0] -= dx * b2m; v0[1] -= dy * b2m; v0[2] -= dz * b2m
        v1[0] += dx * b1m; v1[1] += dy * b1m; v1[2] += dz * b1m

        # pair (sun, saturn)
        dx = r0[0] - r2[0]; dy = r0[1] - r2[1]; dz = r0[2] - r2[2]
        mag = dt * ((dx * dx + dy * dy + dz * dz) ** (-1.5))
        b1m = m0 * mag; b2m = m2 * mag
        v0[0] -= dx * b2m; v0[1] -= dy * b2m; v0[2] -= dz * b2m
        v2[0] += dx * b1m; v2[1] += dy * b1m; v2[2] += dz * b1m

        # pair (sun, uranus)
        dx = r0[0] - r3[0]; dy = r0[1] - r3[1]; dz = r0[2] - r3[2]
        mag = dt * ((dx * dx + dy * dy + dz * dz) ** (-1.5))
        b1m = m0 * mag; b2m = m3 * mag
        v0[0] -= dx * b2m; v0[1] -= dy * b2m; v0[2] -= dz * b2m
        v3[0] += dx * b1m; v3[1] += dy * b1m; v3[2] += dz * b1m

        # pair (sun, neptune)
        dx = r0[0] - r4[0]; dy = r0[1] - r4[1]; dz = r0[2] - r4[2]
        mag = dt * ((dx * dx + dy * dy + dz * dz) ** (-1.5))
        b1m = m0 * mag; b2m = m4 * mag
        v0[0] -= dx * b2m; v0[1] -= dy * b2m; v0[2] -= dz * b2m
        v4[0] += dx * b1m; v4[1] += dy * b1m; v4[2] += dz * b1m

        # pair (jupiter, saturn)
        dx = r1[0] - r2[0]; dy = r1[1] - r2[1]; dz = r1[2] - r2[2]
        mag = dt * ((dx * dx + dy * dy + dz * dz) ** (-1.5))
        b1m = m1 * mag; b2m = m2 * mag
        v1[0] -= dx * b2m; v1[1] -= dy * b2m; v1[2] -= dz * b2m
        v2[0] += dx * b1m; v2[1] += dy * b1m; v2[2] += dz * b1m

        # pair (jupiter, uranus)
        dx = r1[0] - r3[0]; dy = r1[1] - r3[1]; dz = r1[2] - r3[2]
        mag = dt * ((dx * dx + dy * dy + dz * dz) ** (-1.5))
        b1m = m1 * mag; b2m = m3 * mag
        v1[0] -= dx * b2m; v1[1] -= dy * b2m; v1[2] -= dz * b2m
        v3[0] += dx * b1m; v3[1] += dy * b1m; v3[2] += dz * b1m

        # pair (jupiter, neptune)
        dx = r1[0] - r4[0]; dy = r1[1] - r4[1]; dz = r1[2] - r4[2]
        mag = dt * ((dx * dx + dy * dy + dz * dz) ** (-1.5))
        b1m = m1 * mag; b2m = m4 * mag
        v1[0] -= dx * b2m; v1[1] -= dy * b2m; v1[2] -= dz * b2m
        v4[0] += dx * b1m; v4[1] += dy * b1m; v4[2] += dz * b1m

        # pair (saturn, uranus)
        dx = r2[0] - r3[0]; dy = r2[1] - r3[1]; dz = r2[2] - r3[2]
        mag = dt * ((dx * dx + dy * dy + dz * dz) ** (-1.5))
        b1m = m2 * mag; b2m = m3 * mag
        v2[0] -= dx * b2m; v2[1] -= dy * b2m; v2[2] -= dz * b2m
        v3[0] += dx * b1m; v3[1] += dy * b1m; v3[2] += dz * b1m

        # pair (saturn, neptune)
        dx = r2[0] - r4[0]; dy = r2[1] - r4[1]; dz = r2[2] - r4[2]
        mag = dt * ((dx * dx + dy * dy + dz * dz) ** (-1.5))
        b1m = m2 * mag; b2m = m4 * mag
        v2[0] -= dx * b2m; v2[1] -= dy * b2m; v2[2] -= dz * b2m
        v4[0] += dx * b1m; v4[1] += dy * b1m; v4[2] += dz * b1m

        # pair (uranus, neptune)
        dx = r3[0] - r4[0]; dy = r3[1] - r4[1]; dz = r3[2] - r4[2]
        mag = dt * ((dx * dx + dy * dy + dz * dz) ** (-1.5))
        b1m = m3 * mag; b2m = m4 * mag
        v3[0] -= dx * b2m; v3[1] -= dy * b2m; v3[2] -= dz * b2m
        v4[0] += dx * b1m; v4[1] += dy * b1m; v4[2] += dz * b1m

        # position updates (5 bodies)
        r0[0] += dt * v0[0]; r0[1] += dt * v0[1]; r0[2] += dt * v0[2]
        r1[0] += dt * v1[0]; r1[1] += dt * v1[1]; r1[2] += dt * v1[2]
        r2[0] += dt * v2[0]; r2[1] += dt * v2[1]; r2[2] += dt * v2[2]
        r3[0] += dt * v3[0]; r3[1] += dt * v3[1]; r3[2] += dt * v3[2]
        r4[0] += dt * v4[0]; r4[1] += dt * v4[1]; r4[2] += dt * v4[2]


def report_energy(bodies=SYSTEM, e=0.0):
    (r0, v0, m0) = SUN
    (r1, v1, m1) = JUPITER
    (r2, v2, m2) = SATURN
    (r3, v3, m3) = URANUS
    (r4, v4, m4) = NEPTUNE

    dx = r0[0] - r1[0]; dy = r0[1] - r1[1]; dz = r0[2] - r1[2]
    e -= (m0 * m1) / ((dx * dx + dy * dy + dz * dz) ** 0.5)
    dx = r0[0] - r2[0]; dy = r0[1] - r2[1]; dz = r0[2] - r2[2]
    e -= (m0 * m2) / ((dx * dx + dy * dy + dz * dz) ** 0.5)
    dx = r0[0] - r3[0]; dy = r0[1] - r3[1]; dz = r0[2] - r3[2]
    e -= (m0 * m3) / ((dx * dx + dy * dy + dz * dz) ** 0.5)
    dx = r0[0] - r4[0]; dy = r0[1] - r4[1]; dz = r0[2] - r4[2]
    e -= (m0 * m4) / ((dx * dx + dy * dy + dz * dz) ** 0.5)
    dx = r1[0] - r2[0]; dy = r1[1] - r2[1]; dz = r1[2] - r2[2]
    e -= (m1 * m2) / ((dx * dx + dy * dy + dz * dz) ** 0.5)
    dx = r1[0] - r3[0]; dy = r1[1] - r3[1]; dz = r1[2] - r3[2]
    e -= (m1 * m3) / ((dx * dx + dy * dy + dz * dz) ** 0.5)
    dx = r1[0] - r4[0]; dy = r1[1] - r4[1]; dz = r1[2] - r4[2]
    e -= (m1 * m4) / ((dx * dx + dy * dy + dz * dz) ** 0.5)
    dx = r2[0] - r3[0]; dy = r2[1] - r3[1]; dz = r2[2] - r3[2]
    e -= (m2 * m3) / ((dx * dx + dy * dy + dz * dz) ** 0.5)
    dx = r2[0] - r4[0]; dy = r2[1] - r4[1]; dz = r2[2] - r4[2]
    e -= (m2 * m4) / ((dx * dx + dy * dy + dz * dz) ** 0.5)
    dx = r3[0] - r4[0]; dy = r3[1] - r4[1]; dz = r3[2] - r4[2]
    e -= (m3 * m4) / ((dx * dx + dy * dy + dz * dz) ** 0.5)

    e += m0 * (v0[0] * v0[0] + v0[1] * v0[1] + v0[2] * v0[2]) / 2.
    e += m1 * (v1[0] * v1[0] + v1[1] * v1[1] + v1[2] * v1[2]) / 2.
    e += m2 * (v2[0] * v2[0] + v2[1] * v2[1] + v2[2] * v2[2]) / 2.
    e += m3 * (v3[0] * v3[0] + v3[1] * v3[1] + v3[2] * v3[2]) / 2.
    e += m4 * (v4[0] * v4[0] + v4[1] * v4[1] + v4[2] * v4[2]) / 2.
    return e


def offset_momentum(ref, bodies=SYSTEM, px=0.0, py=0.0, pz=0.0):
    for (r, [vx, vy, vz], m) in bodies:
        px -= vx * m
        py -= vy * m
        pz -= vz * m
    (r, v, m) = ref
    v[0] = px / m
    v[1] = py / m
    v[2] = pz / m


def bench_nbody(loops, reference, iterations):
    # Set up global state
    offset_momentum(BODIES[reference])

    range_it = range(loops)
    t0 = pyperf.perf_counter()

    for _ in range_it:
        report_energy()
        advance(0.01, iterations)
        report_energy()

    return pyperf.perf_counter() - t0


def add_cmdline_args(cmd, args):
    cmd.extend(("--iterations", str(args.iterations)))


if __name__ == '__main__':
    runner = pyperf.Runner(add_cmdline_args=add_cmdline_args)
    runner.metadata['description'] = "n-body benchmark (manually unrolled)"
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
