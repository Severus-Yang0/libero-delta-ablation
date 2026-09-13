#!/usr/bin/env bash
# Build the LIBERO simulation client as described in openpi's examples/libero/README.md (Python 3.8
# and its pinned requirements), and write LIBERO's config file so that importing LIBERO inside a batch
# job does not stop to ask for paths on stdin.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../env.sh"

cd "$OPENPI_DIR"
if [ ! -x examples/libero/.venv/bin/python ]; then
    uv venv --python 3.8 examples/libero/.venv
fi
# shellcheck disable=SC1091
source examples/libero/.venv/bin/activate
uv pip sync examples/libero/requirements.txt third_party/libero/requirements.txt \
    --extra-index-url https://download.pytorch.org/whl/cu113 --index-strategy=unsafe-best-match
uv pip install -e packages/openpi-client
uv pip install -e third_party/libero

libero_root="$OPENPI_DIR/third_party/libero/libero/libero"
mkdir -p "$LIBERO_CONFIG_PATH"
cat > "$LIBERO_CONFIG_PATH/config.yaml" <<YAML
benchmark_root: $libero_root
bddl_files: $libero_root/bddl_files
init_states: $libero_root/init_files
datasets: $libero_root/../datasets
assets: $libero_root/assets
YAML

export PYTHONPATH="${PYTHONPATH:-}:$OPENPI_DIR/third_party/libero"
python - <<'PY'
from libero.libero import benchmark, get_libero_path

suites = benchmark.get_benchmark_dict()
for name in ("libero_spatial", "libero_object", "libero_goal", "libero_10"):
    print(f"{name}: {suites[name]().n_tasks} tasks")
print("bddl_files:", get_libero_path("bddl_files"))
PY
