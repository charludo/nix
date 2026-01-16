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
  options.desktop.vscode.enable = lib.mkEnableOption "VSCodium config";

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
          "nix.formatterPath" = "${lib.getExe pkgs.nixfmt}";
          "nix.serverPath" = "${lib.getExe pkgs.nil}";
          "nix.serverSettings" = {
            "nil" = {
              "formatting" = {
                "command" = [
                  "${lib.getExe pkgs.nixfmt}"
                ];
              };
            };
          };
          "nix.enableLanguageServer" = true;
          "editor.formatOnSave" = true;
          "editor.fontFamily" = "${config.fontProfiles.monospace.family}";
        };
      };
    };
    home.packages = [
      pkgs.nil
      pkgs.nixfmt
    ];
  };
}
