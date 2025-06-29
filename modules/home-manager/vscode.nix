{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.vscode;
in
{
  options.desktop.vscode.enable = lib.mkEnableOption "enable VSCodium config";

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      package = pkgs.vscodium;
      profiles.default = {
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
                  "${pkgs.nixfmt-rfc-style}/bin/nixfmt"
                ];
              };
            };
          };
          "nix.enableLanguageServer" = true;
          "editor.formatOnSave" = true;
        };
      };
    };
    home.packages = [
      pkgs.nil
      pkgs.nixfmt-rfc-style
    ];
  };
}
