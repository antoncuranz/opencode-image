#!/usr/bin/env bash
set -euo pipefail

runtime="${CONTAINER_CLI:-docker}"
image="${1:?image required}"
cid=""
tools='opencode git gh rg node npm bun python3 go kubectl helm flux talosctl op yq make psql pg_dump vim nix chromium clear which tar gzip wget unzip ping'

health_status() {
  curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:4096/global/health
}

cleanup() {
  if [ -n "$cid" ]; then
    "$runtime" logs "$cid" >/dev/null 2>&1 || true
    "$runtime" rm -f "$cid" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

cid=$("$runtime" run -d \
  -p 4096:4096 \
  -e OPENCODE_SERVER_PASSWORD=test \
  -e GH_TOKEN=ghp_example_token \
  -v "$PWD":/workspace \
  "$image")

for _ in $(seq 1 30); do
  if ! "$runtime" inspect --format '{{.State.Running}}' "$cid" | grep -qx true; then
    "$runtime" logs "$cid"
    exit 1
  fi
  status="$(health_status || true)"
  if [ "$status" = "200" ] || [ "$status" = "401" ]; then
    break
  fi
  sleep 1
done

"$runtime" inspect --format '{{.State.Running}}' "$cid" | grep -qx true

test "$("$runtime" inspect --format '{{.Config.User}}' "$cid")" = "1000:1000"
test "$("$runtime" inspect --format '{{.Config.WorkingDir}}' "$cid")" = "/workspace"
"$runtime" exec "$cid" sh -lc 'test "$(id -u)" = 1000'
"$runtime" exec "$cid" sh -lc 'test "$(id -g)" = 1000'
"$runtime" exec "$cid" sh -lc 'test "$HOME" = "/home/opencode"'
"$runtime" exec "$cid" sh -lc 'test "$SSL_CERT_FILE" = "/etc/ssl/certs/ca-bundle.crt"'
"$runtime" exec "$cid" sh -lc 'test -f "$SSL_CERT_FILE"'
"$runtime" exec "$cid" sh -lc 'test -x /usr/bin/env'
"$runtime" exec "$cid" sh -lc "command -v $tools"
"$runtime" exec "$cid" sh -lc 'command -v pg_config'
"$runtime" exec "$cid" sh -lc 'test -x "$(command -v chromium)"'
"$runtime" exec "$cid" sh -lc 'git config --global --get credential.helper | grep "gh auth git-credential"'
"$runtime" exec "$cid" sh -lc 'test "$(gh config get git_protocol)" = "https"'
"$runtime" exec "$cid" sh -lc 'curl -fsS https://github.com >/dev/null'
status="$(health_status)"
test "$status" = "200" -o "$status" = "401"
