{
  config,
  lib,
  pkgs,
  private-settings,
  ...
}:
let
  cfg = config.vm;
  profile = "/nix/var/nix/profiles/system";
  manifestUrl = "https://cache.${private-settings.domains.blog}/ci-builds.json";
  rebootWindow = {
    lower = "03:00";
    upper = "05:00";
  };
in
{
  options.vm.unsupervisedUpdates = lib.mkEnableOption "unsupervised nightly updates of the VM";

  config = lib.mkIf cfg.unsupervisedUpdates {
    snow.tags = [ "unsupervised-updates" ];

    systemd.services.unsupervised-updates = {
      description = "Switch to the system CI built for this VM";
      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;
      serviceConfig.Type = "oneshot";

      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment.HOME = "/root";
      path = [
        config.nix.package
        config.systemd.package
        pkgs.coreutils
        pkgs.curl
        pkgs.jq
      ];

      script = ''
        set -o pipefail
        new="$(curl -fsS --retry 5 --netrc-file ${config.age.secrets.nix-cache-netrc.path} ${manifestUrl} \
          | jq -er --arg vm ${lib.escapeShellArg cfg.name} '.nixosConfigurations[$vm]')"

        case "$new" in
          /nix/store/*-nixos-system-${config.system.name}-*) ;;
          *)
            echo "refusing unexpected store path: $new" >&2
            exit 1
            ;;
        esac

        if [ "$new" = "$(readlink -f ${profile})" ]; then
          echo "already on $new"
          exit 0
        fi

        nix build --no-link --profile ${profile} "$new"

        booted="$(readlink /run/booted-system/{initrd,kernel,kernel-modules})"
        built="$(readlink ${profile}/{initrd,kernel,kernel-modules})"
        now="$(date +%H:%M)"

        if [ "$booted" = "$built" ] \
          || [[ "$now" < "${rebootWindow.lower}" ]] || [[ "$now" > "${rebootWindow.upper}" ]]; then
          ${profile}/bin/switch-to-configuration switch
        else
          ${profile}/bin/switch-to-configuration boot
          shutdown -r +1
        fi
      '';

      startAt = rebootWindow.lower;
    };

    systemd.timers.unsupervised-updates.timerConfig = {
      RandomizedDelaySec = "2h";
      FixedRandomDelay = true;
      Persistent = false;
    };
  };
}
