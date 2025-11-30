{
  pkgs,
  config,
  private-settings,
  ...
}:
{
  vm = {
    id = 2212;
    name = "SRV-GIT";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ config.services.forgejo.settings.server.HTTP_PORT ];
    networking.openPorts.udp = [ config.services.forgejo.settings.server.HTTP_PORT ];
  };

  users.users.git.group = "git";
  users.users.git.isNormalUser = true;
  users.groups.git = { };

  services.forgejo = {
    enable = true;
    package = pkgs.forgejo;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = rec {
        DOMAIN = "git.${private-settings.domains.home}";
        ROOT_URL = "https://${DOMAIN}/";
        HTTP_PORT = 3000;
      };
      session = {
        PROVIDER = "db";
        SESSION_LIFE_TIME = 8640000;
      };
      cors = {
        ENABLED = true;
        ALLOW_DOMAIN = builtins.concatStringsSep ", " [
          "https://*.${private-settings.domains.home}"
          "https://*.${private-settings.domains.personal}"
          "https://*.${private-settings.domains.blog}"
        ];
      };
      service.DISABLE_REGISTRATION = true;
      "repository.signing" = {
        DEFAULT_TRUST_MODEL = "collaboratorcommitter";

        FORMAT = "ssh";
        SIGNING_KEY = "/etc/ssh/ssh_host_ed25519_key.pub";
        SIGNING_NAME = "git.${private-settings.domains.home} Instance";
        SIGNING_EMAIL = "noreply@git.${private-settings.domains.home}";
        INITIAL_COMMIT = "always";
        WIKI = "pubkey";
        CRUD_ACTIONS = "pubkey, parentsigned";
        MERGES = "pubkey, commitssigned";
      };
    };
  };

  fail2ban.enable = true;
  fail2ban.doNotBan = [ "192.168.0.0/16" ];

  nas.extraUsers = [ config.services.forgejo.user ];

  nas.backup.enable = true;
  rsync."forgejo" = {
    tasks = [
      {
        from = "${config.services.forgejo.stateDir}";
        to = "${config.nas.backup.stateLocation}/forgejo";
        chown = "${config.services.forgejo.user}:${config.services.forgejo.group}";
        extraFlags = "-L";
      }
    ];
  };
}
