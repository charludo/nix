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
  # Re-route assist_pipeline TTS output for a satellite (e.g. a wyoming
  # mic with no speaker) onto a Sonos. Uses sonos.snapshot /
  # sonos.restore (local UPnP) to emulate ducking — HA's `announce:
  # true` would be the natural fit, but Sonos's announce path needs
  # cloud OAuth and is unusable behind a firewall.
  options.hass.ttsRelay = lib.mkOption {
    default = [ ];
    description = ''
      List of routes mapping an ``assist_satellite`` entity to a target
      Sonos ``media_player``. On each TTS response, the target is
      snapshotted (if playing), the TTS clip is played, and the
      previous state is restored when the clip ends
    '';
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
            description = "Optional TTS playback volume (0.0–1.0). Original volume is restored after the clip";
          };
        };
      }
    );
  };

  config = lib.mkIf (cfg != [ ]) {
    services.home-assistant.customComponents = [
      pkgs.ours.home-assistant.custom-components.tts_relay
    ];

    # tts_relay takes either a bare list of route dicts (legacy) or a
    # dict with `routes:` + `sounds:`. We always emit the dict form so
    # the voice-effect sound URLs flow through to the component. URLs
    # are derived from the per-category paths in `hass.voice.sounds` —
    # voice.nix symlinks each path into `<www>/sounds/<basename>`, so
    # the public URL is `/local/sounds/<basename>`.
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
