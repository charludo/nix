{
  config,
  private-settings,
  pkgs,
  ...
}:
let
  inherit (private-settings) domains;
in
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2209;
    name = "SRV-VIKUNJA";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ config.services.vikunja.port ];
  };

  services.vikunja = {
    enable = true;
    frontendScheme = "https";
    frontendHostname = "planning.${domains.home}";
    settings.service.enableregistration = false;
  };

  nas.enable = true;
  nas.backup.enable = true;

  systemd = {
    timers."vikunja-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "vikunja-backup-daily.service";
      };
    };
    services."vikunja-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.location})" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /var/lib/vikunja/ ${config.nas.backup.location}/vikunja
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      vikunja-init = pkgs.writeShellApplication {
        name = "vikunja-init";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.nas.backup.location}/vikunja/ /var/lib/vikunja
        '';
      };
    in
    [
      vikunja-init
      pkgs.rsync
    ];

  system.stateVersion = "23.11";
}
