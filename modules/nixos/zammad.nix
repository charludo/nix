{
  config,
  lib,
  secrets,
  ...
}:

with lib;
let
  cfg = config.zammad;
in
{
  options.zammad = {
    enable = lib.mkEnableOption (lib.mdDoc "enable zammad (ugh)");
  };

  config = mkIf cfg.enable {
    age.secrets.zammad = {
      rekeyFile = secrets.zammad;
      mode = "0444";
      path = "/var/lib/zammad/secret";
    };
    services.zammad = {
      enable = true;
      openPorts = true;
      database.port = 5433;
      secretKeyBaseFile = config.age.secrets.zammad.path;
    };
    services.postgresql.settings.port = 5433;
  };
}
