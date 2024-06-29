{ lib, ... }:

{
  options.vm = {
    id = lib.mkOption { type = lib.types.int; };
    name = lib.mkOption { type = lib.types.str; };

    hardware = {
      cores = lib.mkOption { type = lib.types.ints.positive; };
      memory = lib.mkOption { type = lib.types.ints.positive; };
      storage = lib.mkOption { type = lib.types.str; };
    };

    networking = {
      address = lib.mkOption { type = lib.types.str; };
      prefixLength = lib.mkOption { type = lib.types.int; };
      gateway = lib.mkOption { type = lib.types.str; };
      bridge = lib.mkOption { type = lib.types.str; };
      nameservers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "192.168.30.5" "192.168.30.6" "192.168.30.13" "1.1.1.1" ];
      };
      openPorts = {
        tcp = lib.mkOption { type = lib.types.listOf lib.types.int; default = [ ]; };
        udp = lib.mkOption { type = lib.types.listOf lib.types.int; default = [ ]; };
      };
    };
  };

  config = { };
}
