{ lib, ... }:

{
  options.home.hostname = lib.mkOption {
    type = lib.types.str;
    description = "the name of the host home-manager is running on";
  };
}
