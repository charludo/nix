{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.hass.ttsRelay;
in
{
  options.hass.ttsRelay = lib.mkOption {
    default = [ ];
    description = "List of routes mapping an `assist_satellite` entity to a target Sonos `media_player`";
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          satellite = lib.mkOption {
            type = lib.types.str;
            description = "assist_satellite entity_id whose TTS output should be redirected";
          };
          target = lib.mkOption {
            type = lib.types.str;
            description = "Sonos media_player entity_id that plays the TTS response";
          };
          volume = lib.mkOption {
            type = lib.types.nullOr (lib.types.numbers.between 0.0 1.0);
            default = null;
            description = "Optional TTS playback volume (0.0–1.0) only for the announcement";
          };
        };
      }
    );
  };

  config = lib.mkIf (cfg != [ ]) {
    services.home-assistant.customComponents = [
      pkgs.ours.home-assistant.tts-relay
    ];

    services.home-assistant.config.tts_relay = {
      routes = map (
        r:
        {
          inherit (r) satellite target;
        }
        // lib.optionalAttrs (r.volume != null) { inherit (r) volume; }
      ) cfg;
      sounds = lib.mapAttrs (_: path: "/local/sounds/${baseNameOf path}") (
        lib.filterAttrs (_: v: v != null) config.hass.voice.sounds
      );
    };

    services.home-assistant.config.logger.logs."custom_components.tts_relay" = "debug";
  };
}
