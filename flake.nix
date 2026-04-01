{
  description = "Standard OCI image for OpenCode web";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opencode-config.url = "github:antoncuranz/opencode-config";
  };

  outputs = inputs@{ nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        entrypoint = pkgs.writeShellApplication {
          name = "opencode-entrypoint";
          runtimeInputs = with pkgs; [ coreutils opencode ];
          text = builtins.readFile ./scripts/entrypoint.sh;
        };
        configRoot = import ./nix/render-config.nix {
          inherit inputs pkgs;
        };
        runtimeRoot = pkgs.runCommand "opencode-runtime-root" {} ''
          mkdir -p "$out/etc" "$out/home/opencode" "$out/workspace"
          cat > "$out/etc/passwd" <<'EOF'
          root:x:0:0:root:/root:/bin/bash
          opencode:x:1000:1000:OpenCode:/home/opencode:/bin/bash
          EOF
          cat > "$out/etc/group" <<'EOF'
          root:x:0:
          opencode:x:1000:
          EOF
        '';
        image = pkgs.dockerTools.buildLayeredImage {
          name = "opencode-image";
          tag = "latest";
          contents = with pkgs; [
            bash
            cacert
            coreutils
            curl
            git
            gh
            gnugrep
            jq
            less
            procps
            ripgrep
            opencode
            entrypoint
            configRoot
            runtimeRoot
          ];
          fakeRootCommands = ''
            chown -R 1000:1000 home/opencode workspace
          '';
          config = {
            Entrypoint = [ "/bin/opencode-entrypoint" ];
            Env = [
              "HOME=/home/opencode"
              "PORT=4096"
            ];
            User = "1000:1000";
            WorkingDir = "/workspace";
          };
        };
      in {
        packages.default = image;
        packages.oci-image = image;

        checks.smoke-script = pkgs.runCommand "smoke-script" {} ''
          test -x ${./scripts/smoke.sh}
          touch "$out"
        '';
      });
}
