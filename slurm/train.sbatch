#!/bin/bash
#SBATCH --job-name=lda-train
#SBATCH --partition=gpu_rtx6000
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=16
#SBATCH --mem=160G
#SBATCH --time=2-00:00:00
#SBATCH --output=logs/%x-%j.out
# Usage: sbatch slurm/train.sbatch CONFIG EXP_NAME SEED [EXTRA_TRAIN_ARGS...]
#
# Runs openpi's train.py with the config's own settings. Norm stats must already be in assets/CONFIG
# (slurm/norm_stats.sbatch). Checkpoints go to $CHECKPOINT_BASE_DIR/CONFIG/EXP_NAME.
#
# openpi saves every 1000 steps and keeps the latest checkpoint plus every KEEP_PERIOD steps. Each
# saved step holds parameters and optimizer state, about 43 GB, so the default of 10000 here keeps
# steps 10000, 20000 and 29999 instead of openpi's six. Resubmitting with the same EXP_NAME resumes.
#
# Arguments after SEED go to train.py unchanged. They are for short test runs only, for example
#   --num-train-steps 400 --log-interval 50
# The runs of the four arms use none.
set -euo pipefail
config=${1:?usage: train.sbatch CONFIG EXP_NAME SEED [EXTRA_TRAIN_ARGS...]}
exp=${2:?usage: train.sbatch CONFIG EXP_NAME SEED [EXTRA_TRAIN_ARGS...]}
seed=${3:?usage: train.sbatch CONFIG EXP_NAME SEED [EXTRA_TRAIN_ARGS...]}
shift 3
cd "$SLURM_SUBMIT_DIR"
source env.sh

if ! ls "assets/$config"/*/*/norm_stats.json >/dev/null 2>&1; then
    echo "no norm stats under assets/$config; run slurm/norm_stats.sbatch $config first" >&2
    exit 1
fi

resume=()
if [ -d "$CHECKPOINT_BASE_DIR/$config/$exp" ]; then
    resume=(--resume)
fi

nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
uv run --frozen --project "$OPENPI_DIR" python "$OPENPI_DIR/scripts/train.py" "$config" \
    --exp-name "$exp" \
    --seed "$seed" \
    --checkpoint-base-dir "$CHECKPOINT_BASE_DIR" \
    --keep-period "${KEEP_PERIOD:-10000}" \
    "${resume[@]}" \
    "$@"
