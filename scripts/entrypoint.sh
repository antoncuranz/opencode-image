#!/usr/bin/env bash
set -euo pipefail

mkdir -p /workspace "$HOME"

exec opencode web --hostname 0.0.0.0 --port "$PORT"
