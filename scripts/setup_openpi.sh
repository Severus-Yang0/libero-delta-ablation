#!/usr/bin/env bash
# Check the openpi checkout, apply the patches in patches/, and build openpi's uv environment.
# Run on a compute node; dependency resolution is killed by the login node's memory limit.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../env.sh"

cd "$OPENPI_DIR"
actual=$(git rev-parse HEAD)
if [ "$actual" != "$OPENPI_COMMIT" ]; then
    echo "third_party/openpi is at $actual, expected $OPENPI_COMMIT" >&2
    exit 1
fi
git submodule update --init --recursive

# The patches are applied in order to a clean working tree. If the tree is already modified, it must
# contain only the patched config file, as left by an earlier run of this script.
status=$(git status --porcelain --untracked-files=no --ignore-submodules=all)
if [ -z "$status" ]; then
    for p in "$ABLATION_ROOT"/patches/*.patch; do
        git apply "$p"
        echo "applied $(basename "$p")"
    done
elif [ "$status" = " M src/openpi/training/config.py" ]; then
    echo "src/openpi/training/config.py already modified, assuming the patches are applied"
else
    echo "third_party/openpi has changes other than the files in patches/:" >&2
    echo "$status" >&2
    exit 1
fi

# Same steps as openpi's README, with the lockfile used as-is.
uv sync --frozen
uv pip install -e .

uv run --frozen python - <<'PY'
from openpi.training import config

for name in (
    "pi0_fast_libero",
    "pi0_fast_libero_no_delta",
    "pi0_fast_libero_quantile",
    "pi0_fast_libero_no_delta_quantile",
):
    data = config.get_config(name).data
    print(
        f"{name}: extra_delta_transform={data.extra_delta_transform}, "
        f"use_quantile_norm_override={data.use_quantile_norm_override}"
    )
PY
