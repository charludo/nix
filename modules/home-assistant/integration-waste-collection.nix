{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass.wasteCollection;

  date = lib.types.strMatching "[0-9]{4}-[0-9]{2}-[0-9]{2}";

  collections = lib.attrValues cfg.collections;
in
{
  options.hass.wasteCollection = {
    enable = lib.mkEnableOption "waste collection schedule (static, Nix-defined dates)";

    collections = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, config, ... }:
          {
            options = {
              slug = lib.mkOption {
                type = lib.types.str;
                default = name;
                readOnly = true;
                description = "Attribute name; the sensor becomes sensor.muell_<slug>.";
              };

              name = lib.mkOption {
                type = lib.types.str;
                description = "Collection type as spoken in answers, e.g. \"Restmüll\".";
              };

              subject = lib.mkOption {
                type = lib.types.str;
                default = config.name;
                defaultText = lib.literalExpression "name";
                example = "der Restmüll";
                description = "Grammatical subject in answers, with article if needed.";
              };

              plural = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether `subject` takes plural verbs (\"müssen\", \"werden\").";
              };

              aliases = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Spoken names the voice intents match on.";
              };

              weekday = lib.mkOption {
                type = lib.types.enum [
                  "MO"
                  "TU"
                  "WE"
                  "TH"
                  "FR"
                  "SA"
                  "SU"
                ];
              };

              everyWeeks = lib.mkOption {
                type = lib.types.ints.positive;
                default = 1;
              };

              start = lib.mkOption {
                type = date;
                description = "A known regular collection date; anchors the interval.";
              };

              until = lib.mkOption {
                type = date;
                description = ''
                  Last day the calendar is valid. Required: without it the static
                  source silently stops after 10 occurrences.
                '';
              };

              moved = lib.mkOption {
                type = lib.types.attrsOf date;
                default = { };
                example = {
                  "2026-12-24" = "2026-12-26";
                };
                description = "Regular date → actual date.";
              };

              cancelled = lib.mkOption {
                type = lib.types.listOf date;
                default = [ ];
              };

              extraDates = lib.mkOption {
                type = lib.types.listOf date;
                default = [ ];
              };

              sensor = lib.mkOption {
                type = lib.types.str;
                readOnly = true;
                default = "sensor.muell_${name}";
                description = "Entity whose state is the next collection date (ISO).";
              };
            };
          }
        )
      );
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant.customComponents = [
      pkgs.home-assistant-custom-components.waste_collection_schedule
    ];

    services.home-assistant.config.waste_collection_schedule = {
      # From this time on the sensors skip today's collection and show the next one;
      # the bags are long gone by then, so voice answers move on to the next date.
      day_switch_time = "11:00";

      sources = map (c: {
        name = "static";
        args = {
          type = c.name;
          frequency = "WEEKLY";
          interval = c.everyWeeks;
          weekdays = c.weekday;
          inherit (c) start until;
          excludes = lib.attrNames c.moved ++ c.cancelled;
          dates = lib.attrValues c.moved ++ c.extraDates;
        };
      }) collections;

      sensors = lib.imap0 (i: c: {
        name = "muell_${c.slug}";
        source_index = i;
        value_template = "{{ value.date.isoformat() }}";
      }) collections;
    };

    hass.devices.sensors = lib.mapAttrs' (
      slug: _: lib.nameValuePair "muell_${slug}" { }
    ) cfg.collections;
  };
}
