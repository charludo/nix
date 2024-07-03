{ config, pkgs, lib, ... }:
let
  zfs-check = pkgs.writeShellApplication {
    name = "zfs-check";
    runtimeInputs = with pkgs; [ zfs gnugrep ];
    text = ''
      zpool status | grep -B 5 -A 5 -E -i '(DEGRADED|FAULTED|OFFLINE|UNAVAIL|REMOVED|FAIL|DESTROYED|corrupt|cannot|unrecover)'
    '';
  };
  smartd-check = pkgs.writeShellApplication {
    name = "smartd-check";
    runtimeInputs = with pkgs; [ gawk gnugrep util-linux smartmontools ];
    text = ''
      check_disk_health() {
          local disk=$1
          local status
          status=$(smartctl -H "$disk" | grep overall-health | awk 'match($0, "result:"){print substr($0, RSTART+8, 6)}')
          echo "$disk: $status"

          if [ "$status" = "PASSED" ]; then
              return 0
          else
              return 1
          fi
      }

      disks=$(lsblk -o NAME --nodeps --noheadings | awk '{print "/dev/"$1}')
      overall_status=0

      for disk in $disks; do
          check_disk_health "$disk"
          result=$?
          if [ $result -ne 0 ]; then
              overall_status=$result
          fi
      done

      exit $overall_status
    '';
  };
  notify-telegram = pkgs.writeShellApplication {
    name = "notify-telegram";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      while getopts ":m:" opt; do
          case "$opt" in
              m) TEXT=$OPTARG ;;
              *) echo "Unknown param: $opt" ;;
          esac
      done

      # shellcheck disable=SC1091
      source "${if builtins.hasAttr "telegram-bot" config.sops.secrets then config.sops.secrets.telegram-bot.path else ""}"

      if [ -z "$TOKEN" ]; then exit 1; fi
      if [ -z "$CHATID" ]; then exit 1; fi
      if [ -z "$TEXT" ]; then exit 1; fi

      URL="https://api.telegram.org/bot$TOKEN/sendMessage"
      TIMEOUT=10

      CMDARGS="chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT"

      curl -s --max-time $TIMEOUT -d "$CMDARGS" "$URL" 2>&1
    '';
  };
  send-telegram = pkgs.writeShellApplication {
    name = "send-telegram";
    runtimeInputs = [ notify-telegram ];
    text = ''
      set +o nounset
      ${notify-telegram}/bin/notify-telegram -m "Monit $MONIT_SERVICE - $MONIT_EVENT at $MONIT_DATE on $MONIT_HOST: $MONIT_ACTION $MONIT_DESCRIPTION."
    '';
  };
  alertTelegram = "${send-telegram}/bin/send-telegram";

  mkMonitOption = configBlock: {
    enable = lib.mkEnableOption "enable this monit config";
    config = lib.mkOption {
      type = lib.types.str;
      default = configBlock;
    };
  };
  enabledMonitOptions = (lib.filterAttrs (name: option: option ? enable && option.enable == true) config.monitConfig);
  monitConfigBlocks = lib.concatStringsSep "\n\n" (
    lib.mapAttrsToList (name: option: option.config) enabledMonitOptions
  );
  cfg = config.monitConfig;
in
{
  options.monitConfig = {
    enable = lib.mkEnableOption "monitoring via monit";
    adminPassword = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "password monit uses for the admin interface";
    };
    polling = lib.mkOption {
      type = lib.types.str;
      default = ''
        set daemon 120 with start delay 60
      '';
    };
    mailServer = lib.mkOption {
      type = lib.types.str;
      default = ''
        set mailserver
          localhost
      '';
    };
    alertAddress = lib.mkOption {
      type = lib.types.str;
      description = "email address to notify";
    };

    adminInterface = mkMonitOption ''
      set httpd port 2812 and use address localhost
        allow localhost
        allow admin:${cfg.adminPassword}
    '';

    system = mkMonitOption ''
      check system $HOST
        if cpu usage > 95% for 10 cycles then alert
        if memory usage > 75% for 5 cycles then alert
        if swap usage > 20% for 10 cycles then alert
        if loadavg (1min) > 90 for 15 cycles then alert
        if loadavg (5min) > 80 for 10 cycles then alert
        if loadavg (15min) > 70 for 8 cycles then alert

        if cpu usage > 95% for 10 cycles then exec ${alertTelegram}
        if memory usage > 75% for 5 cycles then exec ${alertTelegram}
        if swap usage > 20% for 10 cycles then exec ${alertTelegram}
        if loadavg (1min) > 90 for 15 cycles then exec ${alertTelegram}
        if loadavg (5min) > 80 for 10 cycles then exec ${alertTelegram}
        if loadavg (15min) > 70 for 8 cycles then exec ${alertTelegram}
    '';

    filesystem = mkMonitOption ''
      check filesystem root with path /
        if space usage > 80% then alert
        if inode usage > 80% then alert
        
        if space usage > 80% then exec ${alertTelegram}
        if inode usage > 80% then exec ${alertTelegram}
    '';

    sshd = mkMonitOption ''
      check process sshd with pidfile /var/run/sshd.pid
        start program  "${pkgs.systemd}/bin/systemctl start sshd"
        stop program  "${pkgs.systemd}/bin/systemctl stop sshd"
        if failed port 22 protocol ssh for 2 cycles then restart
        if failed port 22 protocol ssh for 2 cycles then exec ${alertTelegram}
    '';

    postfix = mkMonitOption ''
      check process postfix with pidfile /var/lib/postfix/queue/pid/master.pid
        start program = "${pkgs.systemd}/bin/systemctl start postfix"
        stop program = "${pkgs.systemd}/bin/systemctl stop postfix"
        if failed port 25 protocol smtp for 5 cycles then restart
        if failed port 25 protocol smtp for 5 cycles then restart
    '';

    dovecot = mkMonitOption ''
      check process dovecot with pidfile /var/run/dovecot2/master.pid
        start program = "${pkgs.systemd}/bin/systemctl start dovecot2"
        stop program = "${pkgs.systemd}/bin/systemctl stop dovecot2"
        if failed host ${config.mailserver.fqdn} port 993 type tcpssl sslauto protocol imap for 5 cycles then restart
        if failed host ${config.mailserver.fqdn} port 993 type tcpssl sslauto protocol imap for 5 cycles then exec ${alertTelegram}
    '';

    rspamd = mkMonitOption ''
      check process rspamd with matching "rspamd: main process"
        start program = "${pkgs.systemd}/bin/systemctl start rspamd"
        stop program = "${pkgs.systemd}/bin/systemctl stop rspamd"
    '';

    smartd = mkMonitOption ''
      check program smartd with path "${smartd-check}/bin/smartd-check"
        every 120 cycles
        if status > 0 then alert
        if status > 0 then exec ${alertTelegram}
    '';

    zfs = mkMonitOption ''
      check program zfs-check with path "${zfs-check}/bin/zfs-check"
        if status == 0 then alert
        if status == 0 then exec ${alertTelegram}
    '';

    extraConfig = mkMonitOption "";
  };
  config = lib.mkIf cfg.enable {
    services.monit = {
      enable = true;
      config = ''
        set alert ${cfg.alertAddress}
        ${cfg.polling}
        ${cfg.mailServer}
        ${monitConfigBlocks}
      '';
    };
  };
}

