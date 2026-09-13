#!/bin/bash
#SBATCH --job-name=lda-norm-stats
#SBATCH --partition=day
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x-%j.out
# Usage: sbatch slurm/norm_stats.sbatch CONFIG
# Writes assets/CONFIG/physical-intelligence/libero/norm_stats.json. Run slurm/download_data.sbatch
# first, so that several of these jobs can run at once without downloading the dataset in parallel.
# Submit from the repository root: openpi resolves its assets directory relative to the working
# directory.
set -euo pipefail
config=${1:?usage: norm_stats.sbatch CONFIG}
cd "$SLURM_SUBMIT_DIR"
source env.sh
uv run --frozen --project "$OPENPI_DIR" python "$OPENPI_DIR/scripts/compute_norm_stats.py" --config-name "$config"
ls -l "assets/$config"/*/*/norm_stats.json
