{ pkgs, inputs, config, lib, ... }:
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2211;
    name = "SRV-MINECRAFT";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "2G"; # expand to 64G
  };

  services.minecraft-server = {
    enable = true;
    eula = true;
    openFirewall = true;
    declarative = true;
    package = pkgs.minecraftServers.vanilla-1-20;
    jvmOpts = "-XX:+UseG1GC -Xmx6G -Xms6G -Dsun.rmi.dgc.server.gcInterval=600000 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32";
    serverProperties = {
      server-port = 25565;
      motd = "Wo Haus am See???!!";
      enable-rcon = false;

      gamemode = 0;
      difficulty = 1;
      hardcore = false;
      force-gamemode = true;

      level-name = "world-2";
      level-seed = "-1743022870505021258";

      max-players = 5;
      player-idle-timeout = 60;

      online-mode = true;
      white-list = true;
      enforce-whitelist = true;
    };
    whitelist = inputs.private-settings.minecraftFriends;
  };

  system.activationScripts.script.text = ''
    ln -sf ${../hosts/gsv/services/pickaxe.png} ${config.services.minecraft-server.dataDir}/server-icon.png
  '';

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "minecraft-server"
  ];
  system.stateVersion = "23.11";
}
