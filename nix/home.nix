{ ... }:

{
  home.stateVersion = "25.11";
  home.username = "opencode";
  home.homeDirectory = "/var/lib/opencode";

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    settings.git_protocol = "https";
  };
}
