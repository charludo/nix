{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass;
in
{
  options.hass.persons = lib.mkOption {
    default = { };
    description = "HA person entries, templated into .storage/person";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          trackers = lib.mkOption {
            type = lib.types.listOf (lib.types.strMatching "^device_tracker\\..+");
            default = [ ];
            example = lib.literalExpression "[ e.person.charlotte.device_tracker ]";
            description = "device_tracker entity_ids linked to this person";
          };
          picture = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Picture URL (e.g. /local/foo.jpg)";
          };
          userId = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "HA user UUID to associate with";
          };
          phone = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "xiaomi_15";
            description = "Mobile App device name as it appears in HA's mobile_app integration";
          };
        };
      }
    );
  };

  config = lib.mkIf (cfg.persons != { }) {
    systemd.tmpfiles.rules =
      let
        registryFile = pkgs.writeText "person" (
          builtins.toJSON {
            version = 2;
            minor_version = 1;
            key = "person";
            data.items = lib.mapAttrsToList (name: person: {
              id = lib.ha.mkSlug name;
              inherit name;
              user_id = person.userId;
              device_trackers = person.trackers;
              picture = person.picture;
            }) cfg.persons;
          }
        );
      in
      [
        "L+ ${config.services.home-assistant.configDir}/.storage/person - - - - ${registryFile}"
      ];
  };
}
