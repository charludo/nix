{ config, lib, ... }:
let
  cfg = config.services.nginx;
in
{
  options.services.nginx.debug = lib.mkEnableOption "nginx debug logging into journald";

  config = lib.mkIf cfg.debug {
    services.nginx.appendHttpConfig = ''
      error_log stderr;
      access_log syslog:server=unix:/dev/log combined;
    '';
  };
}
