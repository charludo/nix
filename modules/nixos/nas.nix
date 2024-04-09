{ lib, ... }:

{
  options.enableNas = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  options.enableNasBackup = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
}
