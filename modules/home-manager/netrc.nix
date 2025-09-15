{ lib, config, ... }:

let
  cfg = config.cli.netrc;
in
{
  options.cli.netrc.file = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    description = "set custom netrc file";
    default = null;
  };

  config = lib.mkIf (cfg.file != null) {
    home.activation = {
      linkNetrc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        [ -f ${config.age.secrets.netrc.path} ] || exit 0
        ln -sf ${config.age.secrets.netrc.path} ${config.home.homeDirectory}/.netrc
        chmod 644 ${config.home.homeDirectory}/.netrc
      '';
    };
  };
}
