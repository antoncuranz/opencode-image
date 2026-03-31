{ inputs, pkgs, ... }:

let
  entrypoint = pkgs.writeShellScriptBin "opencode-entrypoint" (builtins.readFile ../scripts/entrypoint.sh);
in
{
  system.stateVersion = "25.11";

  boot.isContainer = true;

  documentation.enable = false;
  networking.hostName = "opencode-web";
  networking.useHostResolvConf = false;
  services.resolved.enable = false;

  users.users.opencode = {
    isNormalUser = true;
    uid = 1000;
    group = "opencode";
    home = "/var/lib/opencode";
    createHome = true;
    shell = pkgs.bashInteractive;
    extraGroups = [ "users" ];
  };

  users.groups.opencode = {};

  environment.systemPackages = with pkgs; [
    bashInteractive
    cacert
    coreutils
    curl
    git
    gh
    gnugrep
    jq
    less
    openssh
    procps
    ripgrep
    opencode
    entrypoint
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.opencode = import ./home.nix;
  home-manager.sharedModules = [ inputs.opencode-config.homeManagerModules.default ];

  systemd.services.opencode-web = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      User = "opencode";
      Group = "opencode";
      WorkingDirectory = "/workspace";
      Environment = [
        "HOME=/var/lib/opencode"
        "PORT=4096"
      ];
      ExecStart = "${entrypoint}/bin/opencode-entrypoint";
      Restart = "always";
      RestartSec = 2;
    };
  };

  system.activationScripts.opencodeDirs.text = ''
    mkdir -p /workspace /var/lib/opencode
    chown -R opencode:opencode /workspace /var/lib/opencode
  '';
}
