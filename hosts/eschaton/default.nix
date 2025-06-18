{
  pkgs,
  private-settings,
  secrets,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../common
    ../../users/charlotte/user.nix
  ];

  age.enable = true;
  bluetooth.enable = true;
  docker.enable = true;
  fish.enable = true;
  graphicalFixes.enable = true;
  greetd.enable = true;
  gvfs.enable = true;
  ld.enable = true;
  nicerFonts.enable = true;
  nvim.enable = true;
  printers.enable = true;
  soundConfig.enable = true;
  soundConfig.enableCombinedAdapter = true;
  screensharing.enable = true;
  surfshark.enable = true;
  tailscale.enable = true;
  wifi.enable = true;
  programs.dconf.enable = true;

  suspend.enable = true;
  suspend.powertop = true;
  hardware.asus.battery.chargeUpto = 80;
  powerManagement.cpuFreqGovernor = "balanced";

  nas.enable = true;
  nas.backup.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;
  networking.hostName = "eschaton";
  networking.nameservers = [
    "192.168.30.13"
  ] ++ private-settings.upstreamDNS;

  boot.kernelParams = [
    "video=eDP-1:2880x1800@59.88"
    "i915.enable_psr=0"
  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.luks.devices."luks-ae3712c5-9e36-4590-9bed-8529a71859d1".device =
    "/dev/disk/by-uuid/ae3712c5-9e36-4590-9bed-8529a71859d1";

  age.secrets.yubikey-sudo.rekeyFile = private-settings.yubikeys.perostek.sudoFile;

  wireguard = {
    enable = true;
    interface = "hoehle";
    port = 51865;
    ip = "192.168.150.12/32";
    secrets = {
      secretsFilePrivate = secrets.drone-wg-private;
      secretsFilePreshared = secrets.drone-wg-preshared;
      remotePublicKey = private-settings.wireguard.publicKeys.drone;
    };
  };

  snow = {
    enable = true;
    useRemoteSudo = true;
    buildOnTarget = false;
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vpl-gpu-rt
      intel-compute-runtime
    ];
  };

  system.stateVersion = "23.11";
}
