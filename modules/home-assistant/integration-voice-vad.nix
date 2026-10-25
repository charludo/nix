{
  lib,
  config,
  ...
}:
let
  cfg = config.hass.voice.vad;
in
{
  # How long to wait for silence is per satellite in HA ("Finished speaking
  # detection" on the device page); satellites pass it in with every run.
  # The overall recording limit has no UI, hence this patch.
  options.hass.voice.vad.timeoutSeconds = lib.mkOption {
    type = lib.types.float;
    default = 15.0;
    description = "Maximum recording duration for a single assist_pipeline voice command. Upstream default: 15.0.";
  };

  config = lib.mkIf (cfg.timeoutSeconds != 15.0) {
    hass.package.postPatch = ''
      substituteInPlace homeassistant/components/assist_pipeline/vad.py \
        --replace-fail 'timeout_seconds: float = 15.0' 'timeout_seconds: float = ${toString cfg.timeoutSeconds}'
    '';
  };
}
