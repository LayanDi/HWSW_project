"""
cProfile wrapper for pyflate: calls the decompression function directly,
in a single process, bypassing pyperf.Runner's worker-process spawning.

Profiling run_benchmark.py directly (e.g. `python -m cProfile
run_benchmark.py`) profiles the PARENT process, which just spawns worker
subprocesses and reads their JSON results back over a pipe - cProfile then
sees time spent in `TextIOWrapper.read()` (reading worker output), not in
the actual bzip2/Huffman decoding, which happens inside the child
processes and is invisible to the parent's profiler.

Usage:
    python profile_pyflate.py
"""
import os
import cProfile
import pstats
import pyflate_original as rb

filename = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "data", "interpreter.tar.bz2")


def run_once():
    with open(filename, 'rb') as input_fp:
        field = rb.RBitfield(input_fp)
        magic = field.readbits(16)
        if magic == 0x1f8b:
            return rb.gzip_main(field)
        elif magic == 0x425a:
            return rb.bzip2_main(field)
        else:
            raise Exception("Unknown file magic")


cProfile.run('run_once()', 'pyflate_profile.prof')

p = pstats.Stats('pyflate_profile.prof')
p.strip_dirs().sort_stats('cumulative').print_stats(25)
print()
p.sort_stats('tottime').print_stats(25)
