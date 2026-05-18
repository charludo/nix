{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass;

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
{
  options.hass.persons = lib.mkOption {
    default = { };
    description = ''
      Home Assistant person entries, templated into .storage/person.
      Each key is the person's display name (slugified into the
      person id and entity_id, e.g. "Charlotte" -> person.charlotte)
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          trackers = lib.mkOption {
            type = lib.types.listOf (lib.types.strMatching "^device_tracker\\..+");
            default = [ ];
            example = lib.literalExpression "[ e.device_tracker.phone_charlotte ]";
            description = ''
              device_tracker entity_ids linked to this person. Pass via the
              type-safe e.* tree, e.g. e.device_tracker.phone_charlotte
            '';
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
        };
      }
    );
  };

  config = lib.mkIf (cfg.persons != { }) {
    systemd.tmpfiles.rules = [
      "L+ ${config.services.home-assistant.configDir}/.storage/person - - - - ${registryFile}"
    ];
  };
}
