{
  imports = [ ../users/marie/user.nix ];

  vm = {
    id = 3020;
    name = "CL-NIX-1";

    hardware.cores = 4;
    hardware.memory = 4096;
    hardware.storage = "64G";

    clientDevice.enable = true;
    clientDevice.kde = true;
  };

  nas.enable = true;
  nas.backup.enable = true;
}
