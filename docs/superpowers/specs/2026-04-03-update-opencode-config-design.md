# Update opencode-config flake input

Goal
- Update opencode-config flake input to the latest commit from github:antoncuranz/opencode-config and push the change to main.

Recommendation
- Use `nix flake update --update-input opencode-config` to update flake.lock while keeping flake.nix unchanged.

Steps
1. Ensure working tree clean.
2. Run `nix flake update --update-input opencode-config`.
3. Inspect `git diff` and verify only flake.lock changed.
4. Commit with message: `deps(lock): update opencode-config`.
5. Push commit to `main`.

Risks
- Remote push may fail if credentials or remotes are misconfigured.
- flake.lock may include unrelated changes if update command was not limited.

