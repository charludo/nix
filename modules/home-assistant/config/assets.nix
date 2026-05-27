{ config, ... }:
let
  # Static images referenced from Lovelace cards. HA only serves files
  # under `${configDir}/www` (mapped to `/local/...` in the browser),
  # so we expose nix-store paths from this repo via tmpfiles symlinks.
  # Sources live in `assets/` alongside this file; adjust there.
  www = "${config.services.home-assistant.configDir}/www";
in
{
  systemd.tmpfiles.rules = [
    # `L+` doesn't create parent directories, so make sure /www exists
    # before symlinking the per-asset folders into it.
    "d ${www} 0755 hass hass -"
    "L+ ${www}/bambu - - - - ${./assets/bambu}"
  ];
}
