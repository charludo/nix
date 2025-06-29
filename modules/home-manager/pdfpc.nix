{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.pdfpc;
in
{
  options.desktop.pdfpc.enable = lib.mkEnableOption "enable PDF Presenter's Console";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.pdfpc ];
    home.file.".config/pdfpc/pdfpcrc".text = # bash
      ''
        option black-on-end true
        option current-height 60
        option current-size 56
        option disable-scrolling true
        option final-slide true
        option next-height 35
        option prerender-slides -1
      '';
    home.shellAliases.pdfpc = "pdfpc --notes=right";
  };
}
