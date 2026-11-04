{
  config,
  lib,
  private-settings,
  secrets,
  ...
}:
{
  gitea-runners = {
    enable = true;
    runners = {
      ci-buildbot = {
        tokenFile.secret = secrets.gitea-runner-token-ci-buildbot;
        makeNixRunner = true;
        uuid = "06dbe2a8-5564-4bae-9ae9-a90eecf5b3f9";
        labels = [ "buildbot:docker://gitea-runner-nix" ];
        settings = {
          container.cpus = "6";
          container.memory = "48G";
          container.memory_swap = "0";
          runner.timeout = "6h";
        };
      };
    };
  };

  age.secrets.nix-cache-signing-key.rekeyFile = secrets.gsv-nix-cache;
  age.secrets.nix-cache-htpasswd = {
    rekeyFile = secrets.gsv-nix-cache-htpasswd;
    owner = "nginx";
  };
  services.harmonia = {
    cache.enable = true;
    cache.signKeyPaths = [ config.age.secrets.nix-cache-signing-key.path ];
    cache.settings.bind = "127.0.0.1:5021";
  };

  # keep sliding window of store paths over the past 2 months
  nix.gc = {
    dates = "monthly";
    options = "--delete-older-than 32d";
  };
  nix.settings = {
    extra-substituters = lib.mkForce [ ];
    extra-trusted-public-keys = lib.mkForce [ ];
  };

  systemd.tmpfiles.rules = [ "d /nix/var/nix/profiles/ci 0755 nixuser nixuser -" ];

  networking.firewall.allowedTCPPorts = [
    443
    80
  ];

  services.nginx = {
    virtualHosts."cache.${private-settings.domains.blog}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://${config.services.harmonia.cache.settings.bind}";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_redirect http:// https://;
          proxy_http_version 1.1;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          auth_basic "Nix cache";
          auth_basic_user_file ${config.age.secrets.nix-cache-htpasswd.path};
        '';
      };
      locations."= /ci-builds.json" = {
        alias = "/nix/var/nix/profiles/ci/ci-builds";
        extraConfig = ''
          default_type application/json;
          add_header Cache-Control no-cache;
          auth_basic "Nix cache";
          auth_basic_user_file ${config.age.secrets.nix-cache-htpasswd.path};
        '';
      };
    };
  };
}
