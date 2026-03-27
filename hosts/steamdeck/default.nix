{ pkgs, private-settings, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common
    ../../users/charlotte/user.nix
  ];

  nvim.enable = true;
  plymouth.enable = true;
  plymouth.theme = "dark_planet";
  steamOpenFirewall.enable = true;
  wifi.enable = true;
  yubikey.enable = false;
  programs.dconf.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  environment.systemPackages = [ pkgs.protonup-rs ];

  jovian = {
    devices.steamdeck = {
      enable = true;
      autoUpdate = true;
    };
    hardware.has.amd.gpu = true;
    steam = {
      enable = true;
      autoStart = true;
      desktopSession = "gamescope-wayland";

      user = "charlotte";
    };
    steamos.useSteamOSConfig = true;
  };
  # https://github.com/Jovian-Experiments/Jovian-NixOS/issues/564
  systemd.user.services."steamos-manager".serviceConfig.ExecStartPre = pkgs.lib.getExe (
    pkgs.writeShellScriptBin "wait-for-start" ''
      sleep 10
    ''
  );

  users.users.charlotte.extraGroups = [ "steamos" ];
  security.sudo.extraRules = [
    {
      users = [ "charlotte" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  networking.networkmanager.enable = true;
  networking.hostName = "steamdeck";
  networking.nameservers = [
    "192.168.30.13"
  ]
  ++ private-settings.upstreamDNS.ips;

  xdg.portal.enable = true;
  xdg.portal.wlr.enable = true;
  services.flatpak.enable = true;
  services.flatpak.packages = [
    "gg.minion.Minion"
  ];
}
