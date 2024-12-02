{ lib, ... }:
{
  options.hass.devices =
    lib.mapAttrs
      (
        _: description:
        lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.area = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "HA area this entity belongs to";
              };
            }
          );
          default = { };
          inherit description;
        }
      )
      {
        media_players = "Known media_player entities keyed by slug";
        vacuums = "Known vacuum entities keyed by slug";
        fans = "Known fan entities keyed by slug";
        images = "Known image entities keyed by slug";
        suns = "Known sun entities keyed by slug";
        weathers = "Known weather entities keyed by slug";
        sensors = "Sensor entities (template, statistics, integration-provided) keyed by slug";
      };
}
