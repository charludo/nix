{ pkgs, inputs, ... }:
{
  _module.args.defaultUser = "charlotte";
  imports =
    [
      inputs.nix-flatpak.nixosModules.nix-flatpak

      ./hardware-configuration.nix

      ../common/global
      ../common/optional/nvim.nix
      ../common/optional/plymouth.nix
      ../common/optional/steam-firewall.nix
      ../common/optional/wifi.nix

      ../../users/charlotte/user.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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
  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;

  networking.networkmanager.enable = true;
  networking.hostName = "steamdeck";
  networking.nameservers = [ "192.168.30.13" "1.1.1.1" ];

  xdg.portal.enable = true;
  xdg.portal.wlr.enable = true;
  services.flatpak.enable = true;
  services.flatpak.packages = [
    "gg.minion.Minion"
  ];

  system.stateVersion = "23.11";
}
