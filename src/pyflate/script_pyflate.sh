set -e


mkdir -p results/pyflate

pip install pyperf py-spy


python -m pyperf system tune || true

cd src/pyflate/software


# 1. Baseline (original pyperformance pyflate benchmark)
python pyflate_original.py -o ../../../results/pyflate/baseline.json \
    --loops 1 --values 15

# 2. Optimization #1: O(1) dict lookup in find_next_symbol()
python pyflate_lookup.py -o ../../../results/pyflate/v1_lookup.json \
    --loops 1 --values 15
python -m pyperf compare_to ../../../results/pyflate/baseline.json \
    ../../../results/pyflate/v1_lookup.json \
    > ../../../results/pyflate/compare_v1_lookup.txt
cat ../../../results/pyflate/compare_v1_lookup.txt

# 3. Optimization #2: + move_to_front() using pop/insert instead of triple list-slicing
python pyflate_v2_lookup_mtf.py -o ../../../results/pyflate/v2_lookup_mtf.json \
    --loops 1 --values 15
python -m pyperf compare_to ../../../results/pyflate/baseline.json \
    ../../../results/pyflate/v2_lookup_mtf.json \
    > ../../../results/pyflate/compare_v2_lookup_mtf.txt
cat ../../../results/pyflate/compare_v2_lookup_mtf.txt

# 4. Correctness verification: byte-identical output + MD5 check against the real benchmark input
python -c "
import pyflate_v2_lookup_mtf as v2
out = v2.bench_pyflake(1, 'data/interpreter.tar.bz2')
print('MD5 check passed, ran in', out, 'seconds')
"

# 5. cProfile
python cprofile_wrapper_baseline.py \
    > ../../../results/pyflate/cprofile_baseline.txt
cat ../../../results/pyflate/cprofile_baseline.txt
mv pyflate_profile.prof ../../../results/pyflate/pyflate_profile_baseline.prof

# 6. Flame graphs (py-spy): baseline vs optimized, visual before/after
py-spy record -o ../../../results/pyflate/baseline_flame.svg -- \
    python flamegraph_wrapper.py pyflate_original
py-spy record -o ../../../results/pyflate/v2_lookup_mtf_flame.svg -- \
    python flamegraph_wrapper.py pyflate_v2_lookup_mtf

cd ../../..
echo "All pyflate profiling/optimization steps completed."
