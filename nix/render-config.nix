{ inputs, pkgs }:

let
  home = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      inputs.opencode-config.homeManagerModules.default
      ./home.nix
    ];
  };
in
pkgs.runCommand "opencode-config-root" {} ''
  mkdir -p "$out/home/opencode"
  cp -R ${home.config.home-files}/. "$out/home/opencode/"
''
