#!/bin/bash
#SBATCH --job-name=lda-eval
#SBATCH --partition=gpu_rtx6000
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x-%j.out
# Usage: sbatch slurm/eval.sbatch CONFIG CHECKPOINT SUITE TAG [TRIALS_PER_TASK]
# CHECKPOINT is a step directory or a gs:// path. Output goes to results/TAG/SUITE/.
set -euo pipefail
config=${1:?config}
checkpoint=${2:?checkpoint}
suite=${3:?suite}
tag=${4:?tag}
trials=${5:-50}
cd "$SLURM_SUBMIT_DIR"
bash scripts/run_eval.sh "$config" "$checkpoint" "$suite" "results/$tag/$suite" "$trials"
