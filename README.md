# opencode-nixos-web-image

Rootless NixOS image for running `opencode web` with `opencode-config` baked in.

## Build

```bash
nix build .#packages.x86_64-linux.default
```

## Run with Podman

```bash
podman import \
  --change 'CMD ["/init"]' \
  result/tarball/*.tar.xz \
  localhost/opencode-nixos-web-image:dev
podman run --rm \
  -p 4096:4096 \
  -e OPENCODE_SERVER_PASSWORD=change-me \
  -e GH_TOKEN=ghp_example_token \
  -v /path/to/repos:/workspace \
  localhost/opencode-nixos-web-image:dev
```

Required mounts:

- `/workspace` for working repos

Required env:

- `OPENCODE_SERVER_PASSWORD`
- `GH_TOKEN` for outbound GitHub auth through `gh`

Config is baked in through `opencode-config` and discovered from `~/.config/opencode` for the `opencode` user. `OPENCODE_CONFIG_DIR` does not need to be set.

## Publish

GitHub Actions builds the image on pushes and tags and publishes to GHCR.

Published tags:

- `${GITHUB_SHA}` on non-PR pushes
- `latest` from `main`
- `v*` from Git tags

## Troubleshooting

- If GitHub auth fails, verify `GH_TOKEN` is present and `git config --global --get-all credential.helper` points at `gh`.
- If the web UI is reachable but login fails, verify `OPENCODE_SERVER_PASSWORD` matches the credentials used by the client.
- If Podman cannot write the mounted workspace, fix host ownership for UID `1000` or adjust the container UID.
