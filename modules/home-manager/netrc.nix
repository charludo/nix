{ lib, config, ... }:

let
  cfg = config.netrc;
in
{
  options.netrc.file = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    description = "set custom netrc file";
    default = null;
  };

  config = lib.mkIf (cfg.file != null) {
    home.activation = {
      linkNetrc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ln -sf ${config.age.secrets.netrc.path} ${config.home.homeDirectory}/.netrc
        chmod 644 ${config.home.homeDirectory}/.netrc
      '';
    };
  };
}
