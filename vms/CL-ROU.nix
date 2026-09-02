{
  imports = [ ../users/charlotte/user.nix ];

  vm = {
    id = 3024;
    name = "CL-ROU";

    hardware.cores = 6;
    hardware.memory = 16284;
    hardware.storage = "64G";

    networking.openPorts.tcp = [ 8000 ];
    networking.openPorts.udp = [ 8000 ];

    certsFor = [
      {
        name = "preview";
        port = 5500;
      }
    ];

    clientDevice.enable = true;
  };

  ld.enable = true;
  programs.dconf.enable = true;
  yubikey.enable = false;

  users.users.charlotte.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOAGqlAP1HqnpvQs6RdOvACadsLBe2ZHuPD3G1l4gUsZ charlotte@conduit"
  ];
}
