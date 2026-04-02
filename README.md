# opencode-image

Standard OCI image for running `opencode web` with `opencode-config` baked in and a broader daily-driver toolchain for local repo work.

## Build

```bash
nix build \
  --override-input opencode-config path:/Users/ant0n/Developer/opencode-config \
  .#packages.x86_64-linux.default
```

Use the override locally to reuse the checked-out `opencode-config` repo. CI keeps the pinned GitHub input.

## Run

```bash
docker load < result
docker tag opencode-image:latest localhost/opencode-image:dev
docker run --rm \
  --privileged \
  -p 4096:4096 \
  -e OPENCODE_SERVER_PASSWORD=change-me \
  -e GH_TOKEN=ghp_example_token \
  -v /path/to/repos:/workspace \
  localhost/opencode-image:dev
```

Required mounts:

- `/workspace` for working repos

Required env:

- `OPENCODE_SERVER_PASSWORD`
- `GH_TOKEN` for outbound GitHub HTTPS auth through `gh`

Runtime contract:

- user: `1000:1000`
- workdir: `/workspace`
- home: `/home/opencode`
- `opencode`: `nixpkgs-unstable`
- entrypoint: `opencode web --hostname 0.0.0.0 --port ${PORT:-4096}`
- auth: GitHub HTTPS via `gh` credential helper only
- SSH-based Git auth is not configured or supported
- CA bundle is exposed at `/etc/ssl/certs/ca-bundle.crt`
- `/usr/bin/env` is available for shebang compatibility
- `pg_config` is available for Python packages like `psycopg2`
- Docker commands talk to an internal rootless daemon, not a host socket
- container runtime should grant `--privileged` or equivalent support for nested containers

Included tooling baseline:

- JS: `node`, `npm`, `bun`
- Python: `python3`, `pip`
- Go: `go`
- Kubernetes/GitOps: `kubectl`, `helm`, `flux`, `talosctl`, `op`, `yq`
- Dev tooling: `make`, `docker`, `psql`, `pg_dump`, `vim`, `nix`
- Browser automation baseline: `chromium` for `agent-browser` and similar tooling

Config is baked in through `opencode-config` and discovered from `~/.config/opencode`. `OPENCODE_CONFIG_DIR` does not need to be set.

The image stays HTTPS-only for Git auth. SSH-based flows, including `cloudlab` bootstrap paths that expect SSH remotes, remain out of scope for this image even if some transitive package ships an `ssh` binary.

## Smoke test

```bash
./scripts/smoke.sh localhost/opencode-image:dev
```

## Publish

GitHub Actions builds the image on pushes and tags and publishes to GHCR.

Published tags:

- `${GITHUB_SHA}` on non-PR pushes
- `latest` from `main`
- `v*` from Git tags

## Troubleshooting

- If `docker` is installed but cannot reach the daemon, verify the container is running with `--privileged` or equivalent nested-container support.
- If `psycopg2` fails to build, verify `pg_config` is present with `command -v pg_config`.
- If a script fails on `#!/usr/bin/env ...`, verify `/usr/bin/env` exists in the container.
- If browser automation fails, verify `chromium` starts inside the container and that your OpenCode browser tooling is configured to use it.
- If GitHub auth fails, verify `GH_TOKEN` is present and `git config --global --get credential.helper` contains `gh auth git-credential`.
- If the web UI is reachable but login fails, verify `OPENCODE_SERVER_PASSWORD` matches the credentials used by the client.
- If the container cannot write the mounted workspace, fix host ownership for UID `1000`.
