import argparse
from pathlib import Path

import numpy as np


def directed(m, k, p, rng):
    cases = []
    eye = np.eye(m, k, dtype=np.int64)
    cases.append((eye, rng.integers(-128, 128, (k, p))))
    cases.append((np.zeros((m, k), np.int64), np.zeros((k, p), np.int64)))
    cases.append((np.full((m, k), -128), np.full((k, p), -128)))
    sign = np.where(np.indices((m, k)).sum(0) % 2 == 0, 127, -128)
    cases.append((sign, np.full((k, p), -128)))
    one_a = np.zeros((m, k), np.int64)
    one_b = np.zeros((k, p), np.int64)
    one_a[m - 1, k - 1] = 5
    one_b[k - 1, p - 1] = -7
    cases.append((one_a, one_b))
    a = (np.arange(m * k).reshape(m, k) % 13) - 6
    b = (np.arange(k * p).reshape(k, p) * 3 % 11) - 5
    cases.append((a, b))
    return cases


def write(path, values, width):
    mask = (1 << (4 * width)) - 1
    path.write_text("".join(f"{int(v) & mask:0{width}x}\n" for v in values))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--n", type=int, default=4)
    p.add_argument("--k", type=int, default=4)
    p.add_argument("--m", type=int, help="rows of A, default N")
    p.add_argument("--p", type=int, help="columns of B, default N")
    p.add_argument("--count", type=int, default=100)
    p.add_argument("--seed", type=int, default=7)
    p.add_argument("--out", default="data")
    args = p.parse_args()

    m = args.m or args.n
    q = args.p or args.n
    rng = np.random.default_rng(args.seed)
    cases = directed(m, args.k, q, rng)
    for _ in range(args.count):
        cases.append((rng.integers(-128, 128, (m, args.k)), rng.integers(-128, 128, (args.k, q))))

    out = Path(args.out)
    out.mkdir(exist_ok=True)
    a = np.concatenate([x.ravel() for x, _ in cases])
    b = np.concatenate([y.ravel() for _, y in cases])
    c = np.concatenate([(x.astype(np.int64) @ y.astype(np.int64)).ravel() for x, y in cases])
    write(out / "a.hex", a, 2)
    write(out / "b.hex", b, 2)
    write(out / "c.hex", c, 8)
    write(out / "count.hex", [len(cases)], 8)
    print(f"wrote {len(cases)} cases (M={m}, K={args.k}, P={q}) to {out}/")


if __name__ == "__main__":
    main()
