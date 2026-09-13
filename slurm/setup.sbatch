#!/bin/bash
#SBATCH --job-name=lda-setup
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --output=logs/%x-%j.out
# Builds openpi's environment (with the patch applied) and the LIBERO client environment.
# Submit from the repository root.
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
bash scripts/setup_openpi.sh
bash scripts/setup_libero_client.sh
