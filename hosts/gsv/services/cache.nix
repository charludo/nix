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
    defaultTokenFile.secret = secrets.gitea-actions-registration-token;
    runners = {
      ci-buildbot = {
        makeNixRunner = true;
        labels = [ "buildbot:docker://gitea-runner-nix" ];
        settings = {
          container.cpus = "6";
          container.memory = "48G";
          container.memory_swap = "0";
        };
      };
    };
  };

  age.secrets.nix-cache-signing-key.rekeyFile = secrets.gsv-nix-cache;
  services.harmonia = {
    enable = true;
    signKeyPaths = [ config.age.secrets.nix-cache-signing-key.path ];
    settings.bind = "127.0.0.1:5021";
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

  networking.firewall.allowedTCPPorts = [
    443
    80
  ];

  services.nginx = {
    virtualHosts."cache.${private-settings.domains.blog}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://${config.services.harmonia.settings.bind}";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_redirect http:// https://;
          proxy_http_version 1.1;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
        '';
      };
    };
  };
}
