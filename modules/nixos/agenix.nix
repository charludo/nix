{
  inputs,
  lib,
  config,
  ...
}:
let
  cfg = config.age;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.agenix-rekey.packages.x86_64-linux.default
    ];
  };
}
