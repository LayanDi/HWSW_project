set -e


mkdir -p results/nbody


pip install pyperf numpy numba py-spy


python -m pyperf system tune || true

cd src/nbody/software

# 1. Baseline (original pyperformance nbody benchmark)

python nbody_original.py -o ../../../results/nbody/baseline.json \
    --values 15 --loops 4


# 2. Optimization #1: manual loop unrolling

python nbody_unrolled.py -o ../../../results/nbody/unrolled.json \
    --values 15 --loops 4
python -m pyperf compare_to ../../../results/nbody/baseline.json \
    ../../../results/nbody/unrolled.json \
    > ../../../results/nbody/compare_unroll.txt
cat ../../../results/nbody/compare_unroll.txt

# 3. Optimization #2: sqrt() instead of ** (-1.5)
python nbody_unrolled_sqrt.py -o ../../../results/nbody/v2_sqrt.json \
    --values 15 --loops 4
python -m pyperf compare_to ../../../results/nbody/baseline.json \
    ../../../results/nbody/v2_sqrt.json \
    > ../../../results/nbody/compare_v2.txt
cat ../../../results/nbody/compare_v2.txt

# 4. Optimization #3: Numba JIT (nopython mode)
python nbody_numba.py -o ../../../results/nbody/numba.json \
    --values 15 --loops 4
python -m pyperf compare_to ../../../results/nbody/baseline.json \
    ../../../results/nbody/numba.json \
    > ../../../results/nbody/compare_numba.txt
cat ../../../results/nbody/compare_numba.txt

# 5. perf stat
perf stat -e cache-references,cache-misses,cycles,instructions \
    python perf_wrapper_baseline.py \
    2>&1 | tee ../../../results/nbody/perf_stat_baseline_singlerun.txt
perf stat -e cache-references,cache-misses,cycles,instructions \
    python perf_wrapper_numba.py \
    2>&1 | tee ../../../results/nbody/perf_stat_numba_singlerun.txt

# 6. perf record + report with Python debug symbols (original)
perf record -F 999 -g -- python3-dbg -m pyperformance run --bench nbody
perf report --stdio > ../../../results/nbody/perf_report_nbody.txt

# 7. Flame graphs (py-spy): baseline vs numba, visual before/after
py-spy record -o ../../../results/nbody/baseline_flame.svg -- \
    python nbody_original.py --iterations 200000
py-spy record -o ../../../results/nbody/numba_flame.svg -- \
    python nbody_numba.py --iterations 200000

cd ../../..
echo "All nbody profiling/optimization steps completed."
