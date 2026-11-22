import csv
import re
import subprocess
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

CORE = ["rtl/pe.v", "rtl/systolic_array.v", "rtl/skew.v"]
RTL = [*CORE, "rtl/controller.v", "rtl/mm_accel.v"]
CONFIGS = [(2, 2), (3, 3), (4, 4), (8, 8), (4, 8), (4, 16), (4, 32), (4, 64)]
STREAM = [(2, 2), (4, 4), (4, 16), (8, 8)]
TILED = [(4, 8, 8, 8), (4, 8, 16, 12), (4, 16, 16, 16), (8, 16, 16, 16)]


def simulate(n, k, seq):
    src = ["rtl/seq_mac.v"] if seq else RTL
    flags = ["-DDUT=seq_mac"] if seq else []
    out = "sim/perf_seq" if seq else "sim/perf_acc"
    cmd = ["iverilog", "-Wall", *flags, "-P", f"mm_accel_tb.N={n}", "-P", f"mm_accel_tb.K={k}", "-o", out, *src, "tb/mm_accel_tb.v"]
    subprocess.run(cmd, check=True)
    log = subprocess.run(["vvp", "-n", out], check=True, capture_output=True, text=True).stdout
    m = re.search(r"errors=(\d+) cycles=(\d+)", log)
    if not m or m.group(1) != "0":
        sys.exit(f"simulation failed for N={n} K={k} seq={seq}\n{log}")
    return int(m.group(2))


def vectors(n, k, count, m=None, p=None):
    cmd = [sys.executable, "scripts/gen_vectors.py", "--n", str(n), "--k", str(k), "--count", str(count)]
    if m:
        cmd += ["--m", str(m), "--p", str(p)]
    subprocess.run(cmd, check=True, capture_output=True)


def run(src, top, params, pattern):
    flags = [f"-P{top}.{x}={v}" for x, v in params.items()]
    subprocess.run(["iverilog", "-Wall", *flags, "-o", "sim/perf2", *src], check=True)
    log = subprocess.run(["vvp", "-n", "sim/perf2"], check=True, capture_output=True, text=True).stdout
    m = re.search(pattern, log)
    if not m or m.group(1) != "0":
        sys.exit(f"simulation failed for {top} {params}\n{log}")
    return int(m.group(2))


def phase2(seq44):
    rows = []
    for n, k in STREAM:
        vectors(n, k, 100)
        one = run([*RTL, "tb/mm_accel_tb.v"], "mm_accel_tb", {"N": n, "K": k}, r"errors=(\d+) cycles=(\d+)")
        st = run([*CORE, "rtl/mm_stream.v", "tb/stream_tb.v"], "stream_tb", {"N": n, "K": k}, r"errors=(\d+) cycles=(\d+)")
        rows.append({"design": "stream", "N": n, "M": n, "K": k, "P": n, "matrices": 106,
                     "cycles": st, "baseline": "one at a time", "baseline_cycles": 106 * one,
                     "gain": round(106 * one / st, 2), "utilization_pct": round(100 * 106 * k / st, 1)})
        print(rows[-1])
    for n, m, k, p in TILED:
        vectors(n, k, 10, m, p)
        src = [*CORE, "rtl/mm_stream.v", "rtl/mm_tiled.v", "tb/tiled_tb.v"]
        tl = run(src, "tiled_tb", {"N": n, "M": m, "K": k, "P": p}, r"errors=(\d+) cycles=(\d+)")
        seq = m * p * k + 1
        rows.append({"design": "tiled", "N": n, "M": m, "K": k, "P": p, "matrices": 1,
                     "cycles": tl, "baseline": "single MAC", "baseline_cycles": seq,
                     "gain": round(seq / tl, 2), "utilization_pct": round(100 * m * p * k / (n * n * tl), 1)})
        print(rows[-1])
    with open("results/phase2_performance.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=rows[0].keys())
        w.writeheader()
        w.writerows(rows)

    st4 = next(r for r in rows if r["design"] == "stream" and r["N"] == 4 and r["K"] == 4)
    labels = ["single MAC", "Phase I array", "streaming array"]
    vals = [seq44, st4["baseline_cycles"] / 106, st4["cycles"] / 106]
    plt.figure(figsize=(6, 4))
    bars = plt.bar(labels, vals, color=["#9a9a9a", "#4c78a8", "#2e8b57"])
    plt.bar_label(bars, [f"{v:.2f}" for v in vals])
    plt.ylabel("cycles per 4x4x4 product")
    plt.title("Throughput, 106 back-to-back 4x4x4 products")
    plt.tight_layout()
    plt.savefig("results/throughput.png", dpi=150)
    print("wrote results/phase2_performance.csv and results/throughput.png")


def main():
    Path("sim").mkdir(exist_ok=True)
    Path("results").mkdir(exist_ok=True)
    rows = []
    for n, k in CONFIGS:
        subprocess.run([sys.executable, "scripts/gen_vectors.py", "--n", str(n), "--k", str(k), "--count", "10"], check=True)
        sa = simulate(n, k, False)
        sq = simulate(n, k, True)
        rows.append({
            "N": n,
            "K": k,
            "model_compute": 2 * n + k - 2,
            "systolic_cycles": sa,
            "sequential_cycles": sq,
            "speedup": round(sq / sa, 2),
            "utilization_pct": round(100 * k / sa, 1),
        })
        print(rows[-1])

    with open("results/performance.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=rows[0].keys())
        w.writeheader()
        w.writerows(rows)

    ks = [r for r in rows if r["N"] == 4]
    x = [r["K"] for r in ks]
    plt.figure(figsize=(6, 4))
    plt.plot(x, [r["speedup"] for r in ks], "o-", label="measured (4x4 array)")
    plt.axhline(16, ls="--", c="gray", label="limit: 16 PEs")
    plt.xscale("log", base=2)
    plt.xticks(x, [str(v) for v in x])
    plt.xlabel("K (inner dimension)")
    plt.ylabel("speed-up over sequential MAC")
    plt.title("Speed-up vs K, 4x4 output-stationary array")
    plt.grid(alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig("results/speedup_vs_k.png", dpi=150)
    print("wrote results/performance.csv and results/speedup_vs_k.png")
    phase2(next(r["sequential_cycles"] for r in rows if r["N"] == 4 and r["K"] == 4))


if __name__ == "__main__":
    main()
