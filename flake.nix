{
  description = "Rootless NixOS OCI image for OpenCode web";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.11";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    opencode-config.url = "github:antoncuranz/opencode-config";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, home-manager, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        nixosConfiguration = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./nix/system.nix
            home-manager.nixosModules.home-manager
            "${nixpkgs}/nixos/modules/virtualisation/docker-image.nix"
          ];
        };
      in {
        nixosConfigurations.opencode-web = nixosConfiguration;
        packages.default = nixosConfiguration.config.system.build.tarball;
      });
}
