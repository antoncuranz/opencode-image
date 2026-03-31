# OpenCode NixOS Web Image Runtime Cleanup Design

**Goal:** Simplify the image runtime contract so `opencode-nixos-web-image` relies on `opencode-config` for config placement, keeps one clear source of truth for runtime paths and env, and removes dead surface such as `/data` and the standalone smoke script.

## Problem

The current image works, but its runtime contract is noisier than needed:

- `HOME` is set in multiple places
- `PORT` is defaulted in multiple places
- `OPENCODE_CONFIG_DIR` is exported in the entrypoint even though the image already imports `opencode-config`
- `/data` is created and documented, but nothing in the repo actually uses it
- `scripts/smoke.sh` exists mostly as CI glue, not as part of the runtime model

This makes the repo harder to reason about and obscures what the actual supported contract is.

## Scope

This cleanup covers:

- runtime env ownership in `nix/system.nix` and `scripts/entrypoint.sh`
- removal of unused `/data` behavior and docs
- removal of the standalone smoke script and its flake/workflow references
- README and CI updates to match the reduced contract

This cleanup does not cover:

- changing the non-root runtime user
- moving `HOME` to `/workspace`
- adding a new persistent state location
- changing `opencode-config` itself

## Approaches Considered

### 1. Minimal contract cleanup

Keep `HOME=/var/lib/opencode`, keep `/workspace` as the working directory, remove duplicate env defaults from the entrypoint, stop setting `OPENCODE_CONFIG_DIR`, and delete `/data` and `smoke.sh`.

Pros:

- smallest change set
- matches current `opencode-config` expectation of `~/.config/opencode`
- preserves clear separation between user home and mounted repos

Cons:

- still keeps a small entrypoint wrapper

### 2. Keep `/data` as a reserved future mount

Document `/data` as future state storage, but leave it otherwise unused.

Pros:

- leaves room for future persistence

Cons:

- keeps dead contract surface
- users mount a path that currently does nothing

### 3. Make `/workspace` the user home

Use `/workspace` as both working directory and `HOME`.

Pros:

- fewer paths

Cons:

- mixes user config with mounted repos
- makes the XDG/config story less clean
- increases risk of repo mount behavior affecting user home behavior

## Recommended Design

Use approach 1.

The image should keep a dedicated home at `/var/lib/opencode` and keep `/workspace` as the working directory only. `opencode-config` should continue to populate `~/.config/opencode` through Home Manager, with no explicit `OPENCODE_CONFIG_DIR` override. Runtime env should be defined once in `nix/system.nix`, and the entrypoint should stop re-declaring defaults already owned by the service.

Because `/data` is not wired to any actual state path, it should be removed from activation, entrypoint setup, and README examples. If persistent mutable state is introduced later, it should be added back only together with a real consumer.

Because `scripts/smoke.sh` is only CI glue, it should be removed together with `checks.smoke-script` and the workflow step that calls it. Verification can be handled by image build success for now, with any future runtime validation reintroduced in a simpler form if needed.

## Architecture

### Runtime ownership

`nix/system.nix` becomes the canonical source for:

- runtime user home
- working directory
- service environment
- startup command wiring

`scripts/entrypoint.sh` should do only what cannot be expressed cleanly in the service definition. After this cleanup, that should be limited to lightweight directory preparation, if any remains necessary.

### Config placement

The image already imports `inputs.opencode-config.homeManagerModules.default`. That module expects a normal per-user XDG layout under `HOME`, which resolves to `~/.config/opencode`. No explicit `OPENCODE_CONFIG_DIR` is needed as long as `HOME` is correct.

### Filesystem contract

Supported runtime paths after cleanup:

- `/var/lib/opencode` as the user home and XDG config base
- `/workspace` as the mounted working directory

Unsupported path after cleanup:

- `/data`, because no component currently reads or writes to it

### CI contract

The workflow should match the repo's real guarantees. If the standalone smoke script is removed, CI should stop referring to it. The flake should also stop exposing a check that only verifies script executability.

## File Impact

- `flake.nix`: remove `checks.smoke-script` and its dependency on `scripts/smoke.sh`
- `nix/system.nix`: keep canonical `HOME` and `PORT`; stop creating `/data`
- `scripts/entrypoint.sh`: remove `PORT` and `HOME` fallback duplication if already provided by systemd; remove `OPENCODE_CONFIG_DIR`; stop creating `/data`
- `README.md`: remove `/data` mount requirement and any implication that config dir must be set manually
- `.github/workflows/publish.yml`: remove smoke-script invocation
- `scripts/smoke.sh`: delete

## Verification

After implementation, verify:

1. `nix build .#packages.x86_64-linux.default` still succeeds.
2. The image still starts `opencode web` as the `opencode` user.
3. `HOME` resolves to `/var/lib/opencode`.
4. OpenCode config is discovered from `~/.config/opencode` without `OPENCODE_CONFIG_DIR`.
5. README and CI no longer mention `/data` or `scripts/smoke.sh`.

## Risks

- If `opencode web` was implicitly relying on `PORT` or `HOME` fallback behavior inside the entrypoint, removing those defaults could break startup if systemd env is changed later.
- Removing smoke coverage reduces runtime validation in CI until a replacement is added.

These risks are acceptable for this cleanup because the service already sets the canonical env, and the current smoke check mostly validates shell glue rather than core image correctness.
