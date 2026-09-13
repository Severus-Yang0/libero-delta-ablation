"""Summarise the log of openpi's examples/libero/main.py as JSON.

    python scripts/parse_eval_log.py client.log --config CONFIG --checkpoint DIR --suite SUITE \
        --trials-per-task 50 --seed 7 > result.json

main.py logs "Task: <description>" at the start of every episode, "Current task success rate: <x>"
after the last episode of each task, and "Total success rate: <x>" and "Total episodes: <n>" at the
end.
"""

import argparse
import json
import re
import sys

TASK = re.compile(r"(?:^|:)Task: (.+?)\s*$")
TASK_RATE = re.compile(r"Current task success rate: ([0-9.]+)")
TOTAL_RATE = re.compile(r"Total success rate: ([0-9.]+)")
TOTAL_EPISODES = re.compile(r"Total episodes: (\d+)")


def parse(lines):
    tasks = []
    current = None
    total_rate = None
    total_episodes = None
    for line in lines:
        match = TASK_RATE.search(line)
        if match:
            tasks.append({"task": current, "success_rate": float(match.group(1))})
            continue
        match = TOTAL_RATE.search(line)
        if match:
            total_rate = float(match.group(1))
            continue
        match = TOTAL_EPISODES.search(line)
        if match:
            total_episodes = int(match.group(1))
            continue
        match = TASK.search(line)
        if match:
            current = match.group(1)
    return tasks, total_rate, total_episodes


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("log")
    parser.add_argument("--config", required=True)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--suite", required=True)
    parser.add_argument("--trials-per-task", type=int, required=True)
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--openpi-commit", default=None)
    parser.add_argument("--openpi-diff-sha256", default=None)
    args = parser.parse_args()

    with open(args.log) as f:
        tasks, total_rate, total_episodes = parse(f)
    if total_rate is None:
        sys.exit(f"{args.log}: no 'Total success rate' line, the evaluation did not finish")

    expected = args.trials_per_task * len(tasks)
    result = {
        "config": args.config,
        "checkpoint": args.checkpoint,
        "suite": args.suite,
        "trials_per_task": args.trials_per_task,
        "seed": args.seed,
        "openpi_commit": args.openpi_commit,
        "openpi_diff_sha256": args.openpi_diff_sha256,
        "success_rate": total_rate,
        "episodes": total_episodes,
        "complete": total_episodes == expected,
        "tasks": tasks,
    }
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
