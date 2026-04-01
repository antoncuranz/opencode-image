#!/usr/bin/env bash
set -euo pipefail

runtime="${CONTAINER_CLI:-docker}"
image="${1:?image required}"
cid=""

cleanup() {
  if [ -n "$cid" ]; then
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
  if curl -fsS http://127.0.0.1:4096/global/health >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

test "$("$runtime" inspect --format '{{.Config.User}}' "$cid")" = "1000:1000"
test "$("$runtime" inspect --format '{{.Config.WorkingDir}}' "$cid")" = "/workspace"
"$runtime" exec "$cid" sh -lc 'test "$(id -u)" = 1000'
"$runtime" exec "$cid" sh -lc 'test "$(id -g)" = 1000'
"$runtime" exec "$cid" sh -lc 'test "$HOME" = "/home/opencode"'
"$runtime" exec "$cid" sh -lc 'test "$SSL_CERT_FILE" = "/etc/ssl/certs/ca-certificates.crt"'
"$runtime" exec "$cid" sh -lc 'test -f "$SSL_CERT_FILE"'
"$runtime" exec "$cid" sh -lc 'command -v opencode git gh rg'
"$runtime" exec "$cid" sh -lc '! command -v ssh >/dev/null 2>&1'
"$runtime" exec "$cid" sh -lc 'git config --global --get credential.helper | grep "gh auth git-credential"'
"$runtime" exec "$cid" sh -lc 'test "$(gh config get git_protocol)" = "https"'
"$runtime" exec "$cid" sh -lc 'curl -fsS https://github.com >/dev/null'
curl -fsS http://127.0.0.1:4096/global/health >/dev/null
