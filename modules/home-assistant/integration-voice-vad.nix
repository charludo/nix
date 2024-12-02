{
  lib,
  config,
  ...
}:
let
  cfg = config.hass.voice.vad;
in
{
  options.hass.voice.vad = {
    silenceSeconds = lib.mkOption {
      type = lib.types.float;
      default = 0.7;
      description = "Seconds of silence required for assist_pipeline to consider a voice command finished. Upstream default: 0.7.";
    };

    timeoutSeconds = lib.mkOption {
      type = lib.types.float;
      default = 15.0;
      description = "Maximum recording duration for a single assist_pipeline voice command. Upstream default: 15.0.";
    };
  };

  config = lib.mkIf (cfg.silenceSeconds != 0.7 || cfg.timeoutSeconds != 15.0) {
    hass.package.postPatch = ''
      substituteInPlace homeassistant/components/assist_pipeline/vad.py \
        --replace-fail 'silence_seconds: float = 0.7' 'silence_seconds: float = ${toString cfg.silenceSeconds}' \
        --replace-fail 'timeout_seconds: float = 15.0' 'timeout_seconds: float = ${toString cfg.timeoutSeconds}'
    '';
  };
}
