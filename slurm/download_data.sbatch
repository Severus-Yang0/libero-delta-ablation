#!/bin/bash
#SBATCH --job-name=lda-download-data
#SBATCH --partition=day
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x-%j.out
# Downloads physical-intelligence/libero (~35 GB) into $HF_LEROBOT_HOME through lerobot's own
# LeRobotDataset, the same call openpi's data loader makes. Run once before the norm-stats and training
# jobs; with every file present locally, lerobot loads the dataset without contacting the Hub.
# Single requests to the Hub occasionally time out, so the download is retried; it resumes where it
# stopped. Submit from the repository root.
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
source env.sh

attempts=${DOWNLOAD_ATTEMPTS:-10}
for i in $(seq 1 "$attempts"); do
    echo "attempt $i/$attempts, $(date)"
    if uv run --frozen --project "$OPENPI_DIR" python - <<'PY'; then
from lerobot.common.datasets.lerobot_dataset import LeRobotDataset

ds = LeRobotDataset("physical-intelligence/libero")
print("root", ds.root)
print("codebase_version", ds.meta.info["codebase_version"])
print("episodes", ds.num_episodes, "frames", ds.num_frames, "tasks", ds.meta.total_tasks)
PY
        du -sh "$HF_LEROBOT_HOME/physical-intelligence/libero"
        exit 0
    fi
    sleep 60
done
echo "download failed after $attempts attempts" >&2
exit 1
