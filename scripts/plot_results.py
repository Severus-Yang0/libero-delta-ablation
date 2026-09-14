"""Plot the evaluation results and print them as markdown tables.

    uv run --frozen --project third_party/openpi python scripts/plot_results.py [--seeds 42 43 44]

Reads results/<config>_s<seed>/<suite>/result.json and results/released/libero_10/result.json.
Writes figures/libero_10.png and figures/all_suites.png: bars are the mean success rate over training
seeds, error bars the standard deviation over seeds. Prints the tables used in README.md.
"""

import argparse
import json
import statistics
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.lines import Line2D  # noqa: E402
from matplotlib.patches import Patch  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SUITES = [
    ("libero_spatial", "LIBERO-Spatial"),
    ("libero_object", "LIBERO-Object"),
    ("libero_goal", "LIBERO-Goal"),
    ("libero_10", "LIBERO-10"),
]
# (config, normalization, delta transform); bars are grouped by normalization.
ARMS = [
    ("pi0_fast_libero", "mean/std", "on"),
    ("pi0_fast_libero_no_delta", "mean/std", "off"),
    ("pi0_fast_libero_quantile", "quantile", "on"),
    ("pi0_fast_libero_no_delta_quantile", "quantile", "off"),
]
NORMS = ["mean/std", "quantile"]
COLOR = {"on": "#eb6834", "off": "#2a78d6"}
LABEL = {"on": "delta transform on", "off": "delta transform off"}
INK, SECONDARY, MUTED, GRID, AXIS, SURFACE = "#0b0b0b", "#52514e", "#898781", "#e1e0d9", "#c3c2b7", "#ffffff"
BAR_WIDTH, BAR_OFFSET = 0.3, 0.17

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "font.size": 10,
        "figure.facecolor": SURFACE,
        "axes.facecolor": SURFACE,
        "savefig.facecolor": SURFACE,
        "axes.edgecolor": AXIS,
        "axes.labelcolor": SECONDARY,
        "text.color": INK,
        "xtick.color": SECONDARY,
        "ytick.color": MUTED,
        "legend.frameon": False,
    }
)


def success(config, seed, suite):
    path = ROOT / "results" / f"{config}_s{seed}" / suite / "result.json"
    result = json.loads(path.read_text())
    if not result.get("complete", False):
        raise ValueError(f"{path} is incomplete")
    return 100 * result["success_rate"]


def summary(seeds):
    out = {}
    for config, _, _ in ARMS:
        for suite, _ in SUITES:
            values = [success(config, seed, suite) for seed in seeds]
            sd = statistics.stdev(values) if len(values) > 1 else 0.0
            out[config, suite] = (statistics.mean(values), sd, values)
    return out


def draw_panel(ax, data, suite, value_fontsize):
    for config, norm, delta in ARMS:
        x = NORMS.index(norm) + (-BAR_OFFSET if delta == "on" else BAR_OFFSET)
        mean, sd, _ = data[config, suite]
        ax.bar(x, mean, BAR_WIDTH, color=COLOR[delta], zorder=2)
        ax.errorbar(x, mean, yerr=sd, fmt="none", ecolor=SECONDARY, elinewidth=1, capsize=3, zorder=3)
        ax.text(x, mean + sd + 1.5, f"{mean:.1f}", ha="center", va="bottom", fontsize=value_fontsize, color=INK)
    ax.set_xticks(range(len(NORMS)), NORMS)
    ax.set_xlim(-0.55, len(NORMS) - 0.45)
    ax.set_ylim(0, 108)
    ax.set_yticks(range(0, 101, 20), [f"{v}%" for v in range(0, 101, 20)])
    ax.grid(axis="y", color=GRID, linewidth=0.8, zorder=0)
    ax.tick_params(length=0)
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)


def legend_handles(released=False):
    handles = [Patch(color=COLOR[d], label=LABEL[d]) for d in ("on", "off")]
    if released:
        handles.append(Line2D([], [], color=SECONDARY, linewidth=1.2, linestyle=(0, (4, 3)), label="released checkpoint"))
    return handles


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seeds", type=int, nargs="+", default=[42, 43, 44])
    args = parser.parse_args()

    data = summary(args.seeds)
    released = 100 * json.loads((ROOT / "results/released/libero_10/result.json").read_text())["success_rate"]
    seeds_text = ", ".join(str(s) for s in args.seeds)
    note = f"Mean of {len(args.seeds)} training seeds ({seeds_text}), 500 episodes per evaluation. Error bars: SD over seeds."
    out_dir = ROOT / "figures"
    out_dir.mkdir(exist_ok=True)

    fig, ax = plt.subplots(figsize=(5.4, 4.4))
    draw_panel(ax, data, "libero_10", value_fontsize=10)
    ax.axhline(released, color=SECONDARY, linewidth=1.2, linestyle=(0, (4, 3)), zorder=1)
    ax.set_xlabel("action normalization")
    ax.set_title("LIBERO-10 success rate", fontsize=12, pad=30)
    ax.legend(handles=legend_handles(released=True), loc="lower center", bbox_to_anchor=(0.5, 1.0), ncol=3, fontsize=8.5)
    fig.text(0.5, 0.01, note, ha="center", fontsize=7.5, color=MUTED)
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    fig.savefig(out_dir / "libero_10.png", dpi=200)
    plt.close(fig)

    fig, axes = plt.subplots(1, len(SUITES), figsize=(11.5, 3.9), sharey=True)
    for ax, (suite, name) in zip(axes, SUITES):
        draw_panel(ax, data, suite, value_fontsize=8.5)
        ax.set_title(name, fontsize=11, pad=8)
    axes[0].set_ylabel("success rate")
    fig.legend(handles=legend_handles(), loc="upper center", bbox_to_anchor=(0.5, 1.0), ncol=2, fontsize=9.5)
    fig.text(0.5, 0.01, note + " x-axis: action normalization.", ha="center", fontsize=8, color=MUTED)
    fig.tight_layout(rect=(0, 0.04, 1, 0.92))
    fig.savefig(out_dir / "all_suites.png", dpi=200)
    plt.close(fig)

    print("| config | delta transform | normalization | " + " | ".join(name for _, name in SUITES) + " |")
    print("|---|---|---|" + "---|" * len(SUITES))
    for config, norm, delta in ARMS:
        cells = [f"{data[config, suite][0]:.1f} ± {data[config, suite][1]:.1f}" for suite, _ in SUITES]
        print(f"| `{config}` | {delta} | {norm} | " + " | ".join(cells) + " |")
    print()
    print("| config | " + " | ".join(f"seed {s}" for s in args.seeds) + " |")
    print("|---|" + "---|" * len(args.seeds))
    for config, _, _ in ARMS:
        print(f"| `{config}` | " + " | ".join(f"{v:.1f}" for v in data[config, "libero_10"][2]) + " |")
    print(f"| released `pi0_fast_libero` checkpoint | {released:.1f} | | |")


if __name__ == "__main__":
    main()
