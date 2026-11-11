from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, Rectangle

OUT = Path("docs/diagrams")


def box(ax, x, y, w, h, text, color="#e8f0fe", size=10):
    ax.add_patch(Rectangle((x, y), w, h, fc=color, ec="black", lw=1.2))
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=size)


def arrow(ax, x1, y1, x2, y2, text=None, side="top"):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>", mutation_scale=12, lw=1.2))
    if text:
        dy = 0.15 if side == "top" else -0.25
        ax.text((x1 + x2) / 2, (y1 + y2) / 2 + dy, text, ha="center", fontsize=8)


def block_diagram():
    fig, ax = plt.subplots(figsize=(10, 5.2))
    box(ax, 3.2, 4.3, 4.2, 0.8, "Controller FSM\nIDLE > CLEAR > RUN > DONE", "#fde8e8")
    box(ax, 0.0, 2.4, 1.4, 0.8, "A buffer")
    box(ax, 1.9, 2.4, 1.4, 0.8, "A feeder")
    box(ax, 3.8, 2.4, 1.4, 0.8, "Row skew\n(i delays)")
    box(ax, 5.8, 0.2, 2.6, 3.0, "4 x 4 PE grid\n(systolic_array)\n\n16 MAC cells\nint8 x int8\nint32 acc", "#e6f4ea")
    box(ax, 5.8, 3.4, 2.6, 0.6, "Col skew (j delays)")
    box(ax, 8.9, 3.4, 1.0, 0.6, "B feeder")
    box(ax, 8.9, 4.3, 1.0, 0.6, "B buffer")
    arrow(ax, 1.4, 2.8, 1.9, 2.8)
    arrow(ax, 3.3, 2.8, 3.8, 2.8, "A[i][t]")
    arrow(ax, 5.2, 2.8, 5.8, 2.8)
    arrow(ax, 9.4, 4.3, 9.4, 4.0)
    arrow(ax, 8.9, 3.7, 8.4, 3.7)
    arrow(ax, 7.1, 3.4, 7.1, 3.2, )
    arrow(ax, 8.4, 1.0, 9.9, 1.0, "C (16 x 32 bit)")
    arrow(ax, 5.3, 4.3, 5.3, 3.25, "clr, t", side="bottom")
    ax.text(0.0, 4.7, "start", fontsize=9)
    arrow(ax, 0.6, 4.7, 3.2, 4.7)
    arrow(ax, 7.4, 4.7, 8.6, 4.95, "busy, done")
    ax.text(0.0, 1.6, "write port (wr_en, wr_addr, wr_data)\nloads A and B buffers", fontsize=8)
    ax.set_xlim(-0.2, 10.4)
    ax.set_ylim(0, 5.4)
    ax.axis("off")
    ax.set_title("mm_accel: output-stationary systolic matrix multiplier", fontsize=12)
    fig.tight_layout()
    fig.savefig(OUT / "block_diagram.png", dpi=160)
    plt.close(fig)


def pe_diagram():
    fig, ax = plt.subplots(figsize=(5, 4))
    box(ax, 1.5, 1.2, 2.2, 1.8, "a x b\n+\nacc (32 bit)", "#e6f4ea", 11)
    arrow(ax, 0.2, 2.1, 1.5, 2.1, "a_in")
    arrow(ax, 3.7, 2.1, 5.0, 2.1, "a_out (+1 cycle)")
    arrow(ax, 2.6, 4.0, 2.6, 3.0)
    ax.text(2.7, 3.6, "b_in", fontsize=8)
    arrow(ax, 2.6, 1.2, 2.6, 0.1)
    ax.text(2.7, 0.5, "b_out (+1 cycle)", fontsize=8)
    ax.set_xlim(0, 5.2)
    ax.set_ylim(0, 4.2)
    ax.axis("off")
    ax.set_title("Processing element (pe.v)")
    fig.tight_layout()
    fig.savefig(OUT / "pe.png", dpi=160)
    plt.close(fig)


def wavefront(n=4, k=4):
    cycles = 2 * n + k - 2
    fig, axes = plt.subplots(1, cycles, figsize=(1.3 * cycles, 1.9))
    for t, ax in enumerate(axes):
        for i in range(n):
            for j in range(n):
                kk = t - i - j
                on = 0 <= kk < k
                ax.add_patch(Rectangle((j, n - 1 - i), 1, 1, fc="#34a853" if on else "white", ec="gray"))
                if on:
                    ax.text(j + 0.5, n - 0.5 - i, f"k{kk}", ha="center", va="center", fontsize=6, color="white")
        ax.set_xlim(0, n)
        ax.set_ylim(0, n)
        ax.set_aspect("equal")
        ax.axis("off")
        ax.set_title(f"t={t}", fontsize=8)
    fig.suptitle("Active PEs per cycle, 4x4 x 4x4 (green = doing a MAC with index k)", fontsize=9)
    fig.tight_layout()
    fig.savefig(OUT / "wavefront.png", dpi=160)
    plt.close(fig)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    block_diagram()
    pe_diagram()
    wavefront()
    print(f"wrote diagrams to {OUT}/")
