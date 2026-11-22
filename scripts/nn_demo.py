import re
import subprocess
import sys
import warnings
from pathlib import Path

import numpy as np
from sklearn.datasets import load_digits
from sklearn.exceptions import ConvergenceWarning
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier

N = 4
RTL = ["rtl/pe.v", "rtl/systolic_array.v", "rtl/skew.v", "rtl/mm_stream.v", "rtl/mm_tiled.v", "tb/tiled_tb.v"]


def write(path, values, width):
    mask = (1 << (4 * width)) - 1
    path.write_text("".join(f"{int(v) & mask:0{width}x}\n" for v in values))


def accel(a, b):
    m, k = a.shape
    p = b.shape[1]
    Path("data").mkdir(exist_ok=True)
    write(Path("data/a.hex"), a.ravel(), 2)
    write(Path("data/b.hex"), b.ravel(), 2)
    write(Path("data/c.hex"), (a.astype(np.int64) @ b.astype(np.int64)).ravel(), 8)
    write(Path("data/count.hex"), [1], 8)
    params = [f"-Ptiled_tb.{x}={v}" for x, v in (("N", N), ("M", m), ("K", k), ("P", p), ("MAXT", 1))]
    subprocess.run(["iverilog", "-Wall", *params, "-o", "sim/nn", *RTL], check=True)
    log = subprocess.run(["vvp", "-n", "sim/nn"], check=True, capture_output=True, text=True).stdout
    res = re.search(r"tiles=(\d+) cases=1 errors=(\d+) cycles=(\d+)", log)
    if not res or res.group(2) != "0":
        sys.exit(f"accelerator run failed\n{log}")
    out = np.array([int(x, 16) for x in Path("sim/tiled_out.hex").read_text().split()], dtype=np.int64)
    out = np.where(out >= 1 << 31, out - (1 << 32), out).reshape(m, p)
    return out, int(res.group(1)), int(res.group(3))


def pad(x, rows, cols):
    out = np.zeros((rows, cols), dtype=x.dtype)
    out[: x.shape[0], : x.shape[1]] = x
    return out


def main():
    Path("sim").mkdir(exist_ok=True)
    Path("results").mkdir(exist_ok=True)
    x, y = load_digits(return_X_y=True)
    xtr, xte, ytr, yte = train_test_split(x, y, test_size=0.2, random_state=0, stratify=y)

    with warnings.catch_warnings():
        warnings.simplefilter("ignore", ConvergenceWarning)
        mlp = MLPClassifier(hidden_layer_sizes=(32,), max_iter=300, random_state=0).fit(xtr / 16, ytr)
    w1, w2 = mlp.coefs_
    b1, b2 = mlp.intercepts_
    acc_float = (mlp.predict(xte / 16) == yte).mean()

    xtr_q = np.round(xtr * 127 / 16).astype(np.int64)
    xq = np.round(xte * 127 / 16).astype(np.int64)
    s1 = 127 / np.abs(w1).max()
    s2 = 127 / np.abs(w2).max()
    w1q = np.round(w1 * s1).astype(np.int64)
    w2q = np.round(w2 * s2).astype(np.int64)
    b1q = np.round(b1 * 127 * s1).astype(np.int64)
    r = 127 / np.maximum(xtr_q @ w1q + b1q, 0).max()
    b2q = np.round(b2 * r * 127 * s1 * s2).astype(np.int64)

    def requant(acc):
        return np.clip(np.round(np.maximum(acc + b1q, 0) * r), 0, 127).astype(np.int64)

    m = xq.shape[0]
    h_ref = xq @ w1q
    o_ref = requant(h_ref) @ w2q
    acc_int8 = ((o_ref + b2q).argmax(1) == yte).mean()

    h_hw, t1, c1 = accel(xq, w1q)
    o_hw, t2, c2 = accel(requant(h_hw), pad(w2q, w2q.shape[0], 12))
    o_hw = o_hw[:, :10]
    acc_hw = ((o_hw + b2q).argmax(1) == yte).mean()

    exact1 = bool((h_hw == h_ref).all())
    exact2 = bool((o_hw == o_ref).all())
    seq1 = m * 64 * 32
    seq2 = m * 32 * 12
    lines = [
        "Neural network demo: handwritten digits (scikit-learn digits, 8x8 images)",
        "network: 64 -> 32 (ReLU) -> 10, trained in float, weights and activations quantized to int8",
        f"test images: {m}",
        f"accuracy float model:          {acc_float:.4f}",
        f"accuracy int8 NumPy reference: {acc_int8:.4f}",
        f"accuracy int8 on accelerator:  {acc_hw:.4f}",
        f"layer 1 ({m}x64 by 64x32): {t1} tiles, {c1} cycles on the 4x4 array, {seq1} on a single MAC, exact match: {exact1}",
        f"layer 2 ({m}x32 by 32x12): {t2} tiles, {c2} cycles on the 4x4 array, {seq2} on a single MAC, exact match: {exact2}",
    ]
    Path("results/nn_demo.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    if not (exact1 and exact2):
        sys.exit("FAIL accelerator output differs from NumPy")
    print("NN DEMO PASSED")


if __name__ == "__main__":
    main()
