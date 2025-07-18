{ config, lib, ... }:

with lib;
let
  cfg = config.keyring;
in
{
  options.keyring = {
    enable = lib.mkEnableOption "a keyring provider";
  };

  config = mkIf cfg.enable {
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;
  };
}
