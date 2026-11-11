import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

SIGNALS = ["clk", "clr", "a_left", "b_top", "c_flat"]


def parse(path, scope):
    ids, depth, inside, changes, t = {}, 0, False, {}, 0
    for line in Path(path).read_text().splitlines():
        p = line.split()
        if not p:
            continue
        if p[0] == "$scope":
            depth += 1
            inside = depth == 1 and p[2] == scope
        elif p[0] == "$upscope":
            depth -= 1
        elif p[0] == "$var" and inside and depth == 1 and p[4] in SIGNALS:
            ids[p[3]] = (p[4], int(p[2]))
        elif line[0] == "#":
            t = int(line[1:])
        elif line[0] == "b" and len(p) == 2 and p[1] in ids:
            name, width = ids[p[1]]
            changes.setdefault(name, []).append((t, p[0][1:].rjust(width, "0")))
        elif line[0] in "01xz" and line[1:] in ids:
            changes.setdefault(ids[line[1:]][0], []).append((t, line[0]))
    return changes, t


def lanes(bits, width):
    v = int(bits.replace("x", "0").replace("z", "0"), 2)
    n = len(bits) // width
    out = []
    for i in range(n):
        x = (v >> (i * width)) & ((1 << width) - 1)
        out.append(x - (1 << width) if x >> (width - 1) else x)
    return out


def main():
    vcd = sys.argv[1] if len(sys.argv) > 1 else "sim/array_tb.vcd"
    out = sys.argv[2] if len(sys.argv) > 2 else "docs/diagrams/waveform.png"
    end = int(sys.argv[3]) if len(sys.argv) > 3 else 65000
    ch, _ = parse(vcd, "array_tb")
    fig, ax = plt.subplots(figsize=(11, 3.6))
    widths = {"a_left": 8, "b_top": 8, "c_flat": 32}
    for row, name in enumerate(SIGNALS):
        y = len(SIGNALS) - 1 - row
        ax.text(-1500, y + 0.35, name, ha="right", va="center", fontsize=9, family="monospace")
        ev = [(t, v) for t, v in ch.get(name, []) if t <= end] + [(end, None)]
        for (t0, v), (t1, _) in zip(ev, ev[1:]):
            if t1 <= t0:
                continue
            if name in widths:
                ax.add_patch(plt.Rectangle((t0, y + 0.1), t1 - t0, 0.5, fc="#e8f0fe", ec="#1a73e8", lw=0.8))
                vals = lanes(v, widths[name])
                label = ",".join(str(x) for x in reversed(vals))
                if t1 - t0 >= 8000:
                    ax.text((t0 + t1) / 2, y + 0.35, label, ha="center", va="center", fontsize=7)
            else:
                lvl = 0.6 if v == "1" else 0.1
                ax.plot([t0, t1], [y + lvl, y + lvl], c="#1a73e8", lw=1)
                ax.plot([t1, t1], [y + 0.1, y + 0.6], c="#1a73e8", lw=0.5)
    ax.set_xlim(-12000, end)
    ax.set_ylim(-0.2, len(SIGNALS))
    ax.set_yticks([])
    ax.set_xlabel("time (ns)")
    ax.set_xticks(range(0, end + 1, 10000), [str(x // 1000) for x in range(0, end + 1, 10000)])
    for s in ["top", "right", "left"]:
        ax.spines[s].set_visible(False)
    ax.set_title("array_tb waveform: skewed inputs (row1,row0 / col1,col0) and results C[1][1],C[1][0],C[0][1],C[0][0]", fontsize=9)
    fig.tight_layout()
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=160)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
