{ config, ... }:
{
  vm = {
    id = 2102;
    name = "SRV-SUWAYOMI";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "32G";

    certsFor = [
      {
        name = "suwayomi";
        port = config.services.suwayomi-server.settings.server.port;
      }
      {
        name = "readarr";
        port = config.services.readarr.settings.server.port;
      }
    ];
  };

  surfshark = {
    enable = true;
    alwaysOn = true;
    hopWeekly = true;
    iptables = {
      enable = true;
      enforceForUsers = [ config.services.suwayomi-server.user ];
    };
  };

  networking.interfaces.ens18.ipv4.routes = [
    {
      address = "192.168.0.0";
      prefixLength = 16;
      via = config.vm.networking.gateway;
    }
  ];

  services.suwayomi-server = {
    enable = true;
    openFirewall = true;

    dataDir = "/var/lib/suwayomi-server";

    settings.server = {
      extensionRepos = [
        "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
        "https://raw.githubusercontent.com/ThePBone/tachiyomi-extensions-revived/repo/index.min.json"
      ];
      downloadAsCbz = true;
      flareSolverrEnabled = true;
      autoDownloadNewChapters = true;
    };
  };
  users.groups.${config.services.suwayomi-server.user}.gid = 995;

  services.flaresolverr.enable = true;

  services.readarr = {
    enable = true;
    openFirewall = true;
  };

  systemd = {
    services.suwayomi-server.after = [ "media-NAS.mount" ];
    services.readarr.after = [ "media-NAS.mount" ];
  };

  nas.enable = true;
  nas.extraUsers = [
    config.services.suwayomi-server.user
    config.services.readarr.user
  ];

  # this makes the downloaded Mangas available to Kavita
  rsync."suwayomi-content" = {
    tasks = [
      {
        prefixCommand = "find ${config.services.suwayomi-server.dataDir}/.local/share/Tachidesk/downloads/mangas/*/ -maxdepth 0 -type d -exec";
        suffixCommand = "\\;"; # terminates exec
        from = "{}"; # uses the results from find
        to = "${config.nas.location}/Manga";
      }
    ];
    requires = [
      "media-NAS.mount"
    ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    restore = false;
  };

  nas.backup.enable = true;
  rsync."suwayomi" = {
    tasks = [
      {
        from = "${config.services.suwayomi-server.dataDir}";
        to = "${config.nas.backup.stateLocation}/suwayomi";
        chown = "${config.services.suwayomi-server.user}:${config.services.suwayomi-server.group}";
      }
    ];
  };
  rsync."readarr" = {
    tasks = [
      {
        from = "${config.services.readarr.dataDir}";
        to = "${config.nas.backup.stateLocation}/torrenter/readarr2";
        chown = "${config.services.readarr.user}:${config.services.readarr.group}";
      }
    ];
  };
}
