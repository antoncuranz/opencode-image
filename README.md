# opencode-image

Standard OCI image for running `opencode web` with `opencode-config` baked in.

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
- SSH tooling is intentionally not included
- CA bundle is exposed at `/etc/ssl/certs/ca-certificates.crt`

Config is baked in through `opencode-config` and discovered from `~/.config/opencode`. `OPENCODE_CONFIG_DIR` does not need to be set.

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

- If GitHub auth fails, verify `GH_TOKEN` is present and `git config --global --get credential.helper` contains `gh auth git-credential`.
- If the web UI is reachable but login fails, verify `OPENCODE_SERVER_PASSWORD` matches the credentials used by the client.
- If the container cannot write the mounted workspace, fix host ownership for UID `1000`.
