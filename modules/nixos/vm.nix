{ config, lib, ... }:
{
  options.vm = {
    enable = lib.mkEnableOption (lib.mdDoc "make into vm");
    id = lib.mkOption { type = lib.types.int; };
    name = lib.mkOption {
      type = lib.types.strMatching "^$|^[[:alnum:]]([[:alnum:]_-]{0,61}[[:alnum:]])?$";
    };

    hardware = {
      cores = lib.mkOption { type = lib.types.ints.positive; };
      memory = lib.mkOption { type = lib.types.ints.positive; };
      storage = lib.mkOption { type = lib.types.str; };
    };

    networking = {
      address = lib.mkOption {
        type = lib.types.str;
        default = "192.168.${builtins.substring 0 2 (toString config.vm.id)}.1${
          builtins.substring 2 2 (toString config.vm.id)
        }";
      };
      gateway = lib.mkOption {
        type = lib.types.str;
        default = "192.168.${builtins.substring 0 2 (toString config.vm.id)}.1";
      };
      prefixLength = lib.mkOption {
        type = lib.types.int;
        default = 24;
      };
      bridge = lib.mkOption { type = lib.types.str; };
      nameservers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "192.168.30.5"
          "192.168.30.6"
          "192.168.30.13"
          "1.1.1.1"
        ];
      };
      openPorts = {
        tcp = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
        };
        udp = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
        };
      };
    };
  };

  config = { };
}
