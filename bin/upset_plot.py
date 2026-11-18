#!/usr/bin/env python3
"""UpSet plot from a 0/1 overlap table.

Usage: upset_plot.py <matrix.tsv> <output_prefix>
The table has 3 leading columns (chr/start/end or gene/./.), then one 0/1 column per cell type.
Writes <prefix>_upset.png and <prefix>_combinations.tsv. Needs only numpy and matplotlib.
"""
import sys
from collections import Counter

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

matrix_file, prefix = sys.argv[1], sys.argv[2]
with open(matrix_file) as fh:
    header = fh.readline().rstrip("\n").split("\t")
    sets = header[3:]
    rows = [tuple(int(v) for v in line.rstrip("\n").split("\t")[3:]) for line in fh if line.strip()]

unit = "genes" if header[0] == "gene" else ("5 kb bins" if "bins" in prefix else "regions")
counts = Counter(r for r in rows if any(r))
combos = sorted(counts, key=lambda c: (-counts[c], c))

with open(f"{prefix}_combinations.tsv", "w") as out:
    out.write("combination\tcount\n")
    for c in combos:
        out.write("&".join(s for s, v in zip(sets, c) if v) + f"\t{counts[c]}\n")

n_sets = len(sets)
fig = plt.figure(figsize=(max(6, 0.45 * len(combos) + 3), 3.2 + 0.35 * n_sets))
if not combos:
    fig.text(0.5, 0.5, f"No marked {unit}", ha="center", va="center")
    fig.savefig(f"{prefix}_upset.png", dpi=150)
    sys.exit(0)

grid = fig.add_gridspec(2, 2, width_ratios=[1.2, max(3, 0.45 * len(combos))],
                        height_ratios=[3, 0.35 * n_sets + 0.3], wspace=0.02, hspace=0.05)
ax_bar = fig.add_subplot(grid[0, 1])
ax_dots = fig.add_subplot(grid[1, 1], sharex=ax_bar)
ax_sets = fig.add_subplot(grid[1, 0], sharey=ax_dots)
dark, light = "#4a4a46", "#dcdbd5"
x = np.arange(len(combos))
vals = [counts[c] for c in combos]

ax_bar.bar(x, vals, color=dark, width=0.65)
for xi, v in zip(x, vals):
    ax_bar.text(xi, v, f"{v:,}", ha="center", va="bottom", fontsize=7, rotation=90)
ax_bar.set_ylabel(f"{unit} in combination")
ax_bar.set_ylim(0, max(vals) * 1.2)
ax_bar.spines[["top", "right", "bottom"]].set_visible(False)
ax_bar.tick_params(axis="x", bottom=False, labelbottom=False)
ax_bar.set_title(prefix.replace("_", " "), loc="left", fontsize=10)

y = np.arange(n_sets)[::-1]
for xi, c in zip(x, combos):
    on = [y[j] for j in range(n_sets) if c[j]]
    ax_dots.scatter([xi] * n_sets, y, s=40, color=light, zorder=1)
    ax_dots.scatter([xi] * len(on), on, s=40, color=dark, zorder=3)
    if len(on) > 1:
        ax_dots.plot([xi, xi], [min(on), max(on)], color=dark, lw=1.6, zorder=2)
ax_dots.set_xlim(-0.6, len(combos) - 0.4)
ax_dots.set_ylim(-0.6, n_sets - 0.4)
ax_dots.axis("off")

totals = [sum(r[j] for r in rows) for j in range(n_sets)]
ax_sets.barh(y, totals, color="#8f8e88", height=0.55)
ax_sets.invert_xaxis()
ax_sets.set_yticks(y)
ax_sets.set_yticklabels(sets)
ax_sets.yaxis.tick_right()
ax_sets.tick_params(axis="y", length=0, pad=6)
ax_sets.set_xlabel(f"{unit} per cell type", fontsize=8)
ax_sets.spines[["top", "left", "right"]].set_visible(False)

fig.savefig(f"{prefix}_upset.png", dpi=150, bbox_inches="tight")
