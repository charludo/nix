{ config, lib, ... }:

with lib;
let
  cfg = config.soundConfig;
in
{
  options.soundConfig = {
    enable = lib.mkEnableOption "sound output";

    enableCombinedAdapter = mkOption {
      type = types.bool;
      default = false;
      description = "add a combiner adapter with a single input/output";
    };
  };

  config = mkIf cfg.enable {
    security.rtkit.enable = true;
    services.pulseaudio.enable = false;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;

      raopOpenFirewall = true;

      extraConfig.pipewire = {
        # "10-airplay" = {
        #   "context.modules" = [
        #     {
        #       name = "libpipewire-module-raop-sink";
        #
        #       args = {
        #         "raop.latency.ms" = 255.419488;
        #         "raop.ip" = "192.168.24.203";
        #         "raop.port" = "7000";
        #         "raop.name" = "Office";
        #         # "raop.audio.codec" = "ALAC";
        #         "raop.encryption.type" = "auth_setup";
        #         # "raop.transport" = "tcp";
        #         "audio.format" = "S16";
        #         "audio.rate" = 44100;
        #         "audio.channels" = 2;
        #         "sess.latency.msec" = 255.419488;
        #       };
        #     }
        #   ];
        # };
        # "10-airplay" = {
        #   "context.modules" = [
        #     {
        #       name = "libpipewire-module-raop-discover";
        #
        #       # increase the buffer size if you get dropouts/glitches
        #       # args = {
        #       #   "raop.latency.ms" = 500;
        #       # };
        #     }
        #   ];
        # };
      }
      // mkIf cfg.enableCombinedAdapter {
        "10-combined-source" = {
          "context.objects" = [
            {
              factory = "adapter";
              args = {
                "factory.name" = "support.null-audio-sink";
                "node.name" = "Multi Source Aggregator";
                "audio.position" = [ "MONO" ];
                "media.class" = "Audio/Duplex";
                "object.linger" = true;
                "monitor.channel-volumes" = true;
                "monitor.passthrough" = true;
              };
            }
          ];
        };
      };
    };
  };
}
