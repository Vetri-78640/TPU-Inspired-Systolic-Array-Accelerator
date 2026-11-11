import csv
import re
import subprocess
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

RTL = ["rtl/pe.v", "rtl/systolic_array.v", "rtl/skew.v", "rtl/controller.v", "rtl/mm_accel.v"]
CONFIGS = [(2, 2), (3, 3), (4, 4), (8, 8), (4, 8), (4, 16), (4, 32), (4, 64)]


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


if __name__ == "__main__":
    main()
