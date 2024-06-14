{ config, ... }:
{
  sops.secrets.zammad = { mode = "0444"; path = "/var/lib/zammad/secret"; };
  services.zammad = {
    enable = true;
    openPorts = true;
    secretKeyBaseFile = config.sops.secrets.zammad.path;
  };
}
