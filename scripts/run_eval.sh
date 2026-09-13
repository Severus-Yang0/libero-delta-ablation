#!/usr/bin/env bash
# Evaluate one policy on one LIBERO suite with openpi's policy server and LIBERO client.
#
#   scripts/run_eval.sh CONFIG CHECKPOINT SUITE OUT_DIR [TRIALS_PER_TASK] [SEED]
#
# CHECKPOINT is a training step directory or a gs:// path. Writes server.log, client.log and
# result.json to OUT_DIR. Apart from suite, trial count, seed and port, the client runs with
# openpi's defaults.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../env.sh"

config=${1:?config}
checkpoint=${2:?checkpoint}
suite=${3:?suite}
out=$(realpath -m "${4:?output directory}")
trials=${5:-50}
seed=${6:-7}
mkdir -p "$out"

# One port per job, so several evaluations can share a node.
port=$(( 20000 + ${SLURM_JOB_ID:-$$} % 20000 ))

cd "$OPENPI_DIR"
uv run --frozen scripts/serve_policy.py --port "$port" policy:checkpoint \
    --policy.config="$config" --policy.dir="$checkpoint" > "$out/server.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT

# Downloading and loading the checkpoint can take several minutes.
ready=0
for _ in $(seq 1 120); do
    if ! kill -0 "$server_pid" 2>/dev/null; then
        echo "policy server exited early; see $out/server.log" >&2
        exit 1
    fi
    if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
        ready=1
        break
    fi
    sleep 10
done
if [ "$ready" -ne 1 ]; then
    echo "policy server did not open port $port within 20 minutes; see $out/server.log" >&2
    exit 1
fi

export PYTHONPATH="${PYTHONPATH:-}:$OPENPI_DIR/third_party/libero"
examples/libero/.venv/bin/python examples/libero/main.py \
    --args.host 127.0.0.1 \
    --args.port "$port" \
    --args.task-suite-name "$suite" \
    --args.num-trials-per-task "$trials" \
    --args.seed "$seed" \
    --args.video-out-path "$out/videos" \
    2>&1 | tee "$out/client.log"

python3 "$ABLATION_ROOT/scripts/parse_eval_log.py" "$out/client.log" \
    --config "$config" --checkpoint "$checkpoint" --suite "$suite" \
    --trials-per-task "$trials" --seed "$seed" \
    --openpi-commit "$(git rev-parse HEAD)" \
    --openpi-diff-sha256 "$(git diff | sha256sum | cut -d' ' -f1)" \
    > "$out/result.json"
cat "$out/result.json"
