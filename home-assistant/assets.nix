{ config, ... }:
let
  www = "${config.services.home-assistant.configDir}/www";
in
{
  systemd.tmpfiles.rules = [
    "d ${www} 0755 hass hass -"
    "L+ ${www}/bambu - - - - ${./assets/bambu}"
    "L+ ${www}/sounds - - - - ${./assets/sounds}"
  ];
}
