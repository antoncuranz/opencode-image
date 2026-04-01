{ pkgs, ... }:

{
  home.stateVersion = "25.11";
  home.username = "opencode";
  home.homeDirectory = "/home/opencode";

  programs.gh = {
    enable = true;
    settings.git_protocol = "https";
  };

  programs.git = {
    enable = true;
    settings.credential.helper = "!${pkgs.gh}/bin/gh auth git-credential";
  };
}
