{ config, inputs, ... }:
let
  inherit (config.networking) hostName;
  isClean = inputs.self ? rev;
  flakeURL = "github:charludo/nix";
in
{
  system.autoUpgrade = {
    enable = isClean;
    dates = "hourly";
    flags = [ "--refresh" ];
    flake = "${flakeURL}#${hostName}";
    persistent = true;
    allowReboot = true;
    rebootWindow = {
      lower = "01:00";
      upper = "04:00";
    };
  };
}
