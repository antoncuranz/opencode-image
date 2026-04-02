#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/opencode}"
export PORT="${PORT:-4096}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/.docker/run}"
export DOCKER_HOST="${DOCKER_HOST:-unix://$XDG_RUNTIME_DIR/docker.sock}"

mkdir -p /workspace "$HOME" "$XDG_RUNTIME_DIR" "$HOME/.local/share/docker"
chmod 700 "$XDG_RUNTIME_DIR"

dockerd-rootless \
  --host="$DOCKER_HOST" \
  --storage-driver=fuse-overlayfs \
  >"$HOME/dockerd.log" 2>&1 &

for _ in $(seq 1 60); do
  if docker info >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! docker info >/dev/null 2>&1; then
  cat "$HOME/dockerd.log" >&2 || true
  printf 'dockerd failed to become ready\n' >&2
  exit 1
fi

cd /workspace

exec opencode web --hostname 0.0.0.0 --port "${PORT}"
