# Runtime Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove redundant runtime configuration from `opencode-nixos-web-image`, rely on `opencode-config` for config discovery, and delete dead `/data` and smoke-script surface.

**Architecture:** Keep `nix/system.nix` as the single source of truth for runtime env and path ownership. Keep `/var/lib/opencode` as `HOME` and `/workspace` as the service working directory. Remove explicit `OPENCODE_CONFIG_DIR`, remove `/data`, and update CI/docs to match the smaller runtime contract.

**Tech Stack:** Nix flakes, NixOS modules, Home Manager, shell entrypoint, GitHub Actions.

---

## File Structure

Files to modify:

- `/Users/ant0n/Developer/opencode-nixos-web-image/flake.nix` - remove the smoke-script check output
- `/Users/ant0n/Developer/opencode-nixos-web-image/nix/system.nix` - keep canonical runtime env and remove `/data`
- `/Users/ant0n/Developer/opencode-nixos-web-image/scripts/entrypoint.sh` - remove duplicate env defaults and `/data` setup
- `/Users/ant0n/Developer/opencode-nixos-web-image/README.md` - remove `/data` contract and clarify config discovery
- `/Users/ant0n/Developer/opencode-nixos-web-image/.github/workflows/publish.yml` - remove smoke script step

Files to delete:

- `/Users/ant0n/Developer/opencode-nixos-web-image/scripts/smoke.sh` - remove unused standalone runtime smoke script

## Task 1: Remove smoke-script plumbing

**Files:**
- Modify: `/Users/ant0n/Developer/opencode-nixos-web-image/flake.nix`
- Modify: `/Users/ant0n/Developer/opencode-nixos-web-image/.github/workflows/publish.yml`
- Delete: `/Users/ant0n/Developer/opencode-nixos-web-image/scripts/smoke.sh`
- Test: `nix build .#packages.x86_64-linux.default`

- [ ] **Step 1: Remove the flake check that only validates script executability**

Delete the `checks.smoke-script = pkgs.runCommand ...` block from `flake.nix` so the flake stops advertising a check for a script that is being removed.

- [ ] **Step 2: Remove the workflow smoke-test step**

Delete the `Smoke test` step from `.github/workflows/publish.yml` that runs `chmod +x scripts/smoke.sh && CONTAINER_ENGINE=docker ./scripts/smoke.sh "$IMAGE_REF"`.

- [ ] **Step 3: Delete `scripts/smoke.sh`**

Remove the file entirely.

- [ ] **Step 4: Verify the image still builds**

Run: `nix build .#packages.x86_64-linux.default`
Expected: build succeeds and produces the OCI image artifact without referring to `scripts/smoke.sh`.

- [ ] **Step 5: Commit**

```bash
git add flake.nix .github/workflows/publish.yml scripts/smoke.sh
git commit -m "refactor: drop unused smoke script"
```

## Task 2: Make systemd the single env source

**Files:**
- Modify: `/Users/ant0n/Developer/opencode-nixos-web-image/nix/system.nix`
- Modify: `/Users/ant0n/Developer/opencode-nixos-web-image/scripts/entrypoint.sh`
- Test: `nix build .#packages.x86_64-linux.default`

- [ ] **Step 1: Keep canonical runtime env in `nix/system.nix`**

Ensure `systemd.services.opencode-web.serviceConfig.Environment` remains the only place that sets `HOME=/var/lib/opencode` and `PORT=4096`.

- [ ] **Step 2: Remove duplicate env defaults from `scripts/entrypoint.sh`**

Delete:

```bash
export HOME="${HOME:-/var/lib/opencode}"
export PORT="${PORT:-4096}"
export OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
```

The resulting entrypoint should only prepare required directories and execute:

```bash
exec opencode web --hostname 0.0.0.0 --port "$PORT"
```

- [ ] **Step 3: Rebuild the image**

Run: `nix build .#packages.x86_64-linux.default`
Expected: build succeeds with the simplified entrypoint.

- [ ] **Step 4: Commit**

```bash
git add nix/system.nix scripts/entrypoint.sh
git commit -m "refactor: centralize runtime env"
```

## Task 3: Remove dead `/data` contract

**Files:**
- Modify: `/Users/ant0n/Developer/opencode-nixos-web-image/nix/system.nix`
- Modify: `/Users/ant0n/Developer/opencode-nixos-web-image/scripts/entrypoint.sh`
- Modify: `/Users/ant0n/Developer/opencode-nixos-web-image/README.md`
- Test: `grep -R "/data" /Users/ant0n/Developer/opencode-nixos-web-image`

- [ ] **Step 1: Stop creating `/data` in activation**

Change the activation script in `nix/system.nix` so it only creates and owns paths that are still part of the contract.

Expected remaining paths:

```text
/workspace
/var/lib/opencode
```

- [ ] **Step 2: Stop creating `/data` in the entrypoint**

Update `mkdir -p` in `scripts/entrypoint.sh` so it no longer includes `/data`.

- [ ] **Step 3: Remove `/data` from README**

Delete:

- the `-v /path/to/data:/data` example mount
- the `Required mounts` bullet that says `/data` is for persistent state

Add a short note that config is discovered from the baked-in Home Manager setup under `~/.config/opencode`.

- [ ] **Step 4: Verify no `/data` references remain**

Run: `rg '/data' .`
Expected: no matches, or only historical docs you intentionally keep.

- [ ] **Step 5: Commit**

```bash
git add nix/system.nix scripts/entrypoint.sh README.md
git commit -m "refactor: remove unused data mount"
```

## Task 4: Verify config discovery and docs coherence

**Files:**
- Modify: `/Users/ant0n/Developer/opencode-nixos-web-image/README.md`
- Test: runtime manual check after build

- [ ] **Step 1: Clarify config behavior in README**

Document that the image bakes in `opencode-config` and relies on the default per-user XDG location under the `opencode` user's home, so `OPENCODE_CONFIG_DIR` does not need to be set.

- [ ] **Step 2: Run manual runtime verification**

Run a local container command equivalent to the current README example, but without `/data` and without `OPENCODE_CONFIG_DIR`.

Expected:

- service starts
- `HOME` is `/var/lib/opencode`
- `opencode web` is reachable on port `4096`

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: align runtime contract with opencode-config"
```

## Self-Review

- Spec coverage: all approved cleanup items are represented: smoke script removal, env deduplication, `OPENCODE_CONFIG_DIR` removal, `/data` removal, README/workflow alignment.
- Placeholder scan: commands and touched files are concrete.
- Consistency: plan keeps `HOME=/var/lib/opencode` and `/workspace` as working directory throughout.
