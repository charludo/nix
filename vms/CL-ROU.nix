{
  imports = [ ../users/charlotte/user.nix ];

  vm = {
    id = 3022;
    name = "CL-ROU";

    hardware.cores = 6;
    hardware.memory = 16284;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ 8000 ];
    networking.openPorts.udp = [ 8000 ];

    clientDevice.enable = true;
  };

  ld.enable = true;
  programs.dconf.enable = true;
  yubikey.enable = false;
}
