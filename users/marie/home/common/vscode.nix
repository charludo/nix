{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
    ];
    userSettings = {
      "git.enableSmartCommit" = true;
      "nix.formatterPath" = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
      "nix.serverPath" = "${pkgs.nil}/bin/nil";
      "nix.serverSettings" = {
        "nil" = {
          "formatting" = {
            "command" = [
              "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt"
            ];
          };
        };
      };
      "nix.enableLanguageServer" = true;
      "editor.formatOnSave" = true;
    };
  };
  home.packages = [ pkgs.nil pkgs.nixpkgs-fmt ];
}
