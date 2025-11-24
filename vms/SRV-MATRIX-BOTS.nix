{
  config,
  inputs,
  lib,
  pkgs,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2221;
    name = "SRV-MATRIX-BOTS";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "16G";
  };

  imports = [ inputs.nix-update-notifier.nixosModules.default ];

  age.secrets.nixpkgs-bot-matrix-token.rekeyFile = secrets.nixpkgs-bot-matrix-token;
  age.secrets.nixpkgs-bot-github-token.rekeyFile = secrets.nixpkgs-bot-github-token;
  age.secrets.nixpkgs-update-notifier.rekeyFile = secrets.nixpkgs-update-notifier;

  services.nixpkgs-bot = {
    enable = true;
    package = pkgs.ours.nixpkgs-bot;

    secrets = {
      matrixTokenFile = config.age.secrets.nixpkgs-bot-matrix-token.path;
      githubTokenFile = config.age.secrets.nixpkgs-bot-github-token.path;
    };

    settings = {
      server = "https://matrix.${private-settings.domains.home}";
    };
  };

  services.nixpkgs-update-notifier = {
    enable = true;

    username = "nixpkgs";
    passwordFile = config.age.secrets.nixpkgs-update-notifier.path;

    timers.update = "24h0m0s";
    timers.jsblob = "30m0s";
  };

  systemd.services.nixpkgs-update-notifier.serviceConfig.ExecStart =
    let
      cfg = config.services.nixpkgs-update-notifier;
    in
    lib.mkForce (toString [
      (lib.getExe pkgs.nixpkgs-update-notifier)
      "-matrix.homeserver matrix.${private-settings.domains.home}"
      "-matrix.username ${cfg.username}"
      "-db ${cfg.dataDir}/data.db"
      (lib.optionalString (cfg.timers.update != null) "-timers.update ${cfg.timers.update}")
      (lib.optionalString (cfg.timers.jsblob != null) "-timers.jsblob ${cfg.timers.jsblob}")
      (lib.optionalString cfg.debug "-debug")
    ]);
}
