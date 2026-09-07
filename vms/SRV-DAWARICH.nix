{
  config,
  lib,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2225;
    name = "SRV-DAWARICH";

    hardware.cores = 4;
    hardware.memory = 4096;
    hardware.storage = "32G";

    networking.openPorts.tcp = [ 80 ];
  };

  services.dawarich = {
    enable = true;
    localDomain = "dawarich.${private-settings.domains.home}";
    configureNginx = true;
    # Safe now that nginx below tells Rails the request was TLS. On its own this
    # only produced a redirect loop.
    environment = {
      APPLICATION_PROTOCOL = "https";
    };

    secretKeyBaseFile = config.age.secrets.dawarich.path;
  };
  age.secrets.dawarich.rekeyFile = secrets.dawarich;

  # Rails has to be told the outer leg was TLS. nginx's recommendedProxySettings
  # sets `X-Forwarded-Proto $scheme`, which is "http" on the HAProxy→nginx hop,
  # and it overwrites whatever HAProxy sent — so this cannot be fixed at HAProxy.
  #
  # Everything Rails derives from that header then goes wrong, in two stages:
  #   * with APPLICATION_PROTOCOL=https, force_ssl sees an insecure request and
  #     301s to https forever;
  #   * without it, the CSRF origin check compares the browser's
  #     `Origin: https://…` against a base_url of `http://…`, answers POSTs with
  #     422, and Turbo silently re-renders the form — a login that clears its
  #     fields and shows no error. Absolute redirects also come out http://.
  #
  # nginx never dedupes proxy_set_header, so a second directive for the same
  # header would emit it twice. Drop the recommended block for this location and
  # restate it with the proto pinned: nginx here is only ever reached through
  # HAProxy, which always terminates TLS, so https is unconditionally correct.
  services.nginx.virtualHosts.${config.services.dawarich.localDomain}.locations."@proxy" = {
    recommendedProxySettings = lib.mkForce false;
    extraConfig = ''
      proxy_set_header        Host $host;
      proxy_set_header        X-Real-IP $remote_addr;
      proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header        X-Forwarded-Proto https;
      proxy_set_header        X-Forwarded-Host $host;
      proxy_set_header        X-Forwarded-Server $hostname;
    '';
  };

  services.postgresqlBackup = {
    enable = true;
    databases = [ config.services.dawarich.database.name ];
    startAt = "*-*-* 02:00:00";
  };

  nas.backup.enable = true;
  rsync."dawarich" = {
    tasks = [
      {
        from = "/var/lib/dawarich";
        to = "${config.nas.backup.stateLocation}/dawarich/dawarich";
        chown = "${config.services.dawarich.user}:${config.services.dawarich.group}";
      }
      {
        from = config.services.postgresqlBackup.location;
        to = "${config.nas.backup.stateLocation}/dawarich/postgres";
        chown = "postgres:postgres";
      }
    ];
    timerConfig = {
      OnCalendar = "*-*-* 02:15:00";
      Persistent = true;
    };
  };
}
