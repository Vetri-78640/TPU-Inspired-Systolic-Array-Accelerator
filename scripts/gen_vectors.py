import argparse
from pathlib import Path

import numpy as np


def directed(n, k, rng):
    cases = []
    eye = np.eye(n, k, dtype=np.int64)
    cases.append((eye, rng.integers(-128, 128, (k, n))))
    cases.append((np.zeros((n, k), np.int64), np.zeros((k, n), np.int64)))
    cases.append((np.full((n, k), -128), np.full((k, n), -128)))
    sign = np.where(np.indices((n, k)).sum(0) % 2 == 0, 127, -128)
    cases.append((sign, np.full((k, n), -128)))
    one_a = np.zeros((n, k), np.int64)
    one_b = np.zeros((k, n), np.int64)
    one_a[n - 1, k - 1] = 5
    one_b[k - 1, n - 1] = -7
    cases.append((one_a, one_b))
    a = (np.arange(n * k).reshape(n, k) % 13) - 6
    b = (np.arange(k * n).reshape(k, n) * 3 % 11) - 5
    cases.append((a, b))
    return cases


def write(path, values, width):
    mask = (1 << (4 * width)) - 1
    path.write_text("".join(f"{int(v) & mask:0{width}x}\n" for v in values))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--n", type=int, default=4)
    p.add_argument("--k", type=int, default=4)
    p.add_argument("--count", type=int, default=100)
    p.add_argument("--seed", type=int, default=7)
    p.add_argument("--out", default="data")
    args = p.parse_args()

    rng = np.random.default_rng(args.seed)
    cases = directed(args.n, args.k, rng)
    for _ in range(args.count):
        cases.append((rng.integers(-128, 128, (args.n, args.k)), rng.integers(-128, 128, (args.k, args.n))))

    out = Path(args.out)
    out.mkdir(exist_ok=True)
    a = np.concatenate([x.ravel() for x, _ in cases])
    b = np.concatenate([y.ravel() for _, y in cases])
    c = np.concatenate([(x.astype(np.int64) @ y.astype(np.int64)).ravel() for x, y in cases])
    write(out / "a.hex", a, 2)
    write(out / "b.hex", b, 2)
    write(out / "c.hex", c, 8)
    write(out / "count.hex", [len(cases)], 8)
    print(f"wrote {len(cases)} cases (N={args.n}, K={args.k}) to {out}/")


if __name__ == "__main__":
    main()
