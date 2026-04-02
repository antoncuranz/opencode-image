#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

args_file="$tmpdir/run-args"

cat >"$tmpdir/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd="${1:?command required}"
shift

case "$cmd" in
  run)
    printf '%s\n' "$@" >"${ARGS_FILE:?}"
    printf 'fake-cid\n'
    ;;
  inspect)
    if [ "${2:-}" = '{{.Config.User}}' ]; then
      printf '1000:1000\n'
    else
      printf '/workspace\n'
    fi
    ;;
  exec|rm)
    ;;
  *)
    printf 'unexpected docker command: %s\n' "$cmd" >&2
    exit 1
    ;;
esac
EOF

cat >"$tmpdir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '401'
EOF

chmod +x "$tmpdir/docker" "$tmpdir/curl"

PATH="$tmpdir:$PATH" \
ARGS_FILE="$args_file" \
CONTAINER_RUN_ARGS='--privileged --tmpfs /tmp:exec' \
./scripts/smoke.sh test-image >/dev/null

grep -Fx -- '--privileged' "$args_file"
grep -Fx -- '--tmpfs' "$args_file"
grep -Fx -- '/tmp:exec' "$args_file"
