{
  description = "Standard OCI image for OpenCode web";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opencode = {
      url = "github:anomalyco/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opencode-config.url = "github:antoncuranz/opencode-config";
  };

  outputs = inputs@{ nixpkgs, nixpkgs-unstable, flake-utils, opencode, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        nixpkgsConfig = {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [ "1password-cli" ];
        };
        unstablePkgs = import nixpkgs-unstable nixpkgsConfig;
        pkgs = import nixpkgs {
          inherit system;
          config = nixpkgsConfig.config;
          overlays = [
            (final: _prev: {
              bun = unstablePkgs.bun;
            })
            opencode.overlays.default
          ];
        };
        opencodePkg = pkgs.opencode;
        entrypoint = pkgs.writeShellApplication {
          name = "opencode-entrypoint";
          runtimeInputs = with pkgs; [ coreutils opencodePkg ];
          text = builtins.readFile ./scripts/entrypoint.sh;
        };
        configRoot = import ./nix/render-config.nix {
          inherit inputs pkgs;
          opencodePkg = opencodePkg;
        };
        runtimeRoot = pkgs.runCommand "opencode-runtime-root" {} ''
          mkdir -p "$out/etc/ssl/certs" "$out/home/opencode" "$out/usr/bin" "$out/workspace"
          cat > "$out/etc/passwd" <<'EOF'
          root:x:0:0:root:/root:/bin/bash
          opencode:x:1000:1000:OpenCode:/home/opencode:/bin/bash
          EOF
          cat > "$out/etc/group" <<'EOF'
          root:x:0:
          opencode:x:1000:
          EOF
          ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt "$out/etc/ssl/certs/ca-bundle.crt"
          ln -s ${pkgs.coreutils}/bin/env "$out/usr/bin/env"
        '';
        image = pkgs.dockerTools.buildLayeredImage {
          name = "opencode-image";
          tag = "latest";
          contents = with pkgs; [
            bash
            cacert
            chromium
            coreutils
            curl
            fluxcd
            git
            gh
            gnugrep
            gnutar
            gnumake
            go
            helm
            iputils
            jq
            kubectl
            less
            nix
            ncurses
            nodejs_24
            noto-fonts
            _1password-cli
            libpq.pg_config
            procps
            postgresql
            (python312.withPackages (ps: with ps; [ pip rich ]))
            ripgrep
            talosctl
            bun
            unzip
            vim
            wget
            which
            yq
            opencodePkg
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
              "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
              "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
              "CURL_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt"
              "GIT_SSL_CAINFO=/etc/ssl/certs/ca-bundle.crt"
              "NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-bundle.crt"
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
