{ config, lib, ... }:

with lib;
let
  cfg = config._;
in
{
  options._ = {
    enable = lib.mkEnableOption (lib.mdDoc "");

    string = mkOption {
      type = types.str;
      default = "";
      description = "";
      example = "";
    };

    list = mkOption {
      type = types.listOf (string);
      default = [ ];
      description = "";
      example = [ "" ];
    };

    bool = mkOption {
      type = types.bool;
      default = false;
      description = "";
    };
  };

  config = mkIf cfg.enable { };
}
