{ config, inputs, lib, pkgs, ... }:
{
  services.minecraft-server = {
    enable = true;
    eula = true;
    openFirewall = true;
    declarative = true;
    package = pkgs.minecraftServers.vanilla-1-20;
    jvmOpts = "-XX:+UseG1GC -Xmx8G -Xms8G -Dsun.rmi.dgc.server.gcInterval=600000 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32";
    serverProperties = {
      server-port = 25565;
      motd = "Los Peter, Haus bauen!!!!";
      enable-rcon = false;

      gamemode = 0;
      difficulty = 2;
      hardcore = false;
      force-gamemode = true;

      level-name = "world-3";
      level-seed = "-1345672572347283467";

      max-players = 5;
      player-idle-timeout = 60;

      online-mode = true;
      white-list = true;
      enforce-whitelist = true;
    };
    whitelist = inputs.private-settings.minecraftFriends;
  };

  system.activationScripts.script.text = ''
    ln -sf ${./pickaxe.png} ${config.services.minecraft-server.dataDir}/server-icon.png
  '';

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "minecraft-server"
  ];
}
