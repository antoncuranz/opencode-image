#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/opencode}"
export PORT="${PORT:-4096}"

mkdir -p /workspace "$HOME"

cd /workspace

exec opencode web --hostname 0.0.0.0 --port "${PORT}" --print-logs --log-level DEBUG
