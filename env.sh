# Environment for this repository. Source it in every shell and batch job: `source env.sh`
# Defaults match the Yale Bouchet cluster layout. Put overrides in env.local.sh (not tracked).

ABLATION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ABLATION_ROOT
export OPENPI_DIR="$ABLATION_ROOT/third_party/openpi"
export OPENPI_COMMIT=215abfb217dbac7d5f1273282331b9b1866c0479

# Large or regenerable data goes to scratch (purged after 30 days of inactivity).
export SCRATCH_BASE="${SCRATCH_BASE:-/nfs/roberts/scratch/pi_tkf6/$USER/libero-delta-ablation}"

if command -v module >/dev/null 2>&1; then
    module load uv/0.9.17 >/dev/null 2>&1 || true
fi

# Site Python modules (e.g. Jupyter) set PYTHONPATH, and batch jobs inherit it. Packages found there
# get imported inside uv's isolated build environments and break source builds.
unset PYTHONPATH PYTHONHOME

# uv: package cache on scratch, Python builds next to the repo (not in $HOME). Use uv-managed Python
# only, so the environments do not depend on the operating system's interpreter.
export UV_CACHE_DIR="$SCRATCH_BASE/uv-cache"
export UV_PYTHON_INSTALL_DIR="$ABLATION_ROOT/.uv-python"
export UV_PYTHON_PREFERENCE=only-managed
export UV_LINK_MODE=copy
export GIT_LFS_SKIP_SMUDGE=1

# openpi downloads (base weights, released checkpoints) and training output.
export OPENPI_DATA_HOME="$SCRATCH_BASE/openpi-cache"
export CHECKPOINT_BASE_DIR="$SCRATCH_BASE/checkpoints"

# Hugging Face and LeRobot caches (physical-intelligence/libero is ~35 GB).
export HF_HOME="$SCRATCH_BASE/hf"
export HF_LEROBOT_HOME="$HF_HOME/lerobot"
# With HF_HOME moved, the Hub client looks for the login token under $HF_HOME only. Point it back at
# the token written by `huggingface-cli login`; anonymous requests get rate-limited (HTTP 429).
if [ -z "${HF_TOKEN:-}" ] && [ -z "${HF_TOKEN_PATH:-}" ] && [ -f "$HOME/.cache/huggingface/token" ]; then
    export HF_TOKEN_PATH="$HOME/.cache/huggingface/token"
fi
# The Hub client's default 10 s timeouts are too short for this cluster's link to the Hub.
export HF_HUB_ETAG_TIMEOUT="${HF_HUB_ETAG_TIMEOUT:-60}"
export HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-60}"

export XLA_PYTHON_CLIENT_MEM_FRACTION=0.9
# Batch jobs block-buffer stdout, which holds back train.py's "Step N: loss=..." lines until exit.
export PYTHONUNBUFFERED=1

# LIBERO reads its config from here and prompts on stdin if the file is missing.
export LIBERO_CONFIG_PATH="$ABLATION_ROOT/.libero"
export MUJOCO_GL=egl
export PYOPENGL_PLATFORM=egl

export WANDB_MODE="${WANDB_MODE:-offline}"
export WANDB_DIR="$SCRATCH_BASE/wandb"

mkdir -p "$UV_CACHE_DIR" "$OPENPI_DATA_HOME" "$CHECKPOINT_BASE_DIR" "$HF_HOME" "$WANDB_DIR"

if [ -f "$ABLATION_ROOT/env.local.sh" ]; then
    # shellcheck disable=SC1091
    source "$ABLATION_ROOT/env.local.sh"
fi
