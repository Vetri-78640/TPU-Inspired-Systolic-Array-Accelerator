import random
import numpy as np


def run(A, B):
    M, K = A.shape
    _, N = B.shape
    acc = np.zeros((M, N), dtype=np.int64)
    a_reg = np.zeros((M, N), dtype=np.int64)
    b_reg = np.zeros((M, N), dtype=np.int64)
    last = -1
    trace = []
    t = 0
    while True:
        left = [A[i][t - i] if 0 <= t - i < K else 0 for i in range(M)]
        top = [B[t - j][j] if 0 <= t - j < K else 0 for j in range(N)]
        a_in = np.array([[left[i] if j == 0 else a_reg[i][j - 1] for j in range(N)] for i in range(M)])
        b_in = np.array([[top[j] if i == 0 else b_reg[i - 1][j] for j in range(N)] for i in range(M)])
        ops = []
        for i in range(M):
            for j in range(N):
                k = t - i - j
                if 0 <= k < K:
                    ops.append((i, j, k))
                    last = t
        trace.append(ops)
        acc += a_in * b_in
        a_reg, b_reg = a_in, b_in
        t += 1
        if t > M + N + K + 5:
            break
    return acc, last + 1, trace


for _ in range(200):
    M, K, N = random.randint(1, 6), random.randint(1, 70), random.randint(1, 6)
    A = np.random.randint(-128, 128, (M, K))
    B = np.random.randint(-128, 128, (K, N))
    C, cycles, _ = run(A, B)
    assert (C == A @ B).all()
    assert cycles == M + N + K - 2, (M, N, K, cycles)

_, cycles, trace = run(np.ones((2, 2), int), np.ones((2, 2), int))
print("2x2 cycles", cycles)
for t, ops in enumerate(trace[:cycles]):
    print(t, ops)
_, c4, _ = run(np.ones((4, 4), int), np.ones((4, 4), int))
print("4x4 cycles", c4, "seq", 64, "speedup", 64 / c4, "util", 64 / (16 * c4))
_, c64, _ = run(np.ones((4, 64), int), np.ones((64, 4), int))
print("4x64x4 cycles", c64, "seq", 4 * 4 * 64, "speedup", 4 * 4 * 64 / c64)
print("all random checks passed")
