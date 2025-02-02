# see here for reason: https://github.com/ryantm/agenix/issues/300
{ config, lib, ... }:
{
  options.home.xdgRuntimeDir = lib.mkOption {
    type = lib.types.str;
    description = "the path where secrets will be decrypted to";
    default = "/run/user/1000";
  };

  config = {
    age.secretsDir = "${config.home.xdgRuntimeDir}/agenix";
  };
}
